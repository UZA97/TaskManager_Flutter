import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

part 'database.g.dart';

class EventTagTable extends Table {
  @override
  String get tableName => 'event_tags';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get color => text().withDefault(const Constant('#4A90E2'))();
}

class EventTagRelationTable extends Table {
  @override
  String get tableName => 'event_tag_relations';

  IntColumn get eventId => integer().references(EventTable, #id)();
  IntColumn get tagId => integer().references(EventTagTable, #id)();

  @override
  Set<Column> get primaryKey => {eventId, tagId};
}

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

class MapTagTable extends Table {
  @override
  String get tableName => 'map_tags';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get color => text().withDefault(const Constant('#4A90E2'))();
}

class MapPlaceTable extends Table {
  @override
  String get tableName => 'map_places';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get address => text().withDefault(const Constant(''))();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  IntColumn get tagId => integer().references(MapTagTable, #id)();
  TextColumn get createdAt => text()();
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

  TextColumn get startDate => text().nullable()();
  TextColumn get endDate => text().nullable()();
  TextColumn get startTime => text().nullable()();
  TextColumn get endTime => text().nullable()();
  BoolColumn get isAllDay => boolean().withDefault(const Constant(true))();
  TextColumn get content => text().nullable()();

  // 반복: '' (없음) / daily / weekly / monthly / yearly
  TextColumn get recurrence => text().withDefault(const Constant(''))();
  // 반복 종료일 (yyyy-MM-dd, 포함). null이면 무기한
  TextColumn get recurrenceUntil => text().nullable()();
  // 반복 간격 (2면 격주·격월 등)
  IntColumn get recurrenceInterval => integer().withDefault(const Constant(1))();
  // 매주 반복의 요일 (DateTime.weekday, 쉼표로: "1,3,5"). 비면 시작일의 요일
  TextColumn get recurrenceDays => text().withDefault(const Constant(''))();
  // 반복에서 뺀 날짜 (yyyy-MM-dd, 쉼표로) — "이 일정만" 삭제·수정한 회차
  TextColumn get recurrenceExceptions =>
      text().withDefault(const Constant(''))();
  // 구글 캘린더 ID ('' = 기본 캘린더)
  TextColumn get calendarId => text().withDefault(const Constant(''))();

  // 로컬 변경이 아직 구글에 반영되지 않음 (동기화 때 먼저 푸시, 풀이 덮어쓰지 않음)
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
}

// 로컬에서 삭제했지만 구글 삭제가 아직 안 된 일정 (재수입 방지용 툼스톤)
class PendingEventDeleteTable extends Table {
  @override
  String get tableName => 'pending_event_deletes';

  TextColumn get googleEventId => text()();

  @override
  Set<Column> get primaryKey => {googleEventId};
}

// 할 일 탭의 할 일 (메모 체크리스트와 별개)
@DataClassName('TodoItem')
class TodoTable extends Table {
  @override
  String get tableName => 'todos';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  // 기한 (yyyy-MM-dd). null이면 기한 없음
  TextColumn get due => text().nullable()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  TextColumn get doneAt => text().nullable()();
  TextColumn get createdAt => text()();
  // 하위 할 일이면 상위 할 일의 id
  IntColumn get parentId => integer().nullable()();
  // 연결된 메모 id (메모에 추가했거나 직접 연결한 메모)
  IntColumn get noteId => integer().nullable()();
}

@DriftDatabase(
  tables: [
    TodoTable,
    NoteTable,
    TagTable,
    NoteTagTable,
    AttachmentTable,
    SettingTable,
    EventTable,
    FolderTable,
    EventTagTable,
    EventTagRelationTable,
    MapTagTable,
    MapPlaceTable,
    PendingEventDeleteTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// 테스트용 (메모리 DB 등)
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 15;

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
      if (from < 8) {
        await m.createTable(eventTagTable);
        await m.createTable(eventTagRelationTable);
        await m.addColumn(eventTable, eventTable.startDate as GeneratedColumn);
        await m.addColumn(eventTable, eventTable.endDate as GeneratedColumn);
        await m.addColumn(eventTable, eventTable.startTime as GeneratedColumn);
        await m.addColumn(eventTable, eventTable.endTime as GeneratedColumn);
        await m.addColumn(eventTable, eventTable.isAllDay as GeneratedColumn);
        await m.addColumn(eventTable, eventTable.content as GeneratedColumn);
      }
      if (from < 9) {
        await m.createTable(mapTagTable);
        await m.createTable(mapPlaceTable);
      }
      if (from < 10) {
        await _addColumnIfMissing(
          m,
          eventTable,
          eventTable.recurrence as GeneratedColumn,
        );
        await _addColumnIfMissing(
          m,
          eventTable,
          eventTable.recurrenceUntil as GeneratedColumn,
        );
      }
      if (from < 11) {
        await _addColumnIfMissing(
          m,
          eventTable,
          eventTable.dirty as GeneratedColumn,
        );
        // createTable은 IF NOT EXISTS라 재업그레이드에도 안전
        await m.createTable(pendingEventDeleteTable);
      }
      if (from < 12) {
        await m.createTable(todoTable);
      }
      // 이전 버전 앱으로 열었다가 돌아오면 칸이 이미 있을 수 있어 확인 후 추가
      if (from >= 12 && from < 14) {
        await _addColumnIfMissing(
          m,
          todoTable,
          todoTable.parentId as GeneratedColumn,
        );
        await _addColumnIfMissing(
          m,
          todoTable,
          todoTable.noteId as GeneratedColumn,
        );
      }
      if (from < 15) {
        for (final column in [
          eventTable.recurrenceInterval,
          eventTable.recurrenceDays,
          eventTable.recurrenceExceptions,
          eventTable.calendarId,
        ]) {
          await _addColumnIfMissing(m, eventTable, column);
        }
      }
    },
  );

  /// 이전 버전 앱으로 DB를 열면 user_version만 내려가고 컬럼은 남아 있어,
  /// 다시 업그레이드할 때 같은 컬럼을 추가하다 실패하지 않도록 확인 후 추가
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    final columns = await customSelect(
      'PRAGMA table_info("${table.actualTableName}")',
    ).get();
    if (columns.any((row) => row.read<String>('name') == column.name)) return;
    await m.addColumn(table, column);
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'taskmanager.sqlite'));
      // SQLite는 별도 isolate에서 실행 (긴 메모 저장 등으로 화면이 멈추지 않도록)
      return NativeDatabase.createInBackground(file);
    });
  }
}
