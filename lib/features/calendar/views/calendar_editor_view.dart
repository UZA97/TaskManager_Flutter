import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/event_provider.dart';
import '../models/event.dart';
import '../data/event_repository.dart';
import '../../map/services/vworld_service.dart';
import '../../map/widgets/location_search_dialog.dart';
// import '../models/event_tag.dart';
// import '../../../core/notification/notification_service.dart';
// import '../../../core/providers/navigation_provider.dart';
// import '../../map/providers/map_provider.dart';
// import 'package:latlong2/latlong.dart';

class CalendarEditorView extends ConsumerWidget {
  const CalendarEditorView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMonth = ref.watch(currentMonthProvider);
    final eventsAsync = ref.watch(eventListProvider);
    final tagFilter = ref.watch(tagFilterProvider);

    return Column(
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFDDDDDD))),
          ),
          child: Row(
            children: [
              Text(
                '${currentMonth.year}년 ${currentMonth.month}월',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // 오늘 버튼
              OutlinedButton(
                onPressed: () {
                  final now = DateTime.now();
                  ref.read(currentMonthProvider.notifier).setYear(now.year);
                  ref.read(selectedDateProvider.notifier).select(now);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  side: const BorderSide(color: Color(0xFFDDDDDD)),
                ),
                child: const Text('오늘', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              // 일정 추가 버튼
              ElevatedButton.icon(
                onPressed: () => _showEventDialog(context, ref, null),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('일정 추가', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 요일 헤더
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
          ),
          child: Row(
            children: ['일', '월', '화', '수', '목', '금', '토']
                .asMap()
                .entries
                .map(
                  (e) => Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: e.key == 0
                                ? Colors.red
                                : e.key == 6
                                ? Colors.blue
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),

        // 캘린더 그리드
        Expanded(
          child: eventsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
            data: (events) => _CalendarGrid(
              currentMonth: currentMonth,
              events: events,
              onDateTap: (date) {
                ref.read(selectedDateProvider.notifier).select(date);
                _showEventDialog(context, ref, date);
              },
              onEventTap: (event) =>
                  _showEventDialog(context, ref, null, event: event),
            ),
          ),
        ),
      ],
    );
  }

  void _showEventDialog(
    BuildContext context,
    WidgetRef ref,
    DateTime? date, {
    Event? event,
  }) {
    showDialog(
      context: context,
      builder: (context) => _EventDialog(
        initialDate: date ?? ref.read(selectedDateProvider),
        event: event,
      ),
    );
  }
}

// ── 캘린더 그리드 ─────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime currentMonth;
  final List<Event> events;
  final void Function(DateTime) onDateTap;
  final void Function(Event) onEventTap;

  const _CalendarGrid({
    required this.currentMonth,
    required this.events,
    required this.onDateTap,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(currentMonth.year, currentMonth.month, 1);
    final daysInMonth = DateTime(
      currentMonth.year,
      currentMonth.month + 1,
      0,
    ).day;
    final startWeekday = firstDay.weekday % 7;
    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (rowIndex) {
        return Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(7, (colIndex) {
              final cellIndex = rowIndex * 7 + colIndex;
              final day = cellIndex - startWeekday + 1;

              if (day < 1 || day > daysInMonth) {
                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                      color: const Color(0xFFF9F9F9),
                    ),
                  ),
                );
              }

              final date = DateTime(currentMonth.year, currentMonth.month, day);
              final dateStr =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final isToday =
                  date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;
              final dayEvents = events
                  .where((e) => e.eventDate == dateStr)
                  .toList();

              return Expanded(
                child: _CalendarCell(
                  date: date,
                  day: day,
                  isToday: isToday,
                  isSunday: colIndex == 0,
                  isSaturday: colIndex == 6,
                  events: dayEvents,
                  onTap: () => onDateTap(date),
                  onEventTap: onEventTap,
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

// ── 날짜 셀 ───────────────────────────────────────────────
class _CalendarCell extends StatelessWidget {
  final DateTime date;
  final int day;
  final bool isToday;
  final bool isSunday;
  final bool isSaturday;
  final List<Event> events;
  final VoidCallback onTap;
  final void Function(Event) onEventTap;

  const _CalendarCell({
    required this.date,
    required this.day,
    required this.isToday,
    required this.isSunday,
    required this.isSaturday,
    required this.events,
    required this.onTap,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFEEEEEE)),
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
                    ? const BoxDecoration(
                        color: Color(0xFF4A90E2),
                        shape: BoxShape.circle,
                      )
                    : null,
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      color: isToday
                          ? Colors.white
                          : isSunday
                          ? Colors.red
                          : isSaturday
                          ? Colors.blue
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            // 일정 목록
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                itemCount: events.length > 3 ? 3 : events.length,
                itemBuilder: (context, index) {
                  if (index == 2 && events.length > 3) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        '+${events.length - 2}개',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  }
                  final event = events[index];
                  return GestureDetector(
                    onTap: () {
                      onEventTap(event);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90E2).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        event.title.isEmpty ? '(제목 없음)' : event.title,
                        style: const TextStyle(fontSize: 10),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 일정 다이얼로그 ───────────────────────────────────────
class _EventDialog extends ConsumerStatefulWidget {
  final DateTime initialDate;
  final Event? event;

  const _EventDialog({required this.initialDate, this.event});

  @override
  ConsumerState<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends ConsumerState<_EventDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _locationController = TextEditingController();
  bool _isAllDay = true;
  bool _alarmEnabled = false;
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  Set<int> _selectedTagIds = {};
  double? _locationLat;
  double? _locationLng;

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
    }

    // 태그 로드
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.event?.id != null) {
        final repo = ref.read(eventRepositoryProvider);
        final tags = await repo.getEventTags(widget.event!.id!);
        setState(() => _selectedTagIds = tags.map((t) => t.id!).toSet());
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

  Future<void> _pickLocation() async {
    final result = await showDialog<VworldSearchResult>(
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

  Future<void> _save() async {
    if (_titleController.text.isEmpty) return;

    final startDateStr = _formatDate(_startDate ?? widget.initialDate);
    final endDateStr = _formatDate(_endDate ?? widget.initialDate);

    final event = Event(
      id: widget.event?.id,
      title: _titleController.text,
      eventDate: startDateStr,
      createdAt: widget.event?.createdAt ?? DateTime.now().toIso8601String(),
      alarmEnabled: _alarmEnabled,
      alarmTime: _startTime != null
          ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
          : '09:00',
      alarmDaysBefore: 0,
      isAllDay: _isAllDay,
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
    );

    final notifier = ref.read(eventListProvider.notifier);
    if (widget.event != null) {
      await notifier.updateEvent(event);
    } else {
      await notifier.addEvent(event);
    }

    // 태그 저장
    if (event.id != null || widget.event == null) {
      final repo = ref.read(eventRepositoryProvider);
      final savedId =
          widget.event?.id ?? (ref.read(eventListProvider).value?.last.id);
      if (savedId != null) {
        await repo.setEventTags(savedId, _selectedTagIds.toList());
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(eventTagProvider);

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
                  fontWeight: FontWeight.bold,
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
                        const Text(
                          '시작',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _pickDate(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFDDDDDD),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _formatDate(_startDate ?? widget.initialDate),
                              style: const TextStyle(fontSize: 12),
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
                                border: Border.all(
                                  color: const Color(0xFFDDDDDD),
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _startTime != null
                                    ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                                    : '시간 선택',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _startTime == null
                                      ? Colors.grey
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('~', style: TextStyle(color: Colors.grey)),
                  ),
                  // 종료
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '종료',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => _pickDate(false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFDDDDDD),
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _formatDate(_endDate ?? widget.initialDate),
                              style: const TextStyle(fontSize: 12),
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
                                border: Border.all(
                                  color: const Color(0xFFDDDDDD),
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _endTime != null
                                    ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                                    : '시간 선택',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _endTime == null ? Colors.grey : null,
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
                ],
              ),
              const SizedBox(height: 12),

              // 태그
              const Text(
                '태그',
                style: TextStyle(fontSize: 11, color: Colors.grey),
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
                        spacing: 6,
                        runSpacing: 6,
                        children: tags.map((tag) {
                          final isSelected = _selectedTagIds.contains(tag.id);
                          final color = _hexToColor(tag.color);
                          return GestureDetector(
                            onTap: () => setState(() {
                              if (isSelected) {
                                _selectedTagIds.remove(tag.id);
                              } else {
                                _selectedTagIds.add(tag.id!);
                              }
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color
                                    : color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: color),
                              ),
                              child: Text(
                                tag.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : color,
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

              // 알림
              Row(
                children: [
                  const Text('알림', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  Switch(
                    value: _alarmEnabled,
                    onChanged: (v) => setState(() => _alarmEnabled = v),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 버튼
              Row(
                children: [
                  if (widget.event != null)
                    TextButton.icon(
                      onPressed: () {
                        ref
                            .read(eventListProvider.notifier)
                            .deleteEvent(widget.event!.id!);
                        Navigator.pop(context);
                      },
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
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
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
