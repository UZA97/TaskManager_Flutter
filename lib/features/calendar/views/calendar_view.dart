import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/event_provider.dart';
import '../providers/google_calendar_provider.dart';

class CalendarView extends ConsumerWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMonth = ref.watch(currentMonthProvider);
    final eventsAsync = ref.watch(eventListProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final calendarAsync = ref.watch(googleCalendarProvider);

    final eventDates = eventsAsync.value?.map((e) => e.eventDate).toSet() ?? {};

    return Column(
      children: [
        // 월 네비게이션 (기존)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    ref.read(currentMonthProvider.notifier).prevMonth(),
              ),
              Text(
                '${currentMonth.year}년 ${currentMonth.month}월',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    ref.read(currentMonthProvider.notifier).nextMonth(),
              ),
            ],
          ),
        ),

        // 요일 헤더 (기존)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: ['일', '월', '화', '수', '목', '금', '토']
                .asMap()
                .entries
                .map(
                  (e) => Expanded(
                    child: Center(
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 11,
                          color: e.key == 0
                              ? Colors.red
                              : e.key == 6
                              ? Colors.blue
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),

        // 캘린더 그리드 (기존)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _buildCalendarGrid(
            context,
            ref,
            currentMonth,
            selectedDate,
            eventDates,
          ),
        ),

        const Spacer(),

        // Google Calendar 연동 버튼
        Padding(
          padding: const EdgeInsets.all(12),
          child: calendarAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => const SizedBox(),
            data: (isConnected) => Center(
              child: isConnected
                  ? OutlinedButton.icon(
                      onPressed: () => ref
                          .read(googleCalendarProvider.notifier)
                          .disconnect(),
                      icon: const Icon(Icons.link_off, size: 14),
                      label: const Text(
                        'Google Calendar 해제',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: () =>
                          ref.read(googleCalendarProvider.notifier).connect(),
                      icon: const Icon(Icons.calendar_today, size: 14),
                      label: const Text(
                        'Google Calendar 연동',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF4A90E2),
                        side: const BorderSide(color: Color(0xFF4A90E2)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    WidgetRef ref,
    DateTime currentMonth,
    DateTime selectedDate,
    Set<String> eventDates,
  ) {
    final firstDay = DateTime(currentMonth.year, currentMonth.month, 1);
    final daysInMonth = DateTime(
      currentMonth.year,
      currentMonth.month + 1,
      0,
    ).day;
    final startWeekday = firstDay.weekday % 7;

    final cells = <Widget>[];

    // 빈 칸
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

    // 날짜
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(currentMonth.year, currentMonth.month, day);
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final isToday =
          date.year == DateTime.now().year &&
          date.month == DateTime.now().month &&
          date.day == DateTime.now().day;
      final isSelected =
          date.year == selectedDate.year &&
          date.month == selectedDate.month &&
          date.day == selectedDate.day;
      final hasEvent = eventDates.contains(dateStr);
      final weekday = (startWeekday + day - 1) % 7;

      cells.add(
        GestureDetector(
          onTap: () {
            ref.read(selectedDateProvider.notifier).select(date);
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF4A90E2)
                  : isToday
                  ? const Color(0xFFDCEBFF)
                  : hasEvent
                  ? const Color(0xFFFFF3CD)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? Colors.white
                      : weekday == 0
                      ? Colors.red
                      : weekday == 6
                      ? Colors.blue
                      : Colors.black,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      childAspectRatio: 1.2,
      children: cells,
    );
  }
}
