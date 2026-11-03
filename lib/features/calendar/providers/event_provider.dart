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
// build()는 로컬 DB만 읽고, 구글 동기화는 syncNow()로 따로 (한 번에 하나만)
class EventListNotifier extends AsyncNotifier<List<Event>> {
  final _calendarService = GoogleCalendarService();

  // 마지막으로 자동 동기화를 건 "월|계정" — 같은 키로는 다시 안 함
  String? _autoSyncKey;
  Future<void>? _syncing;
  bool _resyncRequested = false;
  // 구글 푸시/동기화 직렬화 (중복 업로드 방지)
  Future<void> _googleLock = Future.value();

  @override
  Future<List<Event>> build() async {
    final month = ref.watch(currentMonthProvider);
    final repo = ref.watch(eventRepositoryProvider);
    final tagFilter = ref.watch(tagFilterProvider);
    final email = ref.watch(
      googleAccountProvider.select((a) => a.valueOrNull?.email),
    );

    // 앱 시작 / 월 변경 / 로그인 시에만 자동 동기화
    final key = '${month.year}-${month.month}|$email';
    if (email != null && key != _autoSyncKey) {
      _autoSyncKey = key;
      Future.microtask(syncNow);
    }

    final events = await repo.getEventsByMonth(month.year, month.month);
    if (tagFilter.isEmpty) return events;

    // 태그 필터 적용 (태그는 한 번의 쿼리로)
    final tagsById = await repo.getTagsForEvents(
      events.map((e) => e.id).whereType<int>(),
    );
    return events.where((event) {
      final tags = tagsById[event.id] ?? const <EventTag>[];
      return tags.any((t) => tagFilter.contains(t.id));
    }).toList();
  }

  Future<String?> _getAccessToken() =>
      ref.read(googleAccountProvider.notifier).getAccessToken();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _googleLock.then((_) => action());
    _googleLock = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// 구글 캘린더 동기화 (진행 중이면 끝난 뒤 한 번 더 — 월이 바뀌었을 수 있음)
  Future<void> syncNow() {
    _resyncRequested = true;
    return _syncing ??= _runSync();
  }

  Future<void> _runSync() async {
    try {
      while (_resyncRequested) {
        _resyncRequested = false;
        final month = ref.read(currentMonthProvider);
        await _serialized(() => _syncGoogleCalendar(month.year, month.month));
      }
    } finally {
      _syncing = null;
    }
    ref.invalidateSelf();
  }

  // 로컬 변경을 백그라운드로 구글에 반영
  void _pushInBackground() {
    _serialized(() async {
      final accessToken = await _getAccessToken();
      if (accessToken == null) return;
      await _pushPending(accessToken);
    }).then(
      (_) => ref.invalidateSelf(),
      onError: (e) => print('구글 캘린더 반영 실패 (다음 동기화 때 재시도): $e'),
    );
  }

  // 삭제 대기 → 수정/신규 순으로 푸시. 네트워크 오류는 그대로 던짐
  Future<void> _pushPending(String accessToken) async {
    final repo = ref.read(eventRepositoryProvider);

    for (final googleEventId in await repo.getPendingDeletes()) {
      if (await _calendarService.deleteEvent(accessToken, googleEventId)) {
        await repo.removePendingDelete(googleEventId);
      }
    }

    // 반복 일정도 회차가 아니라 원본 행 단위로 푸시
    for (final row in await repo.getRowsNeedingPush()) {
      final event = repo.rowToEvent(row);
      if (event.googleEventId == null) {
        final googleEventId = await _calendarService.addEvent(
          accessToken,
          event,
        );
        if (googleEventId != null) {
          await repo.markPushed(row, googleEventId: googleEventId);
        }
        continue;
      }
      final result = await _calendarService.updateEvent(accessToken, event);
      switch (result) {
        case GoogleUpdateResult.ok:
          await repo.markPushed(row);
        case GoogleUpdateResult.notFound:
          // 구글에서 지워졌지만 로컬에서 수정함 → 새로 만듦
          final googleEventId = await _calendarService.addEvent(
            accessToken,
            event,
          );
          if (googleEventId != null) {
            await repo.markPushed(row, googleEventId: googleEventId);
          }
        case GoogleUpdateResult.failed:
          break;
      }
    }
  }

  Future<void> _syncGoogleCalendar(int year, int month) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) return;

      final repo = ref.read(eventRepositoryProvider);

      // 1. 로컬 변경(삭제 대기/수정/신규)을 먼저 구글에 반영
      await _pushPending(accessToken);

      // 2. 구글 → 로컬 (dirty 행과 삭제 대기 ID는 repo에서 건너뜀)
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
      final localEvents = await repo.getEventsByMonth(year, month);
      final dirtyIds = await repo.getDirtyIds();
      final monthPrefix =
          '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
      final googleIds = googleEvents.map((e) => e.googleEventId).toSet();
      for (final event in localEvents) {
        if (event.id == null || event.googleEventId == null) continue;
        // 반복 일정은 한 달 조회 결과만으로 삭제 여부를 판단할 수 없음
        if (event.isRecurring) continue;
        // 아직 푸시 못 한 로컬 수정은 지우지 않음
        if (dirtyIds.contains(event.id)) continue;
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

  // 로컬에 먼저 저장(dirty)하고 구글 반영은 백그라운드 — 오프라인에서도 저장됨
  Future<int> addEvent(Event event) async {
    final repo = ref.read(eventRepositoryProvider);
    final id = await repo.addEvent(event, dirty: true);
    ref.invalidateSelf();
    _pushInBackground();
    return id;
  }

  Future<void> updateEvent(Event event) async {
    final repo = ref.read(eventRepositoryProvider);
    await repo.updateEvent(event, dirty: true);
    ref.invalidateSelf();
    _pushInBackground();
  }

  Future<void> deleteEvent(int id) async {
    final repo = ref.read(eventRepositoryProvider);
    final event = await repo.getEventById(id);

    // 구글 삭제는 툼스톤으로 남겨 두고 푸시 (실패해도 다음 동기화 때 재시도)
    final googleEventId = event?.googleEventId;
    if (googleEventId != null) {
      await repo.addPendingDelete(googleEventId);
    }
    await repo.deleteEvent(id);
    ref.invalidateSelf();
    if (googleEventId != null) _pushInBackground();
  }

  // 완료 여부는 로컬 전용 — 동기화 안 함
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
