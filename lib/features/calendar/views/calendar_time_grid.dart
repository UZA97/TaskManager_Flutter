import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taskmanager/core/theme/app_colors.dart';

import '../models/event.dart';
import '../providers/event_provider.dart';
import 'calendar_actions.dart';

const _hourHeight = 48.0;
const _gutter = 56.0;
const _snapMinutes = 15;
const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

/// 시간대별 일정 (주 보기는 7일, 일 보기는 하루).
/// 일정을 끌어 다른 날·시각으로 옮기고, 빈 칸을 누르면 그 시각으로 새 일정.
class CalendarTimeGrid extends ConsumerStatefulWidget {
  const CalendarTimeGrid({super.key, required this.days, required this.events});

  final List<DateTime> days;
  final List<Event> events;

  @override
  ConsumerState<CalendarTimeGrid> createState() => _CalendarTimeGridState();
}

class _CalendarTimeGridState extends ConsumerState<CalendarTimeGrid> {
  // 처음엔 오전 7시 반부터 보이게
  final _scroll = ScrollController(initialScrollOffset: _hourHeight * 7.5);
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    // 지금 시각 선을 1분마다 옮김
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// 종일 칸에 넣을 일정: 종일 일정과 여러 날에 걸친 일정
  static bool _inAllDayRow(Event e) => e.isAllDay || e.start != e.end;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final allDay = [
      for (final day in widget.days)
        [
          for (final e in eventsOn(widget.events, day))
            if (_inAllDayRow(e)) e,
        ],
    ];
    final allDayRows = allDay.fold<int>(
      0,
      (m, list) => list.length > m ? list.length : m,
    );

