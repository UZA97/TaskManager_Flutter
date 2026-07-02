import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class FolderTable extends Table {
  @override
  String get tableName => 'folders';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get parentId => integer().nullable().references(FolderTable, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get createdAt => text()();
}

class NoteTable extends Table {
  @override
  String get tableName => 'notes';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  IntColumn get folderId => integer().nullable().references(FolderTable, #id)();
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
  TextColumn get googleEventId => text().withDefault(const Constant(''))();
}

@DriftDatabase(
  tables: [
    NoteTable,
    TagTable,
    NoteTagTable,
    AttachmentTable,
    SettingTable,
    EventTable,
    FolderTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3; // 2 → 3

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(eventTable);
      }
      if (from < 3) {
        await m.createTable(folderTable);
        await m.addColumn(noteTable, noteTable.folderId as GeneratedColumn);

        final now = DateTime.now().toIso8601String();
        final defaultFolderId = await into(
          folderTable,
        ).insert(FolderTableCompanion.insert(name: '기본 폴더', createdAt: now));
        await (update(noteTable)..where((t) => t.folderId.isNull())).write(
          NoteTableCompanion(folderId: Value(defaultFolderId)),
        );
      }
    },
  );
  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'taskmanager');
  }
}
