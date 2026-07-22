import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../models/event.dart';
import '../models/event_tag.dart';

class EventRepository {
  final AppDatabase _db;

  EventRepository(this._db);

  Future<List<Event>> getEventsByMonth(int year, int month) async {
    final yearStr = year.toString().padLeft(4, '0');
    final monthStr = month.toString().padLeft(2, '0');
    final monthStart = '$yearStr-$monthStr-01';
    final monthEnd = '$yearStr-$monthStr-31';

    final rows =
        await (_db.select(_db.eventTable)
              ..where(
                (t) =>
                    // 시작일이 이번달 안에 있거나
                    t.eventDate.isBetweenValues(monthStart, monthEnd) |
                    // 기간이 있는 경우 시작~종료가 이번달에 걸치는 경우
                    (t.startDate.isSmallerOrEqualValue(monthEnd) &
                        t.endDate.isBiggerOrEqualValue(monthStart)),
              )
              ..orderBy([
                (t) => OrderingTerm.desc(t.priority),
                (t) => OrderingTerm.asc(t.eventDate),
              ]))
            .get();
    return rows.map(_rowToEvent).toList();
  }

  Future<List<Event>> getAllAlarmEvents() async {
    final rows =
        await (_db.select(_db.eventTable)..where(
              (t) => t.alarmEnabled | t.alarmDaysBefore.isBiggerThanValue(0),
            ))
            .get();
    return rows.map(_rowToEvent).toList();
  }

  Future<void> addEvent(Event event) async {
    await _db
        .into(_db.eventTable)
        .insert(
          EventTableCompanion.insert(
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
          ),
        );
  }

  Future<void> upsertGoogleEvent(Event event) async {
    // googleEventId로 기존 이벤트 확인
    final existing =
        await (_db.select(_db.eventTable)
              ..where((t) => t.googleEventId.equals(event.googleEventId ?? '')))
            .getSingleOrNull();

    if (existing != null) {
      // 이미 있으면 업데이트
      await (_db.update(
        _db.eventTable,
      )..where((t) => t.id.equals(existing.id))).write(
        EventTableCompanion(
          title: Value(event.title),
          eventDate: Value(event.eventDate),
        ),
      );
    } else {
      // 없으면 새로 추가
      await addEvent(event);
    }
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
        title: Value(event.title),
        eventDate: Value(event.eventDate),
        alarmEnabled: Value(event.alarmEnabled),
        alarmTime: Value(event.alarmTime),
        isAllDay: Value(event.isAllDay),
        startDate: Value(event.startDate),
        endDate: Value(event.endDate),
        startTime: Value(event.startTime),
        endTime: Value(event.endTime),
        content: Value(event.content),
        locationName: Value(event.locationName),
        locationLat: Value(event.locationLat),
        locationLng: Value(event.locationLng),
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
    );
  }
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return EventRepository(db);
});
