import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../models/event.dart';
import '../models/recurrence.dart';
import '../models/event_tag.dart';

class EventRepository {
  final AppDatabase _db;

  EventRepository(this._db);

  Future<List<Event>> getEventsByMonth(int year, int month) =>
      getEventsInRange(DateTime(year, month, 1), DateTime(year, month + 1, 0));

  /// [from]~[to] (날짜 기준, 양끝 포함)에 걸치는 일정.
  /// 반복 일정은 범위 안의 회차들로 펼쳐서 반환 (회차는 원본과 같은 id).
  Future<List<Event>> getEventsInRange(DateTime from, DateTime to) async {
    final fromStr = formatDate(from);
    final toStr = formatDate(to);

    final rows =
        await (_db.select(_db.eventTable)..where(
              (t) =>
                  (t.recurrence.equals('') &
                      (
                      // 시작일이 범위 안에 있거나
                      t.eventDate.isBetweenValues(fromStr, toStr) |
                          // 기간이 있는 경우 시작~종료가 범위에 걸치는 경우
                          (t.startDate.isSmallerOrEqualValue(toStr) &
                              t.endDate.isBiggerOrEqualValue(fromStr)))) |
                  // 반복 일정: 범위 끝 이전에 시작했고 종료일이 범위 시작 이후
                  (t.recurrence.equals('').not() &
                      t.eventDate.isSmallerOrEqualValue(toStr) &
                      (t.recurrenceUntil.isNull() |
                          t.recurrenceUntil.isBiggerOrEqualValue(fromStr))),
            ))
            .get();

    final events = <Event>[];
    for (final event in rows.map(_rowToEvent)) {
      if (event.isRecurring) {
        events.addAll(expandOccurrences(event, from, to));
      } else {
        events.add(event);
      }
    }
    events.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      return byPriority != 0 ? byPriority : a.eventDate.compareTo(b.eventDate);
    });

    // 태그 색상은 일정(id)당 한 번만 조회
    final tagColors = <int, String?>{};
    for (final id in events.map((e) => e.id).whereType<int>().toSet()) {
      final tags = await getEventTags(id);
      tagColors[id] = tags.isEmpty ? null : tags.first.color;
    }
    return events
        .map(
          (e) => tagColors[e.id] == null
              ? e
              : e.copyWith(tagColor: tagColors[e.id]),
        )
        .toList();
  }

  // 알림이 켜져 있고 시작일이 fromDate(yyyy-MM-dd) 이후인 일정 + 반복 일정(원본)
  Future<List<Event>> getUpcomingAlarmEvents(String fromDate) async {
    final rows =
        await (_db.select(_db.eventTable)..where(
              (t) =>
                  t.alarmEnabled.equals(true) &
                  (t.eventDate.isBiggerOrEqualValue(fromDate) |
                      (t.recurrence.equals('').not() &
                          (t.recurrenceUntil.isNull() |
                              t.recurrenceUntil.isBiggerOrEqualValue(
                                fromDate,
                              )))),
            ))
            .get();
    return rows.map(_rowToEvent).toList();
  }

  Future<int> addEvent(Event event) async {
    return await _db
        .into(_db.eventTable)
        .insert(
          EventTableCompanion.insert(
            id: Value.absentIfNull(event.id),
            title: Value(event.title),
            eventDate: event.eventDate,
            createdAt: event.createdAt,
            alarmEnabled: Value(event.alarmEnabled),
            alarmTime: Value(event.alarmTime),
            alarmDaysBefore: Value(event.alarmDaysBefore),
            isCompleted: Value(event.isCompleted),
            priority: Value(event.priority),
            googleEventId: Value(event.googleEventId ?? ''),
            locationName: Value(event.locationName),
            locationLat: Value(event.locationLat),
            locationLng: Value(event.locationLng),
            startDate: Value(event.startDate),
            endDate: Value(event.endDate),
            startTime: Value(event.startTime),
            endTime: Value(event.endTime),
            isAllDay: Value(event.isAllDay),
            content: Value(event.content),
            recurrence: Value(event.recurrence),
            recurrenceUntil: Value(event.recurrenceUntil),
          ),
        );
  }

  Future<Event?> getEventById(int id) async {
    final row = await (_db.select(
      _db.eventTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _rowToEvent(row);
  }

  Future<void> upsertGoogleEvent(Event event) async {
    final googleEventId = event.googleEventId;
    if (googleEventId == null || googleEventId.isEmpty) return;

    // googleEventId로 기존 이벤트 확인 (중복 행이 있으면 첫 행만 남김)
    final rows = await (_db.select(
      _db.eventTable,
    )..where((t) => t.googleEventId.equals(googleEventId))).get();

    if (rows.isEmpty) {
      await addEvent(event);
      return;
    }

    for (final dup in rows.skip(1)) {
      await deleteEvent(dup.id);
    }

    // 구글에서 관리되는 필드만 갱신 (알람/우선순위/완료/태그/좌표는 로컬 값 유지)
    await (_db.update(
      _db.eventTable,
    )..where((t) => t.id.equals(rows.first.id))).write(
      EventTableCompanion(
        title: Value(event.title),
        eventDate: Value(event.eventDate),
        startDate: Value(event.startDate),
        endDate: Value(event.endDate),
        startTime: Value(event.startTime),
        endTime: Value(event.endTime),
        isAllDay: Value(event.isAllDay),
        content: Value(event.content),
        locationName: Value(event.locationName),
      ),
    );
  }

  // 앱에서 만든 반복 일정(원본)의 구글 ID — 구글이 돌려주는 회차 사본 중복 방지용
  Future<Set<String>> getRecurringGoogleEventIds() async {
    final rows =
        await (_db.select(_db.eventTable)..where(
              (t) =>
                  t.recurrence.equals('').not() &
                  t.googleEventId.equals('').not(),
            ))
            .get();
    return rows.map((r) => r.googleEventId).toSet();
  }

  Future<void> setGoogleEventId(int id, String googleEventId) async {
    await (_db.update(_db.eventTable)..where((t) => t.id.equals(id))).write(
      EventTableCompanion(googleEventId: Value(googleEventId)),
    );
  }

  Future<void> deleteEvent(int id) async {
    await (_db.delete(_db.eventTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> updateCompletion(int id, bool isCompleted) async {
    await (_db.update(_db.eventTable)..where((t) => t.id.equals(id))).write(
      EventTableCompanion(isCompleted: Value(isCompleted)),
    );
  }

  Future<void> updateEvent(Event event) async {
    await (_db.update(
      _db.eventTable,
    )..where((t) => t.id.equals(event.id!))).write(
      EventTableCompanion(
        id: Value.absentIfNull(event.id),
        title: Value(event.title),
        eventDate: Value(event.eventDate),
        alarmEnabled: Value(event.alarmEnabled),
        alarmTime: Value(event.alarmTime),
        alarmDaysBefore: Value(event.alarmDaysBefore),
        isCompleted: Value(event.isCompleted),
        priority: Value(event.priority),
        googleEventId: Value(event.googleEventId ?? ''),
        isAllDay: Value(event.isAllDay),
        startDate: Value(event.startDate),
        endDate: Value(event.endDate),
        startTime: Value(event.startTime),
        endTime: Value(event.endTime),
        content: Value(event.content),
        locationName: Value(event.locationName),
        locationLat: Value(event.locationLat),
        locationLng: Value(event.locationLng),
        recurrence: Value(event.recurrence),
        recurrenceUntil: Value(event.recurrenceUntil),
      ),
    );
  }

  // 태그 전체 조회
  Future<List<EventTag>> getAllTags() async {
    final rows = await _db.select(_db.eventTagTable).get();
    return rows
        .map((r) => EventTag(id: r.id, name: r.name, color: r.color))
        .toList();
  }

  // 태그 생성
  Future<EventTag> createTag(String name, String color) async {
    final id = await _db
        .into(_db.eventTagTable)
        .insert(EventTagTableCompanion.insert(name: name, color: Value(color)));
    return EventTag(id: id, name: name, color: color);
  }

  // 태그 삭제
  Future<void> deleteTag(int id) async {
    await (_db.delete(_db.eventTagTable)..where((t) => t.id.equals(id))).go();
    await (_db.delete(
      _db.eventTagRelationTable,
    )..where((t) => t.tagId.equals(id))).go();
  }

  // 이벤트에 태그 설정
  Future<void> setEventTags(int eventId, List<int> tagIds) async {
    await (_db.delete(
      _db.eventTagRelationTable,
    )..where((t) => t.eventId.equals(eventId))).go();
    for (final tagId in tagIds) {
      await _db
          .into(_db.eventTagRelationTable)
          .insert(
            EventTagRelationTableCompanion.insert(
              eventId: eventId,
              tagId: tagId,
            ),
          );
    }
  }

  // 이벤트의 태그 조회
  Future<List<EventTag>> getEventTags(int eventId) async {
    final query = _db.select(_db.eventTagRelationTable).join([
      innerJoin(
        _db.eventTagTable,
        _db.eventTagTable.id.equalsExp(_db.eventTagRelationTable.tagId),
      ),
    ])..where(_db.eventTagRelationTable.eventId.equals(eventId));
    final rows = await query.get();
    return rows.map((r) {
      final tag = r.readTable(_db.eventTagTable);
      return EventTag(id: tag.id, name: tag.name, color: tag.color);
    }).toList();
  }

  Event _rowToEvent(EventTableData row) {
    return Event(
      id: row.id,
      title: row.title,
      eventDate: row.eventDate,
      createdAt: row.createdAt,
      alarmEnabled: row.alarmEnabled,
      alarmTime: row.alarmTime,
      alarmDaysBefore: row.alarmDaysBefore,
      isCompleted: row.isCompleted,
      priority: row.priority,
      googleEventId: row.googleEventId.isEmpty ? null : row.googleEventId,
      locationName: row.locationName,
      locationLat: row.locationLat,
      locationLng: row.locationLng,
      startDate: row.startDate,
      endDate: row.endDate,
      startTime: row.startTime,
      endTime: row.endTime,
      isAllDay: row.isAllDay,
      content: row.content,
      recurrence: row.recurrence,
      recurrenceUntil: row.recurrenceUntil,
    );
  }
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return EventRepository(db);
});
