import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../models/event.dart';

class EventRepository {
  final AppDatabase _db;

  EventRepository(this._db);

  Future<List<Event>> getEventsByMonth(int year, int month) async {
    final yearStr = year.toString().padLeft(4, '0');
    final monthStr = month.toString().padLeft(2, '0');
    final rows =
        await (_db.select(_db.eventTable)
              ..where((t) => t.eventDate.like('$yearStr-$monthStr-%'))
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
          ),
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
    );
  }
}

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return EventRepository(db);
});
