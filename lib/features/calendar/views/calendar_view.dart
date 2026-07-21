import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/event_provider.dart';
import '../providers/google_calendar_provider.dart';
import '../models/event_tag.dart';

class CalendarView extends ConsumerWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _MiniCalendar(),
        const Divider(height: 1),
        _TagFilterSection(),
        const Divider(height: 1),
        Expanded(child: _SelectedDateEventList()),
      ],
    );
  }
}

// ── 미니 캘린더 ──────────────────────────────────────────
class _MiniCalendar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMonth = ref.watch(currentMonthProvider);
    final eventsAsync = ref.watch(eventListProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final eventDates = eventsAsync.value?.map((e) => e.eventDate).toSet() ?? {};

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // 월 네비게이션
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                onPressed: () =>
                    ref.read(currentMonthProvider.notifier).prevMonth(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              // 연도 클릭 시 팝업
              GestureDetector(
                onTap: () => _showYearPicker(context, ref, currentMonth),
                child: Text(
                  '${currentMonth.year}년 ${currentMonth.month}월',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                onPressed: () =>
                    ref.read(currentMonthProvider.notifier).nextMonth(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 요일 헤더
          Row(
            children: ['일', '월', '화', '수', '목', '금', '토']
                .asMap()
                .entries
                .map(
                  (e) => Expanded(
                    child: Center(
                      child: Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 10,
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
          const SizedBox(height: 2),
          // 날짜 그리드
          _buildCalendarGrid(
            context,
            ref,
            currentMonth,
            selectedDate,
            eventDates,
          ),
        ],
      ),
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
    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox());
    }

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
          onTap: () => ref.read(selectedDateProvider.notifier).select(date),
          child: Container(
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF4A90E2)
                  : isToday
                  ? const Color(0xFFDCEBFF)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected
                        ? Colors.white
                        : weekday == 0
                        ? Colors.red
                        : weekday == 6
                        ? Colors.blue
                        : null,
                  ),
                ),
                if (hasEvent)
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF4A90E2),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      childAspectRatio: 1.1,
      children: cells,
    );
  }

  void _showYearPicker(
    BuildContext context,
    WidgetRef ref,
    DateTime currentMonth,
  ) {
    final currentYear = currentMonth.year;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('연도 선택'),
        content: SizedBox(
          width: 200,
          height: 300,
          child: GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 1.5,
            children: List.generate(12, (i) {
              final year = currentYear - 5 + i;
              final isSelected = year == currentYear;
              return GestureDetector(
                onTap: () {
                  ref.read(currentMonthProvider.notifier).setYear(year);
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4A90E2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      '$year',
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected ? Colors.white : null,
                        fontWeight: isSelected ? FontWeight.bold : null,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── 태그 필터 ─────────────────────────────────────────────
class _TagFilterSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(eventTagProvider);
    final tagFilter = ref.watch(tagFilterProvider);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '태그 필터',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showAddTagDialog(context, ref),
                child: const Icon(Icons.add, size: 16, color: Colors.grey),
              ),
              if (tagFilter.isNotEmpty) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => ref.read(tagFilterProvider.notifier).clear(),
                  child: const Text(
                    '초기화',
                    style: TextStyle(fontSize: 10, color: Color(0xFF4A90E2)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          tagsAsync.when(
            loading: () => const SizedBox(),
            error: (e, _) => const SizedBox(),
            data: (tags) => tags.isEmpty
                ? const Text(
                    '태그 없음',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  )
                : Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: tags.map((tag) {
                      final isSelected = tagFilter.contains(tag.id);
                      final color = _hexToColor(tag.color);
                      return GestureDetector(
                        onLongPress: () =>
                            _showDeleteTagDialog(context, ref, tag),
                        onTap: () => ref
                            .read(tagFilterProvider.notifier)
                            .toggle(tag.id!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? color : color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: color,
                              width: isSelected ? 0 : 1,
                            ),
                          ),
                          child: Text(
                            tag.name,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? Colors.white : color,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
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

  void _showAddTagDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String selectedColor = '#4A90E2';

    final colors = [
      '#E53935',
      '#FF9800',
      '#FFB300',
      '#4CAF50',
      '#4A90E2',
      '#9C27B0',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('태그 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(hintText: '태그 이름'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: colors.map((hex) {
                  final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                  final isSelected = selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = hex),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  ref
                      .read(eventTagProvider.notifier)
                      .createTag(nameController.text, selectedColor);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteTagDialog(BuildContext context, WidgetRef ref, EventTag tag) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('태그 삭제'),
        content: Text('"${tag.name}" 태그를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              ref.read(eventTagProvider.notifier).deleteTag(tag.id!);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// ── 선택 날짜 일정 리스트 ─────────────────────────────────
class _SelectedDateEventList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedEvents = ref.watch(selectedDateEventsProvider);
    final dateStr =
        '${selectedDate.year}년 ${selectedDate.month}월 ${selectedDate.day}일';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Text(
            dateStr,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: selectedEvents.isEmpty
              ? const Center(
                  child: Text(
                    '일정 없음',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  itemCount: selectedEvents.length,
                  itemBuilder: (context, index) {
                    final event = selectedEvents[index];
                    return ListTile(
                      dense: true,
                      leading: Checkbox(
                        value: event.isCompleted,
                        onChanged: (v) => ref
                            .read(eventListProvider.notifier)
                            .updateCompletion(event.id!, v ?? false),
                      ),
                      title: Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 12,
                          decoration: event.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: event.isCompleted ? Colors.grey : null,
                        ),
                      ),
                      subtitle: event.isAllDay
                          ? null
                          : Text(
                              '${event.startTime ?? ''} ~ ${event.endTime ?? ''}',
                              style: const TextStyle(fontSize: 10),
                            ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () => ref
                            .read(eventListProvider.notifier)
                            .deleteEvent(event.id!),
                      ),
                    );
                  },
                ),
        ),
        // Google Calendar 연동 버튼
        Padding(
          padding: const EdgeInsets.all(8),
          child: ref
              .watch(googleCalendarProvider)
              .when(
                loading: () => const SizedBox(),
                error: (e, _) => const SizedBox(),
                data: (isConnected) => SizedBox(
                  width: double.infinity,
                  child: isConnected
                      ? OutlinedButton.icon(
                          onPressed: () => ref
                              .read(googleCalendarProvider.notifier)
                              .disconnect(),
                          icon: const Icon(Icons.link_off, size: 14),
                          label: const Text(
                            'Google Calendar 해제',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: () => ref
                              .read(googleCalendarProvider.notifier)
                              .connect(),
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: const Text(
                            'Google Calendar 연동',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4A90E2),
                            side: const BorderSide(color: Color(0xFF4A90E2)),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                ),
              ),
        ),
      ],
    );
  }
}
