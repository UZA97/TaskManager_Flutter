import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WeatherDay {
  final DateTime date;
  final int code; // WMO 날씨 코드
  final double max;
  final double min;
  final int? rainChance; // 강수확률 %

  const WeatherDay({
    required this.date,
    required this.code,
    required this.max,
    required this.min,
    this.rainChance,
  });
}

class NewsItem {
  final String title;
  final String source;
  final String url;

  const NewsItem({
    required this.title,
    required this.source,
    required this.url,
  });
}

/// 이번 주 월요일부터 일요일까지 날씨 (Open-Meteo, API 키 불필요).
/// 지난 요일은 실제 관측에 가까운 값, 남은 요일은 예보.
Future<List<WeatherDay>> fetchWeekWeather(double lat, double lng) async {
  final (monday, sunday) = currentWeek(DateTime.now());
  final response = await http
      .get(
        Uri.https('api.open-meteo.com', '/v1/forecast', {
          'latitude': '$lat',
          'longitude': '$lng',
          'daily':
              'weather_code,temperature_2m_max,temperature_2m_min,'
              'precipitation_probability_max',
          'timezone': 'auto',
          'start_date': _ymd(monday),
          'end_date': _ymd(sunday),
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) {
    throw Exception('날씨 조회 실패 (${response.statusCode})');
  }

  final daily = jsonDecode(response.body)['daily'];
  final dates = daily['time'] as List<dynamic>;
  final rain = daily['precipitation_probability_max'] as List<dynamic>?;
  return [
    for (var i = 0; i < dates.length; i++)
      WeatherDay(
        date: DateTime.parse(dates[i] as String),
        code: (daily['weather_code'][i] as num).toInt(),
        max: (daily['temperature_2m_max'][i] as num).toDouble(),
        min: (daily['temperature_2m_min'][i] as num).toDouble(),
        rainChance: (rain?[i] as num?)?.toInt(),
      ),
  ];
}

/// [now]가 속한 주의 (월요일, 일요일) 날짜
(DateTime, DateTime) currentWeek(DateTime now) {
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  return (monday, DateTime(monday.year, monday.month, monday.day + 6));
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Google 뉴스 한국 주요 기사 헤드라인
Future<List<NewsItem>> fetchHeadlines({int count = 8}) async {
  final response = await http
      .get(
        Uri.https('news.google.com', '/rss', {
          'hl': 'ko',
          'gl': 'KR',
          'ceid': 'KR:ko',
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) {
    throw Exception('뉴스 조회 실패 (${response.statusCode})');
  }
  return parseNewsRss(utf8.decode(response.bodyBytes), count: count);
}

/// RSS의 `item`에서 제목·링크 추출. 제목 끝의 " - 언론사"는 출처로 분리.
List<NewsItem> parseNewsRss(String xml, {int count = 8}) {
  final items = RegExp(r'<item>(.*?)</item>', dotAll: true).allMatches(xml);
  final result = <NewsItem>[];
  for (final item in items) {
    final body = item.group(1)!;
    final rawTitle = _tag(body, 'title');
    final url = _tag(body, 'link');
    if (rawTitle == null || url == null) continue;

    final title = _unescape(rawTitle);
    final dash = title.lastIndexOf(' - ');
    result.add(
      NewsItem(
        title: dash > 0 ? title.substring(0, dash) : title,
        source: dash > 0 ? title.substring(dash + 3) : '',
        url: _unescape(url),
      ),
    );
    if (result.length >= count) break;
  }
  return result;
}

String? _tag(String body, String name) {
  final m = RegExp('<$name>(.*?)</$name>', dotAll: true).firstMatch(body);
  if (m == null) return null;
  var value = m.group(1)!.trim();
  if (value.startsWith('<![CDATA[') && value.endsWith(']]>')) {
    value = value.substring(9, value.length - 3);
  }
  return value;
}

String _unescape(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

/// WMO 날씨 코드 → (설명, 아이콘)
(String, IconData) weatherInfo(int code) => switch (code) {
  0 => ('맑음', Icons.wb_sunny_outlined),
  1 || 2 => ('구름 조금', Icons.wb_cloudy_outlined),
  3 => ('흐림', Icons.cloud_outlined),
  45 || 48 => ('안개', Icons.foggy),
  51 || 53 || 55 || 56 || 57 => ('이슬비', Icons.grain),
  61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => ('비', Icons.umbrella),
  71 || 73 || 75 || 77 || 85 || 86 => ('눈', Icons.ac_unit),
  95 || 96 || 99 => ('뇌우', Icons.thunderstorm_outlined),
  _ => ('알 수 없음', Icons.help_outline),
};
