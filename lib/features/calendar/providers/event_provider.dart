import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/event_repository.dart';
import '../models/event.dart';
import '../models/event_tag.dart';
import '../models/recurrence.dart';
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

/// 큰 캘린더 화면의 보기
enum CalendarViewMode {
  month('월'),
  week('주'),
  day('일');

  const CalendarViewMode(this.label);
  final String label;
}

class CalendarViewModeNotifier extends Notifier<CalendarViewMode> {
  @override
  CalendarViewMode build() => CalendarViewMode.month;

  void set(CalendarViewMode mode) => state = mode;
}

final calendarViewModeProvider =
    NotifierProvider<CalendarViewModeNotifier, CalendarViewMode>(
      CalendarViewModeNotifier.new,
    );

// 현재 월
class CurrentMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void prevMonth() => state = DateTime(state.year, state.month - 1);
  void nextMonth() => state = DateTime(state.year, state.month + 1);
  void setYear(int year) => state = DateTime(year, state.month);
  void setMonth(int month) => state = DateTime(state.year, month);

  /// [date]가 든 달로 (주·일 보기에서 날짜를 옮길 때)
  void showDate(DateTime date) {
    if (date.year != state.year || date.month != state.month) {
      state = DateTime(date.year, date.month);
    }
  }
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

/// 달력 그리드에 보이는 범위: 그 달 1일이 든 주의 일요일 ~ 말일이 든 주의 토요일.
/// 주 보기는 이 안에 항상 들어감 (선택한 날짜의 달을 보여 주므로).
({DateTime from, DateTime to}) monthGridRange(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final last = DateTime(month.year, month.month + 1, 0);
  return (
    from: DateTime(first.year, first.month, first.day - first.weekday % 7),
    to: DateTime(last.year, last.month, last.day + 6 - last.weekday % 7),
  );
}

/// [date]가 든 주의 일요일
DateTime weekStartOf(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday % 7);

// ───────────── 구글 캘린더 목록

const _calendarsKey = 'google_calendars';
const _hiddenCalendarsKey = 'google_calendars_hidden';

/// 구글 계정의 캘린더 목록과 숨긴 캘린더
class GoogleCalendarsState {
  const GoogleCalendarsState({
    this.calendars = const [],
    this.hidden = const {},
  });

  final List<GoogleCalendarInfo> calendars;

  /// 화면에 안 보이게 한 캘린더 ID
  final Set<String> hidden;

  GoogleCalendarInfo? byId(String id) {
    for (final c in calendars) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 일정을 고칠 수 있는 캘린더인지 (모르는 캘린더는 고칠 수 있다고 봄)
  bool isWritable(String id) => byId(id)?.writable ?? true;

  List<GoogleCalendarInfo> get visible => [
    for (final c in calendars)
      if (!hidden.contains(c.id)) c,
  ];
}

class GoogleCalendarsNotifier extends AsyncNotifier<GoogleCalendarsState> {
  @override
  Future<GoogleCalendarsState> build() async {
    final repo = ref.watch(eventRepositoryProvider);
    final raw = await repo.getSetting(_calendarsKey);
    final hidden = await repo.getSetting(_hiddenCalendarsKey);
    return GoogleCalendarsState(
      calendars: raw == null
          ? const []
          : [
              for (final c in jsonDecode(raw) as List<dynamic>)
                GoogleCalendarInfo.fromJson(c as Map<String, dynamic>),
            ],
      hidden: {
        for (final id in (hidden ?? '').split('\n'))
          if (id.isNotEmpty) id,
      },
    );
  }

