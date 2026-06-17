import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class NoteTable extends Table {
  @override
  String get tableName => 'notes';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}

class TagTable extends Table {
  @override
  String get tableName => 'tags';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
}

class NoteTagTable extends Table {
  @override
  String get tableName => 'note_tags';

  IntColumn get noteId => integer().references(NoteTable, #id)();
  IntColumn get tagId => integer().references(TagTable, #id)();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}

class AttachmentTable extends Table {
  @override
  String get tableName => 'attachments';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get noteId => integer().references(NoteTable, #id)();
  TextColumn get fileName => text()();
  TextColumn get filePath => text()();
  TextColumn get createdAt => text()();
}

class SettingTable extends Table {
  @override
  String get tableName => 'settings';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class EventTable extends Table {
  @override
  String get tableName => 'events';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get eventDate => text()();
  TextColumn get createdAt => text()();
  BoolColumn get alarmEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get alarmTime => text().withDefault(const Constant('09:00'))();
  IntColumn get alarmDaysBefore => integer().withDefault(const Constant(0))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get priority => integer().withDefault(const Constant(1))();
}

@DriftDatabase(tables: [
  NoteTable,
  TagTable,
  NoteTagTable,
  AttachmentTable,
  SettingTable,
  EventTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(eventTable);
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'taskmanager');
  }
}
