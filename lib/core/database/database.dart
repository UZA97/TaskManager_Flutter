import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'database.g.dart';

class FolderTable extends Table {
  @override
  String get tableName => 'folders';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get parentId => integer().nullable().references(FolderTable, #id)();
  RealColumn get sortOrder => real().withDefault(const Constant(0.0))();
  TextColumn get createdAt => text()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  RealColumn get favoriteSortOrder => real().withDefault(const Constant(0.0))();
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
  RealColumn get sortOrder => real().withDefault(const Constant(0.0))();
  TextColumn get deletedAt => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isImportant => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  RealColumn get favoriteSortOrder => real().withDefault(const Constant(0.0))();
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

  TextColumn get locationName => text().nullable()();
  RealColumn get locationLat => real().nullable()();
  RealColumn get locationLng => real().nullable()();
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
  int get schemaVersion => 7;

  /// 신규 설치와 기존 데이터베이스 업그레이드 모두에서 공통으로 쓰이는
  /// 기본 폴더를 생성하고, 폴더가 비어 있는 메모에 자동으로 연결합니다.
  Future<int> _ensureDefaultFolder() async {
    final now = DateTime.now().toIso8601String();
    final defaultFolderId = await into(
      folderTable,
    ).insert(FolderTableCompanion.insert(name: '기본 폴더', createdAt: now));
    await (update(noteTable)..where((t) => t.folderId.isNull())).write(
      NoteTableCompanion(folderId: Value(defaultFolderId)),
    );
    return defaultFolderId;
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      // 새 데이터베이스 생성 시 모든 테이블을 만든 뒤 기본 폴더를 초기화합니다.
      await m.createAll();
      await _ensureDefaultFolder();
    },
    onUpgrade: (m, from, to) async {
      // 기존 데이터베이스에 구조 변경이 필요할 때 단계별로 마이그레이션합니다.
      if (from < 2) {
        await m.createTable(eventTable);
      }
      if (from < 3) {
        await m.createTable(folderTable);
        await m.addColumn(noteTable, noteTable.folderId as GeneratedColumn);
        await _ensureDefaultFolder();
      }
      if (from < 4) {
        await m.addColumn(
          eventTable,
          eventTable.locationName as GeneratedColumn,
        );
        await m.addColumn(
          eventTable,
          eventTable.locationLat as GeneratedColumn,
        );
        await m.addColumn(
          eventTable,
          eventTable.locationLng as GeneratedColumn,
        );
      }
      if (from < 5) {
        await m.addColumn(noteTable, noteTable.deletedAt as GeneratedColumn);
      }
      if (from < 6) {
        await m.addColumn(noteTable, noteTable.isPinned as GeneratedColumn);
        await m.addColumn(noteTable, noteTable.isImportant as GeneratedColumn);
        await m.addColumn(folderTable, folderTable.isPinned as GeneratedColumn);
      }
      if (from < 7) {
        await m.addColumn(noteTable, noteTable.isFavorite as GeneratedColumn);
        await m.addColumn(
          noteTable,
          noteTable.favoriteSortOrder as GeneratedColumn,
        );
        await m.addColumn(
          folderTable,
          folderTable.isFavorite as GeneratedColumn,
        );
        await m.addColumn(
          folderTable,
          folderTable.favoriteSortOrder as GeneratedColumn,
        );
      }
    },
  );
  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'taskmanager.sqlite'));
      return NativeDatabase(file);
    });
  }
}
