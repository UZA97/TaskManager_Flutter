import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/database/database.dart';
import '../../core/database/database_provider.dart';
import '../map/services/kakao_local_service.dart';
import '../memo/services/gemini_service.dart';
import 'briefing_sources.dart';

const _accent = Color(0xFF4A90E2);
const _regionKey = 'briefing_region';
const _defaultRegion = '서울';
const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 각 부분은 독립적으로 실패할 수 있음 (하나가 실패해도 나머지는 표시)
class AiBriefing {
  final List<WeatherDay> weather;
  final String? weatherError;
  final List<NewsItem> news;
  final String? newsError;
  final String? aiSummary;
  final String? aiError;

  const AiBriefing({
    this.weather = const [],
    this.weatherError,
    this.news = const [],
    this.newsError,
    this.aiSummary,
    this.aiError,
  });
}

/// 날씨를 볼 지역 (설정에 저장)
final briefingRegionProvider = FutureProvider<String>((ref) async {
  final db = ref.watch(databaseProvider);
  final row = await (db.select(
    db.settingTable,
  )..where((t) => t.key.equals(_regionKey))).getSingleOrNull();
  final value = row?.value.trim() ?? '';
  return value.isEmpty ? _defaultRegion : value;
});

Future<void> _saveRegion(AppDatabase db, String region) => db
    .into(db.settingTable)
    .insertOnConflictUpdate(
      SettingTableCompanion.insert(key: _regionKey, value: region),
    );

/// 결과 캐시 시간. 팝업을 다시 열 때마다 요청하지 않도록 (Gemini 사용량 절약)
const _cacheDuration = Duration(minutes: 30);

/// 지역별 결과. [_cacheDuration]이 지난 뒤 팝업을 열면 새로 가져옴.
final aiBriefingProvider = FutureProvider.autoDispose
    .family<AiBriefing, String>((ref, region) async {
  final link = ref.keepAlive();
  final timer = Timer(_cacheDuration, link.close);
  ref.onDispose(timer.cancel);

  // 날씨: 카카오 장소 검색으로 좌표 → Open-Meteo 예보
  List<WeatherDay> weather = const [];
  String? weatherError;
  try {
    final places = await KakaoLocalService().search(region);
    if (places.isEmpty) {
      weatherError = "'$region' 지역을 찾지 못했습니다";
    } else {
      weather = await fetchWeekWeather(places.first.lat, places.first.lng);
    }
  } catch (e) {
    weatherError = '날씨를 가져오지 못했습니다';
    print('날씨 조회 오류: $e');
  }

  // 뉴스: Google 뉴스 RSS
  List<NewsItem> news = const [];
  String? newsError;
  try {
    news = await fetchHeadlines();
  } catch (e) {
    newsError = '뉴스를 가져오지 못했습니다';
    print('뉴스 조회 오류: $e');
  }

  // AI: 실제 데이터를 근거로 요약만 (Google 검색 연동은 사용하지 않음)
  String? aiSummary;
  String? aiError;
  if (weather.isNotEmpty || news.isNotEmpty) {
    try {
      aiSummary = _stripMarkdown(
        await GeminiService().ask(_buildPrompt(region, weather, news)),
      );
    } catch (e) {
      aiError = e.toString().contains('429')
          ? 'Gemini 사용량 한도를 초과해 AI 요약을 건너뛰었습니다'
          : 'AI 요약을 가져오지 못했습니다';
      print('Gemini 요약 오류: $e');
    }
  }

  return AiBriefing(
    weather: weather,
    weatherError: weatherError,
    news: news,
    newsError: newsError,
    aiSummary: aiSummary,
    aiError: aiError,
  );
});

String _dayLabel(DateTime d) =>
    '${d.month}/${d.day}(${_weekdays[d.weekday - 1]})';

String _buildPrompt(
  String region,
  List<WeatherDay> weather,
  List<NewsItem> news,
) {
  final weatherLines = weather
      .map(
        (w) =>
            '${_dayLabel(w.date)} ${weatherInfo(w.code).$1}, '
            '${w.min.round()}~${w.max.round()}°C, '
            '강수확률 ${w.rainChance ?? '-'}%',
      )
      .join('\n');
  final newsLines = news
      .map((n) => '${n.title}${n.source.isEmpty ? '' : ' (${n.source})'}')
      .join('\n');

  return '''
아래 데이터만 근거로 한국어로 짧게 정리해주세요. 데이터에 없는 내용은 추가하지 마세요.
오늘은 ${_dayLabel(DateTime.now())}입니다.

[$region 이번 주(월~일) 날씨]
$weatherLines

[오늘 주요 뉴스 헤드라인]
$newsLines

출력 형식 (마크다운 기호 #, *, ** 사용 금지):
[날씨 한마디]
• 이번 주 날씨 흐름과 오늘 이후 우산이 필요한 날, 옷차림 조언을 2~3줄로
[뉴스 요약]
• 헤드라인 중 중요한 5개를 각각 한 줄로
''';
}