  /// 구글에서 받은 목록으로 갱신. 처음 보는 캘린더 중 구글에서 꺼 둔 것은 숨김.
  Future<GoogleCalendarsState> replace(
    List<GoogleCalendarInfo> calendars,
  ) async {
    final repo = ref.read(eventRepositoryProvider);
    final old = await future;
    final known = {for (final c in old.calendars) c.id};
    final hidden = {
      ...old.hidden,
      for (final c in calendars)
        if (!known.contains(c.id) && !c.selected) c.id,
    };
    await repo.setSetting(
      _calendarsKey,
      jsonEncode([for (final c in calendars) c.toJson()]),
    );
    await repo.setSetting(_hiddenCalendarsKey, hidden.join('\n'));
    final next = GoogleCalendarsState(calendars: calendars, hidden: hidden);
    state = AsyncData(next);
    return next;
  }

  Future<void> toggle(String id) async {
    final current = await future;
    final hidden = {...current.hidden};
    if (!hidden.remove(id)) hidden.add(id);
    await ref
        .read(eventRepositoryProvider)
        .setSetting(_hiddenCalendarsKey, hidden.join('\n'));
    state = AsyncData(
      GoogleCalendarsState(calendars: current.calendars, hidden: hidden),
    );
  }
}

final googleCalendarsProvider =
    AsyncNotifierProvider<GoogleCalendarsNotifier, GoogleCalendarsState>(
      GoogleCalendarsNotifier.new,
    );

// 이벤트 목록 (현재 달의 그리드 범위)
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
    final calendars =
        ref.watch(googleCalendarsProvider).valueOrNull ??
        const GoogleCalendarsState();
    final email = ref.watch(
      googleAccountProvider.select((a) => a.valueOrNull?.email),
    );

    // 앱 시작 / 월 변경 / 로그인 시에만 자동 동기화
    final key = '${month.year}-${month.month}|$email';
    if (email != null && key != _autoSyncKey) {
      _autoSyncKey = key;
      Future.microtask(syncNow);
    }

    final range = monthGridRange(month);
    var events = [
      for (final e in await repo.getEventsInRange(range.from, range.to))
        if (!calendars.hidden.contains(e.calendarId))
          // 태그가 없는 다른 캘린더 일정은 그 캘린더 색으로
          e.tagColor == null && e.calendarId.isNotEmpty
              ? e.copyWith(tagColor: calendars.byId(e.calendarId)?.color)
              : e,
    ];
    if (tagFilter.isEmpty) return events;

    // 태그 필터 적용 (태그는 한 번의 쿼리로)
    final tagsById = await repo.getTagsForEvents(
      events.map((e) => e.id).whereType<int>(),
    );
    events = events.where((event) {
      final tags = tagsById[event.id] ?? const <EventTag>[];
      return tags.any((t) => tagFilter.contains(t.id));
    }).toList();
    return events;
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
        final range = monthGridRange(ref.read(currentMonthProvider));
        await _serialized(() => _syncGoogleCalendar(range.from, range.to));
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
    final calendars = await ref.read(googleCalendarsProvider.future);

    for (final key in await repo.getPendingDeletes()) {
      final (calendarId, googleEventId) = EventRepository.parsePendingDeleteKey(
        key,
      );
      if (await _calendarService.deleteEvent(
        accessToken,
        googleEventId,
        calendarId: calendarId,
      )) {
        await repo.removePendingDelete(key);
      }
    }

    // 반복 일정도 회차가 아니라 원본 행 단위로 푸시
    for (final row in await repo.getRowsNeedingPush()) {
      final event = repo.rowToEvent(row);
      // 공휴일 등 읽기 전용 캘린더는 올리지 않음
      if (!calendars.isWritable(event.calendarId)) continue;
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

  Future<void> _syncGoogleCalendar(DateTime from, DateTime to) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) return;

      final repo = ref.read(eventRepositoryProvider);

      // 0. 캘린더 목록 (실패하면 전에 받은 목록, 그것도 없으면 기본 캘린더만)
      final fetched = await _calendarService.getCalendars(accessToken);
      final calendars = fetched != null
          ? await ref.read(googleCalendarsProvider.notifier).replace(fetched)
          : await ref.read(googleCalendarsProvider.future);
      final targets = calendars.calendars.isEmpty
          ? const ['']
          : [for (final c in calendars.visible) c.id];

