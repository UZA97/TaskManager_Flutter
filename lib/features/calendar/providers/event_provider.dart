import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/event_repository.dart';
import '../models/event.dart';
import '../models/event_tag.dart';
import '../services/google_calendar_service.dart';
import '../../../core/database/database_provider.dart';
import '../../mail/services/google_auth_service.dart';
import '../../../core/database/database.dart';

// 태그 provider 추가
class EventTagNotifier extends AsyncNotifier<List<EventTag>> {
  @override
  Future<List<EventTag>> build() async {
    final repo = ref.watch(eventRepositoryProvider);
    return repo.getAllTags();
  }

  Future<void> createTag(String name, String color) async {
    final repo = ref.read(eventRepositoryProvider);
    await repo.createTag(name, color);
    ref.invalidateSelf();
  }

  Future<void> deleteTag(int id) async {
    final repo = ref.read(eventRepositoryProvider);
    await repo.deleteTag(id);
    ref.invalidateSelf();
  }
}

final eventTagProvider =
    AsyncNotifierProvider<EventTagNotifier, List<EventTag>>(
      EventTagNotifier.new,
    );

// 태그 필터 provider
class TagFilterNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => {};

  void toggle(int tagId) {
    final current = Set<int>.from(state);
    if (current.contains(tagId)) {
      current.remove(tagId);
    } else {
      current.add(tagId);
    }
    state = current;
  }

  void clear() => state = {};
}

final tagFilterProvider = NotifierProvider<TagFilterNotifier, Set<int>>(
  TagFilterNotifier.new,
);

// 현재 월
class CurrentMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void prevMonth() => state = DateTime(state.year, state.month - 1);
  void nextMonth() => state = DateTime(state.year, state.month + 1);
  void setYear(int year) => state = DateTime(year, state.month);
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
  final _calendarService = GoogleCalendarService();
  // final _authService = GoogleAuthService();

  @override
  Future<List<Event>> build() async {
    final month = ref.watch(currentMonthProvider);
    final repo = ref.watch(eventRepositoryProvider);
    final tagFilter = ref.watch(tagFilterProvider);

    await _syncGoogleCalendar(month.year, month.month);

    final events = await repo.getEventsByMonth(month.year, month.month);

    if (tagFilter.isEmpty) return events;

    // 태그 필터 적용
    final filtered = <Event>[];
    for (final event in events) {
      if (event.id == null) continue;
      final tags = await repo.getEventTags(event.id!);
      if (tags.any((t) => tagFilter.contains(t.id))) {
        filtered.add(event);
      }
    }
    return filtered;
  }

  Future<String?> _getAccessToken() async {
    final db = ref.read(databaseProvider);

    // access token 읽기
    final tokenRow = await (db.select(
      db.settingTable,
    )..where((t) => t.key.equals('calendar_access_token'))).getSingleOrNull();
    if (tokenRow == null || tokenRow.value.isEmpty) return null;

    // refresh token으로 갱신 시도
    final refreshRow = await (db.select(
      db.settingTable,
    )..where((t) => t.key.equals('calendar_refresh_token'))).getSingleOrNull();
    if (refreshRow == null) return tokenRow.value;

    final authService = GoogleAuthService();
    final newToken = await authService.refreshAccessToken(refreshRow.value);
    if (newToken == null) return tokenRow.value;

    // 갱신된 token 저장
    await db
        .into(db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion.insert(
            key: 'calendar_access_token',
            value: newToken,
          ),
        );

    return newToken;
  }

  Future<void> _syncGoogleCalendar(int year, int month) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) return;

      final repo = ref.read(eventRepositoryProvider);
      final googleEvents = await _calendarService.getEvents(
        accessToken,
        year,
        month,
      );

      for (final event in googleEvents) {
        await repo.upsertGoogleEvent(event);
      }
    } catch (e) {
      // Google Calendar 동기화 오류는 사용자 인터페이스에 영향을 주지 않도록 로그 없이 무시
    }
  }

  Future<void> addEvent(Event event) async {
    final repo = ref.read(eventRepositoryProvider);

    // Google Calendar에도 추가
    final accessToken = await _getAccessToken();
    if (accessToken != null) {
      final googleEventId = await _calendarService.addEvent(accessToken, event);
      if (googleEventId != null) {
        await repo.addEvent(event.copyWith(googleEventId: googleEventId));
        ref.invalidateSelf();
        return;
      }
    }

    await repo.addEvent(event);
    ref.invalidateSelf();
  }

  Future<void> updateEvent(Event event) async {
    final repo = ref.read(eventRepositoryProvider);
    await repo.updateEvent(event);
    ref.invalidateSelf();
  }

  Future<void> deleteEvent(int id) async {
    final repo = ref.read(eventRepositoryProvider);
    final events = state.value ?? [];
    final event = events.firstWhere((e) => e.id == id);

    // Google Calendar에서도 삭제
    if (event.googleEventId != null && event.googleEventId!.isNotEmpty) {
      final accessToken = await _getAccessToken();
      if (accessToken != null) {
        await _calendarService.deleteEvent(accessToken, event.googleEventId!);
      }
    }

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
  final dateStr =
      '${selectedDate.year}-'
      '${selectedDate.month.toString().padLeft(2, '0')}-'
      '${selectedDate.day.toString().padLeft(2, '0')}';
  return events.where((e) => e.eventDate == dateStr).toList();
});