    return Column(
      children: [
        // 요일·날짜 (누르면 그날의 일 보기)
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.lineSubtle)),
          ),
          child: Row(
            children: [
              const SizedBox(width: _gutter),
              for (final day in widget.days)
                Expanded(
                  child: _DayHeader(
                    day: day,
                    isToday: _sameDay(day, now),
                    onTap: () {
                      goToDate(ref, day);
                      ref
                          .read(calendarViewModeProvider.notifier)
                          .set(CalendarViewMode.day);
                    },
                  ),
                ),
            ],
          ),
        ),
        // 종일 일정
        Container(
          constraints: BoxConstraints(
            minHeight: 30,
            maxHeight: 30.0 + 22 * (allDayRows.clamp(1, 4) - 1),
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _gutter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: Text(
                    '종일',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, color: muted),
                  ),
                ),
              ),
              for (var i = 0; i < widget.days.length; i++)
                Expanded(
                  child: DragTarget<Event>(
                    onAcceptWithDetails: (details) =>
                        moveEventTo(context, ref, details.data, widget.days[i]),
                    builder: (context, candidates, _) => Container(
                      decoration: BoxDecoration(
                        color: candidates.isEmpty
                            ? null
                            : context.accent.withValues(alpha: 0.08),
                        border: Border(
                          left: BorderSide(color: context.lineSubtle),
                        ),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(2),
                        children: [
                          for (final e in allDay[i])
                            _EventChip(event: e, height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // 시간표
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: _hourHeight * 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: _gutter,
                    child: Stack(
                      children: [
                        for (var h = 1; h < 24; h++)
                          Positioned(
                            top: h * _hourHeight - 7,
                            right: 8,
                            child: Text(
                              _hourLabel(h),
                              style: TextStyle(fontSize: 10, color: muted),
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final day in widget.days)
                    Expanded(
                      child: _DayColumn(
                        day: day,
                        now: _sameDay(day, now) ? now : null,
                        events: [
                          for (final e in eventsOn(widget.events, day))
                            if (!_inAllDayRow(e)) e,
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _hourLabel(int h) => h < 12
    ? '오전 $h시'
    : h == 12
    ? '오후 12시'
    : '오후 ${h - 12}시';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int _minutes(String? time, {int fallback = 0}) {
  if (time == null) return fallback;
  final parts = time.split(':');
  if (parts.length < 2) return fallback;
  return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
}

String _time(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.isToday,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final weekday = day.weekday % 7;
    final scheme = Theme.of(context).colorScheme;
    final color = weekday == 0
        ? Colors.red
        : weekday == 6
        ? Colors.blue
        : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Text(
              _weekdays[weekday],
              style: TextStyle(fontSize: 11, color: color),
            ),
            const SizedBox(height: 2),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: isToday
                  ? BoxDecoration(color: context.accent, shape: BoxShape.circle)
                  : null,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isToday ? scheme.onPrimary : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 하루치 시간표 칸
class _DayColumn extends ConsumerWidget {
  const _DayColumn({required this.day, required this.events, this.now});

  final DateTime day;
  final List<Event> events;

  /// 오늘이면 지금 시각 (빨간 선)
  final DateTime? now;

  /// 칸 안의 세로 위치 → 15분 단위 시각(분)
  static int _minutesAt(double dy) {
    final raw = (dy / _hourHeight * 60).round();
    final snapped = (raw / _snapMinutes).round() * _snapMinutes;
    return snapped.clamp(0, 24 * 60 - _snapMinutes);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final placed = _layout(events);
        return DragTarget<Event>(
          onAcceptWithDetails: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final top = box.globalToLocal(details.offset).dy;
            final event = details.data;
            moveEventTo(
              context,
              ref,
              event,
              day,
              startTime: event.isAllDay ? null : _time(_minutesAt(top)),
            );
          },
          builder: (context, candidates, _) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            // 빈 곳을 누르면 그 시각으로 새 일정
            onTapUp: (details) {
              final minutes = _minutesAt(details.localPosition.dy - 12);
              openEventDialog(
                context,
                ref,
                date: day,
                time: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: candidates.isEmpty
                    ? null
                    : context.accent.withValues(alpha: 0.05),
                border: Border(left: BorderSide(color: context.lineSubtle)),
              ),
              child: Stack(
                children: [
                  for (var h = 1; h < 24; h++)
                    Positioned(
                      top: h * _hourHeight,
                      left: 0,
                      right: 0,
                      child: Divider(height: 1, color: context.lineSubtle),
                    ),
                  for (final p in placed)
                    Positioned(
                      top: p.top,
                      height: p.height,
                      left: width * p.lane / p.lanes + 1,
                      width: width / p.lanes - 3,
                      child: _EventChip(
                        event: p.event,
                        height: p.height,
                        width: width / p.lanes - 3,
                        showTime: true,
                      ),
                    ),
                  if (now != null)
                    Positioned(
                      top: (now!.hour * 60 + now!.minute) / 60 * _hourHeight,
                      left: 0,
                      right: 0,
                      child: Container(height: 2, color: Colors.red),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 겹치는 일정은 나란히 (겹치는 묶음마다 칸을 나눔)
List<({Event event, double top, double height, int lane, int lanes})> _layout(
  List<Event> events,
) {
  final items = [
    for (final e in events)
      (
        event: e,
        start: _minutes(e.startTime, fallback: 9 * 60),
        end: () {
          final start = _minutes(e.startTime, fallback: 9 * 60);
          final end = _minutes(e.endTime, fallback: start + 60);
          return end > start ? end : start + 30;
        }(),
      ),
  ]..sort((a, b) => a.start.compareTo(b.start));

  final result =
      <({Event event, double top, double height, int lane, int lanes})>[];
  var group = <({Event event, int start, int end, int lane})>[];
  var groupEnd = -1;

  void flush() {
    final lanes = group.fold<int>(0, (m, g) => g.lane + 1 > m ? g.lane + 1 : m);
    for (final g in group) {
      final top = g.start / 60 * _hourHeight;
      final height = ((g.end - g.start) / 60 * _hourHeight).clamp(
        20.0,
        24 * _hourHeight - top,
      );
      result.add((
        event: g.event,
        top: top,
        height: height,
        lane: g.lane,
        lanes: lanes,
      ));
    }
    group = [];
  }

  for (final item in items) {
    if (item.start >= groupEnd && group.isNotEmpty) flush();
    // 비어 있는 가장 왼쪽 칸
    var lane = 0;
    while (group.any((g) => g.lane == lane && g.end > item.start)) {
      lane++;
    }
    group.add((
      event: item.event,
      start: item.start,
      end: item.end,
      lane: lane,
    ));
    if (item.end > groupEnd) groupEnd = item.end;
  }
  if (group.isNotEmpty) flush();
  return result;
}

/// 일정 상자 (눌러서 열기, 끌어서 옮기기)
class _EventChip extends ConsumerWidget {
  const _EventChip({
    required this.event,
    required this.height,
    this.width,
    this.showTime = false,
  });

  final Event event;
  final double height;
  final double? width;
  final bool showTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final color = eventColor(event);
    final background =
        color?.withValues(alpha: 0.85) ?? scheme.surfaceContainerHighest;
    final foreground = color != null ? Colors.white : scheme.onSurface;
    final title = event.title.isEmpty ? '(제목 없음)' : event.title;

    Widget box({double opacity = 1}) => Opacity(
      opacity: opacity,
      child: Container(
        height: height,
        width: width,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              if (event.isRecurring)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Icon(Icons.repeat, size: 10, color: foreground),
                  ),
                ),
              TextSpan(
                text: title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (showTime && event.startTime != null)
                TextSpan(
                  text: height >= 36
                      ? '\n${event.startTime}${event.endTime != null ? ' ~ ${event.endTime}' : ''}'
                      : '  ${event.startTime}',
                ),
            ],
          ),
          style: TextStyle(fontSize: 11, color: foreground, height: 1.3),
          overflow: TextOverflow.ellipsis,
          maxLines: height >= 36 ? (height / 15).floor() : 1,
        ),
      ),
    );

    final chip = GestureDetector(
      onTap: () => openEventDialog(context, ref, event: event),
      child: MouseRegion(cursor: SystemMouseCursors.click, child: box()),
    );
    if (!isEventWritable(ref, event)) return chip;
    return Draggable<Event>(
      data: event,
      feedback: Material(
        color: Colors.transparent,
        elevation: 4,
        child: SizedBox(width: width ?? 160, child: box(opacity: 0.9)),
      ),
      childWhenDragging: box(opacity: 0.35),
      child: chip,
    );
  }
}