      // 1. 로컬 변경(삭제 대기/수정/신규)을 먼저 구글에 반영
      await _pushPending(accessToken);

      // 앱에서 만든 반복 일정의 회차는 로컬에서 펼쳐 보여주므로 가져오지 않음
      final localRecurringIds = await repo.getRecurringGoogleEventIds();
      final fromStr = formatDate(from);
      final toStr = formatDate(to);

      for (final calendarId in targets) {
        // 2. 구글 → 로컬 (dirty 행과 삭제 대기 ID는 repo에서 건너뜀)
        final googleEvents = await _calendarService.getEvents(
          accessToken,
          from,
          to,
          calendarId: calendarId,
        );
        if (googleEvents == null) continue; // 조회 실패 시 이 캘린더는 삭제 단계로 가지 않음

        for (final event in googleEvents) {
          if (localRecurringIds.contains(event.googleRecurringEventId)) {
            continue;
          }
          await repo.upsertGoogleEvent(event);
        }

        // 3. 구글에서 삭제된 일정은 로컬에서도 삭제
        //    (범위 안에서 시작하는 일정만 — 조회 범위 경계에 걸친 일정 오삭제 방지)
        final dirtyIds = await repo.getDirtyIds();
        final googleIds = googleEvents.map((e) => e.googleEventId).toSet();
        for (final event in await repo.getEventsInRange(from, to)) {
          if (event.calendarId != calendarId) continue;
          if (event.id == null || event.googleEventId == null) continue;
          // 반복 일정은 범위 조회 결과만으로 삭제 여부를 판단할 수 없음
          if (event.isRecurring) continue;
          // 아직 푸시 못 한 로컬 수정은 지우지 않음
          if (dirtyIds.contains(event.id)) continue;
          final start = event.start;
          if (start.compareTo(fromStr) < 0 || start.compareTo(toStr) > 0) {
            continue;
          }
          if (!googleIds.contains(event.googleEventId)) {
            await repo.deleteEvent(event.id!);
          }
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
      await repo.addPendingDelete(
        EventRepository.pendingDeleteKey(event!.calendarId, googleEventId),
      );
    }
    await repo.deleteEvent(id);
    ref.invalidateSelf();
    if (googleEventId != null) _pushInBackground();
  }

  /// 반복 일정에서 [occurrence] 회차만 삭제
  Future<void> deleteOccurrence(Event occurrence) async {
    await ref
        .read(eventRepositoryProvider)
        .addRecurrenceException(occurrence.id!, occurrence.start);
    ref.invalidateSelf();
    _pushInBackground();
  }

  /// 반복 일정에서 [occurrence] 회차만 [edited]로 바꿈:
  /// 그 회차를 반복에서 빼고, 반복 없는 일정으로 따로 만듦. 새 일정 id 반환.
  Future<int> detachOccurrence(Event occurrence, Event edited) async {
    final repo = ref.read(eventRepositoryProvider);
    await repo.addRecurrenceException(occurrence.id!, occurrence.start);
    final tags = await repo.getEventTags(occurrence.id!);
    final id = await repo.addEvent(
      Event(
        title: edited.title,
        eventDate: edited.start,
        startDate: edited.start,
        endDate: edited.end,
        startTime: edited.startTime,
        endTime: edited.endTime,
        isAllDay: edited.isAllDay,
        createdAt: DateTime.now().toIso8601String(),
        alarmEnabled: edited.alarmEnabled,
        alarmTime: edited.alarmTime,
        alarmDaysBefore: edited.alarmDaysBefore,
        priority: edited.priority,
        isCompleted: edited.isCompleted,
        content: edited.content,
        locationName: edited.locationName,
        locationLat: edited.locationLat,
        locationLng: edited.locationLng,
        calendarId: occurrence.calendarId,
      ),
      dirty: true,
    );
    await repo.setEventTags(id, [for (final t in tags) t.id!]);
    ref.invalidateSelf();
    _pushInBackground();
    return id;
  }

