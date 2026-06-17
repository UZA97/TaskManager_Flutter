import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/event_repository.dart';
import '../models/event.dart';

// 현재 월
class CurrentMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void prevMonth() => state = DateTime(state.year, state.month - 1);
  void nextMonth() => state = DateTime(state.year, state.month + 1);
}

final currentMonthProvider = NotifierProvider<CurrentMonthNotifier, DateTime>(
  CurrentMonthNotifier.new,
);

// 선택된 날짜
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void select(DateTime date) => state = date;
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(
  SelectedDateNotifier.new,
);

// 이벤트 목록
class EventListNotifier extends AsyncNotifier<List<Event>> {
  @override
  Future<List<Event>> build() async {
    final month = ref.watch(currentMonthProvider);
    final repo = ref.watch(eventRepositoryProvider);
    return repo.getEventsByMonth(month.year, month.month);
  }

  Future<void> addEvent(Event event) async {
    final repo = ref.read(eventRepositoryProvider);
    await repo.addEvent(event);
    ref.invalidateSelf();
  }

  Future<void> deleteEvent(int id) async {
    final repo = ref.read(eventRepositoryProvider);
    await repo.deleteEvent(id);
    ref.invalidateSelf();
  }

  Future<void> updateCompletion(int id, bool isCompleted) async {
    final repo = ref.read(eventRepositoryProvider);
    await repo.updateCompletion(id, isCompleted);
    ref.invalidateSelf();
  }
}

final eventListProvider = AsyncNotifierProvider<EventListNotifier, List<Event>>(
  EventListNotifier.new,
);

// 선택된 날짜의 이벤트만 필터
final selectedDateEventsProvider = Provider<List<Event>>((ref) {
  final events = ref.watch(eventListProvider).value ?? [];
  final selectedDate = ref.watch(selectedDateProvider);
  final dateStr = '${selectedDate.year}-'
      '${selectedDate.month.toString().padLeft(2, '0')}-'
      '${selectedDate.day.toString().padLeft(2, '0')}';
  return events.where((e) => e.eventDate == dateStr).toList();
});
