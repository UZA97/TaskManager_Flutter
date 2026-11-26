import 'package:taskmanager/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskmanager/features/map/services/location_search_result.dart';
import '../providers/event_provider.dart';
import '../models/event.dart';
import '../models/recurrence.dart';
import '../data/event_repository.dart';
import '../../map/widgets/location_search_dialog.dart';
import '../../map/providers/map_provider.dart';
import '../../../core/providers/navigation_provider.dart';
import 'package:latlong2/latlong.dart';
import 'calendar_actions.dart';
import 'calendar_time_grid.dart';

const _weekdayNames = ['일', '월', '화', '수', '목', '금', '토'];

class CalendarEditorView extends ConsumerStatefulWidget {
  const CalendarEditorView({super.key});

  @override
  ConsumerState<CalendarEditorView> createState() => _CalendarEditorViewState();
}

class _CalendarEditorViewState extends ConsumerState<CalendarEditorView> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// 이전/다음 (월 보기는 한 달, 주 보기는 7일, 일 보기는 하루)
  void _step(int direction) {
    final mode = ref.read(calendarViewModeProvider);
    if (mode == CalendarViewMode.month) {
      final notifier = ref.read(currentMonthProvider.notifier);
      direction < 0 ? notifier.prevMonth() : notifier.nextMonth();
      return;
    }
    final selected = ref.read(selectedDateProvider);
    final days = mode == CalendarViewMode.week ? 7 : 1;
    goToDate(
      ref,
      DateTime(selected.year, selected.month, selected.day + days * direction),
    );
  }

  void _setMode(CalendarViewMode mode) {
    ref.read(calendarViewModeProvider.notifier).set(mode);
    // 주·일 보기는 선택한 날짜 기준이므로 그 날짜의 달을 불러옴
    if (mode != CalendarViewMode.month) {
      ref
          .read(currentMonthProvider.notifier)
          .showDate(ref.read(selectedDateProvider));
    }
  }

  String _title(CalendarViewMode mode, DateTime month, DateTime selected) {
    switch (mode) {
      case CalendarViewMode.month:
        return '${month.year}년 ${month.month}월';
      case CalendarViewMode.week:
        final start = weekStartOf(selected);
        final end = DateTime(start.year, start.month, start.day + 6);
        return start.month == end.month
            ? '${start.year}년 ${start.month}월 ${start.day}일 – ${end.day}일'
            : '${start.year}년 ${start.month}월 ${start.day}일 – '
                  '${end.month}월 ${end.day}일';
      case CalendarViewMode.day:
        return '${selected.year}년 ${selected.month}월 ${selected.day}일 '
            '(${_weekdayNames[selected.weekday % 7]})';
    }
  }

  void _openSearchResult(Event event) {
    final date = DateTime.parse(event.start);
    goToDate(ref, date);
    _search.clear();
    _searchFocus.unfocus();
    setState(() {});
    openEventDialog(context, ref, event: event, date: date);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(calendarViewModeProvider);
    final currentMonth = ref.watch(currentMonthProvider);
    final selected = ref.watch(selectedDateProvider);
    final eventsAsync = ref.watch(eventListProvider);
    final scheme = Theme.of(context).colorScheme;
    final query = _search.text.trim();

    Widget navButton(IconData icon, String tooltip, VoidCallback onPressed) =>
        IconButton(
          tooltip: tooltip,
          icon: Icon(icon, size: 20),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          style: IconButton.styleFrom(
            foregroundColor: scheme.onSurfaceVariant,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

    final body = eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (events) => switch (mode) {
        CalendarViewMode.month => _CalendarGrid(
          currentMonth: currentMonth,
          events: events,
        ),
        CalendarViewMode.week => CalendarTimeGrid(
          days: [
            for (var i = 0; i < 7; i++)
              DateTime(
                weekStartOf(selected).year,
                weekStartOf(selected).month,
                weekStartOf(selected).day + i,
              ),
          ],
          events: events,
        ),
        CalendarViewMode.day => CalendarTimeGrid(
          days: [DateTime(selected.year, selected.month, selected.day)],
          events: events,
        ),
      },
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _searchFocus.requestFocus(),
      },
      child: Column(
        children: [
          // 헤더: 큰 제목, 이전/다음, 오늘, 월·주·일, 검색, 일정 추가
          Padding(
            padding: const EdgeInsets.fromLTRB(36, 24, 24, 14),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    _title(mode, currentMonth, selected),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                navButton(Icons.chevron_left, '이전', () => _step(-1)),
                navButton(Icons.chevron_right, '다음', () => _step(1)),
                const Spacer(),
                OutlinedButton(
                  onPressed: () {
                    final now = DateTime.now();
                    ref.read(currentMonthProvider.notifier).showDate(now);
                    ref.read(selectedDateProvider.notifier).select(now);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.onSurface,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: BorderSide(color: context.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('오늘', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                _ModeToggle(mode: mode, onChanged: _setMode),
                const SizedBox(width: 8),
                SizedBox(
                  width: 200,
                  height: 32,
                  child: TextField(
                    key: const ValueKey('calendar-search'),
                    controller: _search,
                    focusNode: _searchFocus,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: '일정 검색',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      prefixIconConstraints: const BoxConstraints(minWidth: 32),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 14),
                              onPressed: () => setState(_search.clear),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.line),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => openEventDialog(context, ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('일정 추가', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: context.accent,
                    foregroundColor: scheme.onPrimary,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: body),
                if (query.isNotEmpty)
                  Positioned(
                    top: 0,
                    right: 24,
                    width: 380,
                    child: _SearchResults(
                      query: query,
                      onSelect: _openSearchResult,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 월·주·일 전환
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final CalendarViewMode mode;
  final ValueChanged<CalendarViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: context.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in CalendarViewMode.values)
            GestureDetector(
              key: ValueKey('calendar-mode-${m.name}'),
              onTap: () => onChanged(m),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  width: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: m == mode ? context.accent : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    m.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: m == mode ? FontWeight.w600 : null,
                      color: m == mode ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 검색 결과 (누르면 그 날짜로 가서 일정을 엶)
class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query, required this.onSelect});

  final String query;
  final ValueChanged<Event> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(eventSearchProvider(query));
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Material(
      color: context.popupSurface,
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: results.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('검색 오류: $e'),
          ),
          data: (events) => events.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '"$query" 일정 없음',
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: events.length,
                  itemBuilder: (context, i) {
                    final e = events[i];
                    final color = eventColor(e);
                    final date = DateTime.parse(e.start);
                    return InkWell(
                      key: ValueKey('calendar-search-result-$i'),
                      onTap: () => onSelect(e),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 30,
                              decoration: BoxDecoration(
                                color: color ?? context.line,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.title.isEmpty ? '(제목 없음)' : e.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    [
                                      '${date.year}.${date.month}.${date.day} '
                                          '(${_weekdayNames[date.weekday % 7]})',
                                      if (!e.isAllDay && e.startTime != null)
                                        e.startTime!,
                                      if (e.isRecurring) recurrenceSummary(e),
                                      if (e.locationName != null)
                                        e.locationName!,
                                    ].join(' · '),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

// ── 월 보기 그리드 ─────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime currentMonth;
  final List<Event> events;

  const _CalendarGrid({required this.currentMonth, required this.events});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final range = monthGridRange(currentMonth);
    final weeks = (range.to.difference(range.from).inHours / 24 / 7).round();
    final now = DateTime.now();

    return Column(
      children: [
        // 요일 헤더
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.lineSubtle)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        _weekdayNames[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: i == 0
                              ? Colors.red
                              : i == 6
                              ? Colors.blue
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              for (var w = 0; w < weeks; w++)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var d = 0; d < 7; d++)
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final date = DateTime(
                                range.from.year,
                                range.from.month,
                                range.from.day + w * 7 + d,
                              );
                              return _CalendarCell(
                                key: ValueKey(
                                  'calendar-cell-${formatDate(date)}',
                                ),
                                date: date,
                                inMonth: date.month == currentMonth.month,
                                isToday:
                                    date.year == now.year &&
                                    date.month == now.month &&
                                    date.day == now.day,
                                events: eventsOn(events, date),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 날짜 칸 (누르면 새 일정, 일정을 끌어다 놓으면 이 날로 옮김) ──────────
class _CalendarCell extends ConsumerWidget {
  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final List<Event> events;

  const _CalendarCell({
    super.key,
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.events,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final weekday = date.weekday % 7;
    return DragTarget<Event>(
      onAcceptWithDetails: (details) =>
          moveEventTo(context, ref, details.data, date),
      builder: (context, candidates, _) => GestureDetector(
        onTap: () {
          ref.read(selectedDateProvider.notifier).select(date);
          openEventDialog(context, ref, date: date);
        },
        child: Container(
          decoration: BoxDecoration(
            color: candidates.isNotEmpty
                ? context.accent.withValues(alpha: 0.08)
                : inMonth
                ? null
                : context.surfaceMuted,
            border: Border.all(color: context.lineSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 날짜 숫자
              Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: isToday
                      ? BoxDecoration(
                          color: context.accent,
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isToday
                            ? scheme.onPrimary
                            : (weekday == 0
                                      ? Colors.red
                                      : weekday == 6
                                      ? Colors.blue
                                      : scheme.onSurface)
                                  .withValues(alpha: inMonth ? 1 : 0.45),
                      ),
                    ),
                  ),
                ),
              ),
              // 일정 목록 (칸 높이에 맞는 만큼, 넘치면 +N개)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final fit = (constraints.maxHeight / 20).floor().clamp(
                      0,
                      99,
                    );
                    final shown = events.length > fit
                        ? (fit - 1).clamp(0, 99)
                        : events.length;
                    return ClipRect(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final e in events.take(shown))
                            _MonthEventChip(event: e),
                          if (shown < events.length)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                '+${events.length - shown}개',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 월 보기의 일정 한 줄 (눌러서 열기, 끌어서 다른 날로)
class _MonthEventChip extends ConsumerWidget {
  const _MonthEventChip({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final color = eventColor(event);
    Widget chip({double opacity = 1, double? width}) => Opacity(
      opacity: opacity,
      child: Container(
        width: width,
        height: 18,
        margin: const EdgeInsets.fromLTRB(2, 0, 2, 2),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: color?.withValues(alpha: 0.8) ?? scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          [
            if (!event.isAllDay && event.startTime != null) event.startTime!,
            event.title.isEmpty ? '(제목 없음)' : event.title,
          ].join(' '),
          style: TextStyle(
            fontSize: 10,
            color: color != null ? Colors.white : null,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );

    final tappable = GestureDetector(
      onTap: () => openEventDialog(context, ref, event: event),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: chip()),
    );
    if (!isEventWritable(ref, event)) return tappable;
    return LayoutBuilder(
      builder: (context, constraints) => Draggable<Event>(
        data: event,
        feedback: Material(
          color: Colors.transparent,
          elevation: 4,
          child: chip(opacity: 0.9, width: constraints.maxWidth),
        ),
        childWhenDragging: chip(opacity: 0.35),
        child: tappable,
      ),
    );
  }
}

// ── 일정 다이얼로그 ───────────────────────────────────────
class EventDialog extends ConsumerStatefulWidget {
  final DateTime initialDate;
  final Event? event;

  /// 새 일정의 미리 채울 값 (메모의 날짜에서 만들 때)
  final String? initialTitle;
  final String? initialContent;
  final TimeOfDay? initialTime;
  final bool initialAlarm;

  /// 지도에서 만들 때의 장소
  final String? initialLocationName;
  final double? initialLat;
  final double? initialLng;

  const EventDialog({
    this.initialLocationName,
    this.initialLat,
    this.initialLng,
    super.key,
    required this.initialDate,
    this.event,
    this.initialTitle,
    this.initialContent,
    this.initialTime,
    this.initialAlarm = false,
  });

  @override
  ConsumerState<EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends ConsumerState<EventDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isAllDay = true;
  bool _alarmEnabled = false;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int? _selectedTagId;
  double? _locationLat;
  double? _locationLng;
  int? _alarmMinutesBefore; // null = 알림 없음
  bool _saving = false; // 저장/삭제 중복 클릭 방지
  Recurrence _recurrence = Recurrence.none;
  DateTime? _recurrenceUntil; // null = 무기한
  int _interval = 1; // 2면 격주·격월 등
  Set<int> _weekdays = {}; // 매주 반복의 요일 (DateTime.weekday)
  String _calendarId = ''; // 새 일정을 넣을 구글 캘린더 ('' = 기본)

  /// 연 일정이 반복 일정의 한 회차인지 (저장·삭제 때 범위를 물음)
  bool get _isOccurrence =>
      widget.event?.id != null && widget.event!.isRecurring;

  /// 반복 설정을 바꿨는지 (바꿨으면 "이 일정만"은 의미가 없어 전체에 적용)
  bool get _recurrenceChanged {
    final e = widget.event!;
    return _recurrence.key != e.recurrence ||
        _interval != e.recurrenceInterval ||
        _untilString != e.recurrenceUntil ||
        (_recurrence == Recurrence.weekly &&
            !_sameDays(_weekdays, weeklyDays(e)));
  }

  static bool _sameDays(Set<int> a, List<int> b) =>
      a.length == b.length && a.containsAll(b);

  String? get _untilString =>
      _recurrence == Recurrence.none || _recurrenceUntil == null
      ? null
      : _formatDate(_recurrenceUntil!);

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      final e = widget.event!;
      _titleController.text = e.title;
      _contentController.text = e.content ?? '';
      _locationController.text = e.locationName ?? '';
      _locationLat = e.locationLat;
      _locationLng = e.locationLng;
      _isAllDay = e.isAllDay;
      _alarmEnabled = e.alarmEnabled;
      _recurrence = Recurrence.fromKey(e.recurrence);
      _recurrenceUntil = e.recurrenceUntil != null
          ? DateTime.parse(e.recurrenceUntil!)
          : null;
      _interval = e.recurrenceInterval < 1 ? 1 : e.recurrenceInterval;
      _weekdays = e.isRecurring ? weeklyDays(e).toSet() : {};
      _calendarId = e.calendarId;
      if (e.alarmEnabled) {
        _alarmMinutesBefore = e.alarmDaysBefore > 0 ? e.alarmDaysBefore : 30;
      }
      _startDate = e.startDate != null
          ? DateTime.parse(e.startDate!)
          : widget.initialDate;
      _endDate = e.endDate != null
          ? DateTime.parse(e.endDate!)
          : widget.initialDate;
      if (e.startTime != null) {
        final parts = e.startTime!.split(':');
        _startTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
      if (e.endTime != null) {
        final parts = e.endTime!.split(':');
        _endTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } else {
      _startDate = widget.initialDate;
      _endDate = widget.initialDate;
      _titleController.text = widget.initialTitle ?? '';
      _contentController.text = widget.initialContent ?? '';
      final time = widget.initialTime;
      if (time != null) {
        _isAllDay = false;
        _startTime = time;
        // 기본 1시간 (자정을 넘기지 않게)
        _endTime = time.hour >= 23
            ? const TimeOfDay(hour: 23, minute: 59)
            : TimeOfDay(hour: time.hour + 1, minute: time.minute);
      }
      if (widget.initialAlarm) _alarmMinutesBefore = 30;
      _locationController.text = widget.initialLocationName ?? '';
      _locationLat = widget.initialLat;
      _locationLng = widget.initialLng;
    }

    // 태그 로드 (반복 일정의 회차는 그 회차의 날짜 그대로 보여 줌.
    // "모든 일정"으로 저장하면 옮긴 만큼 전체를 옮김)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.event?.id != null) {
        final repo = ref.read(eventRepositoryProvider);
        final tags = await repo.getEventTags(widget.event!.id!);
        if (!mounted) return;
        setState(() {
          _selectedTagId = tags.isNotEmpty ? tags.first.id : null;
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart
        ? (_startDate ?? widget.initialDate)
        : (_endDate ?? widget.initialDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? TimeOfDay.now()),
    );
    if (picked == null) return;
    setState(() {
      if (isStart)
        _startTime = picked;
      else
        _endTime = picked;
    });
  }

  Future<void> _pickRecurrenceUntil() async {
    final start = _startDate ?? widget.initialDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurrenceUntil ?? start.add(const Duration(days: 30)),
      firstDate: start,
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _recurrenceUntil = picked);
  }

  // 지도 탭에서 이 일정의 장소 보기 (지도는 선택된 위치를 중심으로 열림)
  void _showOnMap() {
    ref
        .read(selectedLocationProvider.notifier)
        .select(
          SelectedLocation(
            name: _locationController.text,
            position: LatLng(_locationLat!, _locationLng!),
          ),
        );
    ref.read(navigationProvider.notifier).navigateTo(3); // 지도 탭
    Navigator.pop(context);
  }

  Future<void> _pickLocation() async {
    final result = await showDialog<LocationSearchResult>(
      context: context,
      builder: (context) => const LocationSearchDialog(),
    );
    if (result == null) return;
    setState(() {
      _locationController.text = result.name;
      _locationLat = result.lat;
      _locationLng = result.lng;
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _delete() async {
    if (_saving) return;
    var scope = RecurringScope.all;
    if (_isOccurrence) {
      final picked = await askRecurringScope(context, title: '반복 일정 삭제');
      if (picked == null || !mounted) return;
      scope = picked;
    }
    setState(() => _saving = true);
    try {
      final notifier = ref.read(eventListProvider.notifier);
      if (scope == RecurringScope.thisOnly) {
        await notifier.deleteOccurrence(widget.event!);
      } else {
        await notifier.deleteEvent(widget.event!.id!);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('삭제 실패: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_titleController.text.isEmpty || _saving) return;
    var scope = RecurringScope.all;
    if (_isOccurrence && !_recurrenceChanged) {
      final picked = await askRecurringScope(context, title: '반복 일정 수정');
      if (picked == null || !mounted) return;
      scope = picked;
    }
    setState(() => _saving = true);
    try {
      final id = await _saveEvent(scope);
      // 저장한 일정 번호를 돌려줌 (메모 체크리스트와 연결할 때 씀)
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      _showError('저장 실패: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<int?> _saveEvent(RecurringScope scope) async {
    var startDateStr = _formatDate(_startDate ?? widget.initialDate);
    var endDateStr = _formatDate(_endDate ?? widget.initialDate);
    var exceptions = const <String>[];
    final notifier = ref.read(eventListProvider.notifier);
    final repo = ref.read(eventRepositoryProvider);

    // 반복 일정 전체: 이 회차에서 옮긴 날 수만큼 원본(첫 회차)과 뺀 날짜들을 옮김
    final occurrence = widget.event;
    if (_isOccurrence && scope == RecurringScope.all) {
      final master = await repo.getEventById(occurrence!.id!);
      if (master != null) {
        final shift = DateTime.parse(
          startDateStr,
        ).difference(DateTime.parse(occurrence.start)).inDays;
        final span = DateTime.parse(
          endDateStr,
        ).difference(DateTime.parse(startDateStr)).inDays;
        String move(String date, int days) {
          final d = DateTime.parse(date);
          return _formatDate(DateTime(d.year, d.month, d.day + days));
        }

        startDateStr = move(master.start, shift);
        endDateStr = move(startDateStr, span);
        exceptions = [
          for (final d in master.recurrenceExceptions) move(d, shift),
        ];
      }
    }
    // 매주 반복은 시작일의 요일이 늘 들어가게
    final weekdays = {..._weekdays};
    if (_recurrence == Recurrence.weekly) {
      weekdays.add(DateTime.parse(startDateStr).weekday);
    }

    final event = Event(
      id: widget.event?.id,
      title: _titleController.text,
      createdAt: widget.event?.createdAt ?? DateTime.now().toIso8601String(),
      alarmEnabled: _alarmMinutesBefore != null,
      alarmDaysBefore: _alarmMinutesBefore ?? 0,
      alarmTime: _isAllDay
          ? '09:00' // 하루종일이면 알람 울릴 시간 직접 지정 필요
          : _startTime != null
          ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
          : '09:00',
      isAllDay: _isAllDay,
      eventDate: startDateStr,
      startDate: startDateStr,
      endDate: endDateStr,
      startTime: _isAllDay
          ? null
          : _startTime != null
          ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
          : null,
      endTime: _isAllDay
          ? null
          : _endTime != null
          ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
          : null,
      content: _contentController.text.isEmpty ? null : _contentController.text,
      locationName: _locationController.text.isEmpty
          ? null
          : _locationController.text,
      locationLat: _locationLat,
      locationLng: _locationLng,
      googleEventId: widget.event?.googleEventId,
      priority: widget.event?.priority ?? 1,
      isCompleted: widget.event?.isCompleted ?? false,
      tagColor: widget.event?.tagColor,
      recurrence: _recurrence.key,
      recurrenceUntil: _untilString,
      recurrenceInterval: _recurrence == Recurrence.none ? 1 : _interval,
      // 시작일의 요일 하나뿐이면 따로 적지 않음 (구글 기본과 같음)
      recurrenceDays:
          _recurrence == Recurrence.weekly &&
              !(weekdays.length == 1 &&
                  weekdays.first == DateTime.parse(startDateStr).weekday)
          ? (weekdays.toList()..sort())
          : const [],
      recurrenceExceptions: _recurrence == Recurrence.none
          ? const []
          : exceptions,
      calendarId: _calendarId,
    );

    // 태그 저장
    int? savedId;
    if (_isOccurrence && scope == RecurringScope.thisOnly) {
      savedId = await notifier.detachOccurrence(occurrence!, event);
    } else if (widget.event != null) {
      await notifier.updateEvent(event);
      savedId = widget.event!.id;
    } else {
      savedId = await notifier.addEvent(event);
    }

    if (savedId != null) {
      await repo.setEventTags(
        savedId,
        _selectedTagId != null ? [_selectedTagId!] : [],
      );
    }
    return savedId;
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(eventTagProvider);
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final calendars =
        ref.watch(googleCalendarsProvider).valueOrNull ??
        const GoogleCalendarsState();
    final calendar = calendars.byId(_calendarId);
    final writable = calendars.isWritable(_calendarId);
    final writableCalendars = [
      for (final c in calendars.calendars)
        if (c.writable) c,
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 제목
              Text(
                widget.event != null ? '일정 편집' : '일정 추가',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              // 어느 구글 캘린더의 일정인지 (새 일정은 고를 수 있음)
              if (widget.event == null && writableCalendars.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: DropdownButton<String>(
                    key: const ValueKey('event-calendar'),
                    value: writableCalendars.any((c) => c.id == _calendarId)
                        ? _calendarId
                        : writableCalendars.first.id,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final c in writableCalendars)
                        DropdownMenuItem(
                          value: c.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 10,
                                color: _hexToColor(c.color),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                c.name,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _calendarId = v ?? ''),
                  ),
                )
              else if (calendar != null && !calendar.primary)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: _hexToColor(calendar.color),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          writable
                              ? calendar.name
                              : '${calendar.name} · 읽기 전용 캘린더라 고칠 수 없습니다',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // 제목 입력
              TextField(
                controller: _titleController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '제목',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // 하루종일 토글
              Row(
                children: [
                  const Text('하루종일', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  Switch(
                    value: _isAllDay,
                    onChanged: (v) => setState(() => _isAllDay = v),
                  ),
                ],
              ),

              // 일시
              Row(
                children: [
                  // 시작
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '시작',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                        const SizedBox(height: 4),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _pickDate(true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: context.line),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatDate(_startDate ?? widget.initialDate),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        if (!_isAllDay) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _pickTime(true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: context.line),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _startTime != null
                                    ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                                    : '시간 선택',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _startTime == null ? muted : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('~', style: TextStyle(color: muted)),
                  ),
                  // 종료
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '종료',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                        const SizedBox(height: 4),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => _pickDate(false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: context.line),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatDate(_endDate ?? widget.initialDate),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        if (!_isAllDay) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _pickTime(false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: context.line),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _endTime != null
                                    ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                                    : '시간 선택',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _endTime == null ? muted : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 장소
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _locationController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: '장소',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                        prefixIcon: const Icon(Icons.location_on, size: 16),
                        suffixIcon: _locationController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => setState(() {
                                  _locationController.clear();
                                  _locationLat = null;
                                  _locationLng = null;
                                }),
                              )
                            : null,
                      ),
                      onTap: _pickLocation,
                    ),
                  ),
                  if (_locationLat != null && _locationLng != null)
                    IconButton(
                      tooltip: '지도에서 보기',
                      icon: const Icon(Icons.map_outlined, size: 18),
                      onPressed: _showOnMap,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // 태그
              Text('태그', style: TextStyle(fontSize: 11, color: muted)),
              const SizedBox(height: 6),
              tagsAsync.when(
                loading: () => const SizedBox(),
                error: (e, _) => const SizedBox(),
                data: (tags) => tags.isEmpty
                    ? Text(
                        '태그 없음',
                        style: TextStyle(fontSize: 11, color: muted),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags.map((tag) {
                          final isSelected = _selectedTagId == tag.id;
                          final color = _hexToColor(tag.color);
                          return GestureDetector(
                            onTap: () => setState(() {
                              // 같은 태그 누르면 해제
                              _selectedTagId = isSelected ? null : tag.id;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color
                                    : color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tag.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : color,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : null,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 12),

              // 내용
              TextField(
                controller: _contentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: '내용',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // 반복
              Row(
                children: [
                  const Text('반복', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  DropdownButton<Recurrence>(
                    key: const ValueKey('recurrence-rule'),
                    value: _recurrence,
                    isDense: true,
                    items: [
                      for (final r in Recurrence.values)
                        DropdownMenuItem(value: r, child: Text(r.label)),
                    ],
                    onChanged: (v) =>
                        setState(() => _recurrence = v ?? Recurrence.none),
                  ),
                ],
              ),
              if (_recurrence != Recurrence.none) ...[
                const SizedBox(height: 4),
                // 간격: "2주마다" 등
                Row(
                  children: [
                    const Text('간격', style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    IconButton(
                      key: const ValueKey('recurrence-interval-down'),
                      icon: const Icon(Icons.remove, size: 16),
                      visualDensity: VisualDensity.compact,
                      onPressed: _interval > 1
                          ? () => setState(() => _interval--)
                          : null,
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        _interval == 1
                            ? _recurrence.label
                            : '$_interval${_recurrence.unit}마다',
                        key: const ValueKey('recurrence-interval'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('recurrence-interval-up'),
                      icon: const Icon(Icons.add, size: 16),
                      visualDensity: VisualDensity.compact,
                      onPressed: _interval < 99
                          ? () => setState(() => _interval++)
                          : null,
                    ),
                  ],
                ),
                // 매주: 요일 고르기 (시작일의 요일은 늘 포함)
                if (_recurrence == Recurrence.weekly) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final weekday in const [7, 1, 2, 3, 4, 5, 6])
                        Builder(
                          builder: (context) {
                            final startDay =
                                (_startDate ?? widget.initialDate).weekday;
                            final on =
                                weekday == startDay ||
                                _weekdays.contains(weekday);
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: InkWell(
                                key: ValueKey('recurrence-day-$weekday'),
                                borderRadius: BorderRadius.circular(14),
                                onTap: weekday == startDay
                                    ? null
                                    : () => setState(() {
                                        if (!_weekdays.remove(weekday)) {
                                          _weekdays.add(weekday);
                                        }
                                      }),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: on ? context.accent : null,
                                    shape: BoxShape.circle,
                                    border: on
                                        ? null
                                        : Border.all(color: context.line),
                                  ),
                                  child: Text(
                                    weekdayLabels[weekday - 1],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: on ? scheme.onPrimary : null,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('반복 종료', style: TextStyle(fontSize: 13)),
                    const Spacer(),
                    TextButton(
                      onPressed: _pickRecurrenceUntil,
                      child: Text(
                        _recurrenceUntil == null
                            ? '계속 반복'
                            : '${_formatDate(_recurrenceUntil!)}까지',
                      ),
                    ),
                    if (_recurrenceUntil != null)
                      IconButton(
                        tooltip: '종료일 없음',
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () =>
                            setState(() => _recurrenceUntil = null),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),

              // 알림
              Row(
                children: [
                  const Text('알림', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  Switch(
                    value: _alarmMinutesBefore != null,
                    onChanged: (v) => setState(() {
                      _alarmMinutesBefore = v ? 30 : null; // 켜면 기본 30분
                    }),
                  ),
                ],
              ),
              if (_alarmMinutesBefore != null) ...[
                const SizedBox(height: 8),
                DropdownButton<int>(
                  value: _alarmMinutesBefore,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1분 전')),
                    DropdownMenuItem(value: 5, child: Text('5분 전')),
                    DropdownMenuItem(value: 10, child: Text('10분 전')),
                    DropdownMenuItem(value: 30, child: Text('30분 전')),
                    DropdownMenuItem(value: 60, child: Text('1시간 전')),
                    DropdownMenuItem(value: 120, child: Text('2시간 전')),
                    DropdownMenuItem(value: 1440, child: Text('1일 전')),
                  ],
                  onChanged: (v) => setState(() => _alarmMinutesBefore = v),
                ),
              ],

              const SizedBox(height: 20),

              // 버튼
              Row(
                children: [
                  if (widget.event != null && writable)
                    TextButton.icon(
                      key: const ValueKey('event-delete'),
                      onPressed: _saving ? null : _delete,
                      icon: const Icon(
                        Icons.delete,
                        size: 16,
                        color: Colors.red,
                      ),
                      label: const Text(
                        '삭제',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.onSurface,
                      side: BorderSide(color: context.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const ValueKey('event-save'),
                    onPressed: _saving || !writable ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.accent,
                      foregroundColor: scheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('저장'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF4A90E2);
    }
  }
}