  /// 일정을 다른 날짜·시각으로 옮김 (끌어서 놓기). 기간·길이는 유지.
  /// 반복 일정 회차면 [wholeSeries]가 true일 때 전체를 같은 만큼 옮기고,
  /// 아니면 그 회차만 따로 떼어 옮김.
  Future<void> moveEvent(
    Event event,
    DateTime newStart, {
    String? startTime,
    bool wholeSeries = false,
  }) async {
    final start = DateTime.parse(event.start);
    final shift = DateTime(
      newStart.year,
      newStart.month,
      newStart.day,
    ).difference(DateTime(start.year, start.month, start.day)).inDays;
    var timeChange = (start: event.startTime, end: event.endTime);
    if (startTime != null && !event.isAllDay && event.startTime != null) {
      timeChange = (
        start: startTime,
        end: event.endTime == null
            ? null
            : _addMinutes(
                event.endTime!,
                _minutesOf(startTime) - _minutesOf(event.startTime!),
              ),
      );
    }
    String shifted(String date, int days) {
      final d = DateTime.parse(date);
      return formatDate(DateTime(d.year, d.month, d.day + days));
    }

    Event moved(Event e) {
      final s = shifted(e.start, shift);
      return e.copyWith(
        eventDate: s,
        startDate: s,
        endDate: shifted(e.end, shift),
        startTime: timeChange.start,
        endTime: timeChange.end,
        // 매주 반복의 요일도 같은 만큼 옮김
        recurrenceDays: [
          for (final d in e.recurrenceDays) (d - 1 + shift) % 7 + 1,
        ],
      );
    }

    if (!event.isRecurring) return updateEvent(moved(event));
    if (!wholeSeries) {
      await detachOccurrence(event, moved(event));
      return;
    }
    final master = await ref
        .read(eventRepositoryProvider)
        .getEventById(event.id!);
    if (master == null) return;
    await updateEvent(moved(master));
  }

  // 완료 여부는 로컬 전용 — 동기화 안 함
  Future<void> updateCompletion(int id, bool isCompleted) async {
    final repo = ref.read(eventRepositoryProvider);
    await repo.updateCompletion(id, isCompleted);
    ref.invalidateSelf();
  }
}

int _minutesOf(String time) {
  final parts = time.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// "HH:mm"에 분을 더함 (하루 안으로 자름)
String _addMinutes(String time, int minutes) {
  final total = (_minutesOf(time) + minutes).clamp(0, 23 * 60 + 59);
  return '${(total ~/ 60).toString().padLeft(2, '0')}:'
      '${(total % 60).toString().padLeft(2, '0')}';
}

final eventListProvider = AsyncNotifierProvider<EventListNotifier, List<Event>>(
  EventListNotifier.new,
);

/// [date]에 걸친 일정 (여러 날 일정 포함)
List<Event> eventsOn(Iterable<Event> events, DateTime date) {
  final dateStr = formatDate(date);
  return [
    for (final e in events)
      if (dateStr.compareTo(e.start) >= 0 && dateStr.compareTo(e.end) <= 0) e,
  ];
}

// 선택된 날짜의 이벤트만 필터
final selectedDateEventsProvider = Provider<List<Event>>((ref) {
  final events = ref.watch(eventListProvider).value ?? [];
  return eventsOn(events, ref.watch(selectedDateProvider));
});

/// 일정 검색 결과 (제목·내용·장소)
final eventSearchProvider = FutureProvider.family<List<Event>, String>((
  ref,
  query,
) async {
  ref.watch(eventListProvider); // 일정이 바뀌면 다시 검색
  return ref.watch(eventRepositoryProvider).searchEvents(query);
});
