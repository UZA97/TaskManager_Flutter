import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/event.dart';
import '../providers/event_provider.dart';
import '../../../core/notification/notification_service.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../map/providers/map_provider.dart';
import '../../map/services/vworld_service.dart';
import '../../map/widgets/location_search_dialog.dart';

class CalendarEditorView extends ConsumerStatefulWidget {
  const CalendarEditorView({super.key});

  @override
  ConsumerState<CalendarEditorView> createState() => _CalendarEditorViewState();
}

class _CalendarEditorViewState extends ConsumerState<CalendarEditorView> {
  final _titleController = TextEditingController();
  bool _alarmEnabled = false;
  bool _alarmDaysEnabled = false;
  int _alarmHour = 9;
  int _alarmMinute = 0;
  int _alarmDaysBefore = 1;
  int _priority = 1;
  String? _locationName;
  double? _locationLat;
  double? _locationLng;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _saveEvent() {
    if (_titleController.text.isEmpty) return;
    final selectedDate = ref.read(selectedDateProvider);
    final dateStr =
        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
    final alarmTime =
        '${_alarmHour.toString().padLeft(2, '0')}:${_alarmMinute.toString().padLeft(2, '0')}';

    final event = Event(
      title: _titleController.text,
      eventDate: dateStr,
      createdAt: DateTime.now().toIso8601String(),
      alarmEnabled: _alarmEnabled,
      alarmTime: alarmTime,
      alarmDaysBefore: _alarmDaysEnabled ? _alarmDaysBefore : 0,
      priority: _priority,
      locationName: _locationName,
      locationLat: _locationLat,
      locationLng: _locationLng,
    );

    ref.read(eventListProvider.notifier).addEvent(event);
    _titleController.clear();
    setState(() {
      _alarmEnabled = false;
      _alarmDaysEnabled = false;
      _locationName = null;
      _locationLat = null;
      _locationLng = null;
    });
  }

  Future<void> _pickLocation() async {
    final result = await showDialog<VworldSearchResult>(
      context: context,
      builder: (context) => const LocationSearchDialog(),
    );
    if (result == null) return;
    setState(() {
      _locationName = result.name;
      _locationLat = result.lat;
      _locationLng = result.lng;
    });
  }

  void _goToMap() {
    if (_locationName == null) return;
    final container = ProviderScope.containerOf(context);
    container
        .read(selectedLocationProvider.notifier)
        .select(
          SelectedLocation(
            name: _locationName!,
            position: LatLng(_locationLat!, _locationLng!),
          ),
        );
    container.read(navigationProvider.notifier).navigateTo(3);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedEvents = ref.watch(selectedDateEventsProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 타이틀
          Text(
            '${selectedDate.year}년 ${selectedDate.month}월 ${selectedDate.day}일',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 제목 입력
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: '일정 제목',
              border: UnderlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // 당일 알람
          Row(
            children: [
              Checkbox(
                value: _alarmEnabled,
                onChanged: (v) => setState(() => _alarmEnabled = v ?? false),
              ),
              const Text('당일 알람', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              if (_alarmEnabled) ...[
                DropdownButton<int>(
                  value: _alarmHour,
                  isDense: true,
                  items: List.generate(
                    24,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(
                        '${i.toString().padLeft(2, '0')}시',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  onChanged: (v) => setState(() => _alarmHour = v ?? 9),
                ),
                const SizedBox(width: 4),
                DropdownButton<int>(
                  value: _alarmMinute,
                  isDense: true,
                  items: List.generate(
                    12,
                    (i) => DropdownMenuItem(
                      value: i * 5,
                      child: Text(
                        '${(i * 5).toString().padLeft(2, '0')}분',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  onChanged: (v) => setState(() => _alarmMinute = v ?? 0),
                ),
              ],
            ],
          ),

          // 며칠 전 알람
          Row(
            children: [
              Checkbox(
                value: _alarmDaysEnabled,
                onChanged: (v) =>
                    setState(() => _alarmDaysEnabled = v ?? false),
              ),
              const Text('며칠 전 알람', style: TextStyle(fontSize: 13)),
              if (_alarmDaysEnabled) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(isDense: true),
                    onChanged: (v) => _alarmDaysBefore = int.tryParse(v) ?? 1,
                    controller: TextEditingController(
                      text: '$_alarmDaysBefore',
                    ),
                  ),
                ),
                const Text(' 일 전', style: TextStyle(fontSize: 13)),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // 장소
          Row(
            children: [
              const Text('장소: ', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              if (_locationName == null)
                OutlinedButton.icon(
                  onPressed: _pickLocation,
                  icon: const Icon(Icons.location_on, size: 14),
                  label: const Text('장소 추가', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    side: const BorderSide(color: Color(0xFFDDDDDD)),
                    foregroundColor: Colors.grey[700],
                  ),
                )
              else
                GestureDetector(
                  onTap: _goToMap,
                  child: Chip(
                    label: Text(
                      _locationName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4A90E2),
                      ),
                    ),
                    avatar: const Icon(
                      Icons.location_pin,
                      color: Color(0xFFE53935),
                      size: 14,
                    ),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() {
                      _locationName = null;
                      _locationLat = null;
                      _locationLng = null;
                    }),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // 우선순위
          Row(
            children: [
              const Text('우선순위: ', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _priority,
                isDense: true,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('낮음')),
                  DropdownMenuItem(value: 2, child: Text('보통')),
                  DropdownMenuItem(value: 3, child: Text('높음')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 1),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 저장 버튼
          Row(
            children: [
              ElevatedButton(
                onPressed: _saveEvent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90E2),
                  foregroundColor: Colors.white,
                ),
                child: const Text('저장'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  final selectedDate = ref.read(selectedDateProvider);
                  NotificationService.showAlarm('테스트 알람', selectedDate);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5A623),
                  foregroundColor: Colors.white,
                ),
                child: const Text('🔔 알람 테스트'),
              ),
            ],
          ),

          const Divider(height: 24),

          // 일정 목록
          Expanded(
            child: selectedEvents.isEmpty
                ? const Center(
                    child: Text(
                      '일정이 없어요',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: selectedEvents.length,
                    itemBuilder: (context, index) {
                      final event = selectedEvents[index];
                      return ListTile(
                        leading: Checkbox(
                          value: event.isCompleted,
                          onChanged: (v) => ref
                              .read(eventListProvider.notifier)
                              .updateCompletion(event.id!, v ?? false),
                        ),
                        title: Text(
                          event.title,
                          style: TextStyle(
                            decoration: event.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: event.isCompleted ? Colors.grey : null,
                          ),
                        ),
                        subtitle: event.locationName != null
                            ? GestureDetector(
                                onTap: () {
                                  if (event.locationLat == null) return;
                                  final container = ProviderScope.containerOf(
                                    context,
                                  );
                                  container
                                      .read(selectedLocationProvider.notifier)
                                      .select(
                                        SelectedLocation(
                                          name: event.locationName!,
                                          position: LatLng(
                                            event.locationLat!,
                                            event.locationLng!,
                                          ),
                                        ),
                                      );
                                  container
                                      .read(navigationProvider.notifier)
                                      .navigateTo(3);
                                },
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_pin,
                                      size: 12,
                                      color: Color(0xFFE53935),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      event.locationName!,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF4A90E2),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => ref
                              .read(eventListProvider.notifier)
                              .deleteEvent(event.id!),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