// 지시해도 마크다운이 섞여 오는 경우가 있어 정리
String _stripMarkdown(String text) => text
    .replaceAll('**', '')
    .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
    .replaceAll(RegExp(r'^\s*[*-]\s+', multiLine: true), '• ')
    .trim();

Future<void> showAiBriefingDialog(BuildContext context) =>
    showDialog(context: context, builder: (_) => const AiBriefingDialog());

/// 이번 주 날씨(Open-Meteo)와 주요 뉴스(Google 뉴스)를 Gemini로 요약해 보여주는 팝업
class AiBriefingDialog extends ConsumerWidget {
  const AiBriefingDialog({super.key});

  Future<void> _changeRegion(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final region = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('날씨 지역'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 서울, 부산 해운대구'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('적용'),
          ),
        ],
      ),
    );
    controller.dispose();
    final value = region?.trim() ?? '';
    if (value.isEmpty || value == current) return;
    await _saveRegion(ref.read(databaseProvider), value);
    ref.invalidate(briefingRegionProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final region = ref.watch(briefingRegionProvider).value;
    final result = region == null
        ? null
        : ref.watch(aiBriefingProvider(region));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: _accent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '이번 주 날씨 · 주요 뉴스',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '날씨: Open-Meteo · 뉴스: Google 뉴스 · 요약: Gemini',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (region != null)
                    TextButton.icon(
                      onPressed: () => _changeRegion(context, ref, region),
                      icon: const Icon(Icons.place_outlined, size: 16),
                      label: Text(region),
                    ),
                  IconButton(
                    tooltip: '닫기',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: result == null
                  ? const _Loading()
                  : result.when(
                      loading: () => const _Loading(),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '브리핑을 가져오지 못했습니다.\n$e',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      data: (data) => _Result(data: data),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text(
            '날씨와 뉴스를 가져오는 중...',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  final AiBriefing data;

  const _Result({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      children: [
        // AI 요약
        if (data.aiSummary != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              data.aiSummary!,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          ),
          const SizedBox(height: 16),
        ] else if (data.aiError != null) ...[
          Text(
            data.aiError!,
            style: const TextStyle(fontSize: 11, color: Colors.orange),
          ),
          const SizedBox(height: 12),
        ],

        // 날씨
        const _Header(icon: Icons.thermostat, title: '이번 주 날씨'),
        if (data.weatherError != null)
          _Notice(data.weatherError!)
        else
          for (final w in data.weather) _WeatherRow(day: w),
        const SizedBox(height: 16),

        // 뉴스
        const _Header(icon: Icons.newspaper, title: '주요 뉴스'),
        if (data.newsError != null)
          _Notice(data.newsError!)
        else
          for (final n in data.news) _NewsRow(item: n),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final IconData icon;
  final String title;

  const _Header({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _accent),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;

  const _Notice(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 22, bottom: 4),
    child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
  );
}

class _WeatherRow extends StatelessWidget {
  final WeatherDay day;

  const _WeatherRow({required this.day});

  @override
  Widget build(BuildContext context) {
    final (label, icon) = weatherInfo(day.code);
    final rainy = (day.rainChance ?? 0) >= 60;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = day.date == today;
    final row = Padding(
      padding: const EdgeInsets.fromLTRB(22, 3, 0, 3),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              isToday ? '오늘' : _dayLabel(day.date),
              style: TextStyle(
                fontSize: 12,
                color: isToday ? _accent : null,
                fontWeight: isToday ? FontWeight.bold : null,
              ),
            ),
          ),
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 6),
          SizedBox(
            width: 64,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          SizedBox(
            width: 80,
            child: Text(
              '${day.min.round()}° / ${day.max.round()}°',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (day.rainChance != null)
            Text(
              '☔ ${day.rainChance}%',
              style: TextStyle(
                fontSize: 12,
                color: rainy ? _accent : Colors.grey,
                fontWeight: rainy ? FontWeight.w600 : null,
              ),
            ),
        ],
      ),
    );
    // 지난 요일은 흐리게
    return day.date.isBefore(today) ? Opacity(opacity: 0.45, child: row) : row;
  }
}

class _NewsRow extends StatelessWidget {
  final NewsItem item;

  const _NewsRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          launchUrl(Uri.parse(item.url), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 0, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.source.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                item.source,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
