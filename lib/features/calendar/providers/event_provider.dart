import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/event_repository.dart';
import '../models/event.dart';
import '../models/event_tag.dart';
import '../services/google_calendar_service.dart';
import '../../../core/auth/google_account_provider.dart';

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
  void setMonth(int month) => state = DateTime(state.year, month);
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

  @override
  Future<List<Event>> build() async {
    final month = ref.watch(currentMonthProvider);
    final repo = ref.watch(eventRepositoryProvider);
    final tagFilter = ref.watch(tagFilterProvider);

    await _syncGoogleCalendar(month.year, month.month);

    final events = await repo.getEventsByMonth(month.year, month.month);
    print('태그 미필터 적용: $tagFilter');

    if (tagFilter.isEmpty) return events;

    // 태그 필터 적용
    if (tagFilter.isNotEmpty) {
      final filtered = <Event>[];
      for (final event in events) {
        if (event.id == null) continue;
        final tags = await repo.getEventTags(event.id!);
        if (tags.any((t) => tagFilter.contains(t.id))) {
          filtered.add(event);
        }
      }
      return filtered; // tagColor 포함된 event 반환
    }
    return events;
  }

  Future<String?> _getAccessToken() =>
      ref.read(googleAccountProvider.notifier).getAccessToken();

  Future<void> _syncGoogleCalendar(int year, int month) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) return;

      final repo = ref.read(eventRepositoryProvider);
      final localEvents = await repo.getEventsByMonth(year, month);

      // 1. 구글에 아직 없는 로컬 일정 업로드 (오프라인/게스트 때 만든 일정 포함)
      //    반복 일정은 회차가 아니라 원본을 한 번만 업로드
      final pushedIds = <int>{};
      for (final event in localEvents) {
        if (event.id == null || event.googleEventId != null) continue;
        if (!pushedIds.add(event.id!)) continue;
        final source = event.isRecurring
            ? await repo.getEventById(event.id!)
            : event;
        if (source == null) continue;
        final googleEventId = await _calendarService.addEvent(
          accessToken,
          source,
        );
        if (googleEventId != null) {
          await repo.setGoogleEventId(event.id!, googleEventId);
        }
      }

      // 2. 구글 → 로컬
      final googleEvents = await _calendarService.getEvents(
        accessToken,
        year,
        month,
      );
      if (googleEvents == null) return; // 조회 실패 시 로컬 삭제 단계로 가지 않음

      // 앱에서 만든 반복 일정의 회차는 로컬에서 펼쳐 보여주므로 가져오지 않음
      final localRecurringIds = await repo.getRecurringGoogleEventIds();
      for (final event in googleEvents) {
        if (localRecurringIds.contains(event.googleRecurringEventId)) continue;
        await repo.upsertGoogleEvent(event);
      }

      // 3. 구글에서 삭제된 일정은 로컬에서도 삭제
      //    (이번 달에 시작하는 일정만 — 조회 범위 경계에 걸친 일정 오삭제 방지)
      final monthPrefix =
          '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
      final googleIds = googleEvents.map((e) => e.googleEventId).toSet();
      for (final event in localEvents) {
        if (event.id == null || event.googleEventId == null) continue;
        // 반복 일정은 한 달 조회 결과만으로 삭제 여부를 판단할 수 없음
        if (event.isRecurring) continue;
        final start = event.startDate ?? event.eventDate;
        if (!start.startsWith(monthPrefix)) continue;
        if (!googleIds.contains(event.googleEventId)) {
          await repo.deleteEvent(event.id!);
        }
      }
    } catch (e) {
      print('구글 캘린더 동기화 오류: $e');
    }
  }

  Future<int> addEvent(Event event) async {
    final repo = ref.read(eventRepositoryProvider);
    // Google Calendar에도 추가 (실패하면 다음 동기화 때 재시도)
    final accessToken = await _getAccessToken();
    String? googleEventId;
    if (accessToken != null) {
      googleEventId = await _calendarService.addEvent(accessToken, event);
    }

    final id = await repo.addEvent(
      googleEventId != null
          ? event.copyWith(googleEventId: googleEventId)
          : event,
    );
    ref.invalidateSelf();
    return id;
  }

  Future<void> updateEvent(Event event) async {
    final repo = ref.read(eventRepositoryProvider);
    await repo.updateEvent(event);

    // Google Calendar에도 반영
    final accessToken = await _getAccessToken();
    if (accessToken != null) {
      if (event.googleEventId != null) {
        await _calendarService.updateEvent(accessToken, event);
      } else if (event.id != null) {
        final googleEventId = await _calendarService.addEvent(
          accessToken,
          event,
        );
        if (googleEventId != null) {
          await repo.setGoogleEventId(event.id!, googleEventId);
        }
      }
    }
    ref.invalidateSelf();
  }

  Future<void> deleteEvent(int id) async {
    final repo = ref.read(eventRepositoryProvider);
    final event = await repo.getEventById(id);

    // Google Calendar에서도 삭제
    final googleEventId = event?.googleEventId;
    if (googleEventId != null) {
      final accessToken = await _getAccessToken();
      if (accessToken != null) {
        await _calendarService.deleteEvent(accessToken, googleEventId);
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
      '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

  return events.where((e) {
    if (e.startDate != null && e.endDate != null) {
      return dateStr.compareTo(e.startDate!) >= 0 &&
          dateStr.compareTo(e.endDate!) <= 0;
    }
    return e.eventDate == dateStr;
  }).toList();
});
