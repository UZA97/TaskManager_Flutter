import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event.dart';
import '../providers/event_provider.dart';
import 'calendar_editor_view.dart';

/// 반복 일정을 고치거나 지울 때 적용 범위
enum RecurringScope { thisOnly, all }

/// "이 일정만 / 모든 일정" 묻기. 취소하면 null.
Future<RecurringScope?> askRecurringScope(
  BuildContext context, {
  required String title,
}) => showDialog<RecurringScope>(
  context: context,
  builder: (context) => SimpleDialog(
    title: Text(title, style: const TextStyle(fontSize: 16)),
    children: [
      SimpleDialogOption(
        key: const ValueKey('scope-this'),
        onPressed: () => Navigator.pop(context, RecurringScope.thisOnly),
        child: const Text('이 일정만'),
      ),
      SimpleDialogOption(
        key: const ValueKey('scope-all'),
        onPressed: () => Navigator.pop(context, RecurringScope.all),
        child: const Text('모든 반복 일정'),
      ),
    ],
  ),
);

/// 일정 고칠 수 있는지 (공휴일·구독 등 읽기 전용 캘린더면 false)
bool isEventWritable(WidgetRef ref, Event event) =>
    (ref.read(googleCalendarsProvider).valueOrNull ??
            const GoogleCalendarsState())
        .isWritable(event.calendarId);

/// 일정 편집 창 열기 (새 일정은 [date]·[time]으로)
Future<void> openEventDialog(
  BuildContext context,
  WidgetRef ref, {
  Event? event,
  DateTime? date,
  TimeOfDay? time,
}) => showDialog(
  context: context,
  builder: (context) => EventDialog(
    initialDate: date ?? ref.read(selectedDateProvider),
    event: event,
    initialTime: time,
  ),
);

/// 끌어서 놓은 일정 옮기기. 반복 일정이면 범위를 묻고, 읽기 전용이면 알림만.
Future<void> moveEventTo(
  BuildContext context,
  WidgetRef ref,
  Event event,
  DateTime date, {
  String? startTime,
}) async {
  if (event.id == null) return;
  if (!isEventWritable(ref, event)) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('읽기 전용 캘린더의 일정은 옮길 수 없습니다')));
    return;
  }
  final start = DateTime.parse(event.start);
  final sameDay =
      start.year == date.year &&
      start.month == date.month &&
      start.day == date.day;
  if (sameDay && (startTime == null || startTime == event.startTime)) return;

  var wholeSeries = false;
  if (event.isRecurring) {
    final scope = await askRecurringScope(context, title: '반복 일정 옮기기');
    if (scope == null) return;
    wholeSeries = scope == RecurringScope.all;
  }
  await ref
      .read(eventListProvider.notifier)
      .moveEvent(event, date, startTime: startTime, wholeSeries: wholeSeries);
}

/// 날짜·주·일 보기에서 날짜로 이동 (보이는 달도 같이)
void goToDate(WidgetRef ref, DateTime date) {
  ref.read(currentMonthProvider.notifier).showDate(date);
  ref.read(selectedDateProvider.notifier).select(date);
}

/// 일정 색 (태그 색, 없으면 다른 캘린더의 색). 둘 다 없으면 null → 무채색으로 그림
Color? eventColor(Event event) {
  final hex = event.tagColor;
  if (hex == null) return null;
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return value == null ? null : Color(0xFF000000 | value);
}
