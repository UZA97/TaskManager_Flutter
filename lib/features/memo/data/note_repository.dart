import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../models/note.dart';

class NoteRepository {
  final AppDatabase _db;

  NoteRepository(this._db);
  Note _rowToNote(NoteTableData row, List<String> tags) {
    return Note(
      id: row.id,
      title: row.title,
      content: row.content,
      tags: tags,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      folderId: row.folderId,
      sortOrder: row.sortOrder,
      deletedAt: row.deletedAt,
      isPinned: row.isPinned,
      isImportant: row.isImportant,
      isFavorite: row.isFavorite,
      favoriteSortOrder: row.favoriteSortOrder,
    );
  }

  Future<void> toggleFavorite(int id, bool isFavorite, double sortOrder) async {
    await (_db.update(_db.noteTable)..where((t) => t.id.equals(id))).write(
      NoteTableCompanion(
        isFavorite: Value(isFavorite),
        favoriteSortOrder: Value(sortOrder),
      ),
    );
  }

  Future<void> updateFavoriteSortOrder(int id, double sortOrder) async {
    await (_db.update(_db.noteTable)..where((t) => t.id.equals(id))).write(
      NoteTableCompanion(favoriteSortOrder: Value(sortOrder)),
    );
  }

  Future<void> togglePin(int id, bool isPinned) async {
    await (_db.update(_db.noteTable)..where((t) => t.id.equals(id))).write(
      NoteTableCompanion(isPinned: Value(isPinned)),
    );
  }

  Future<void> toggleImportant(int id, bool isImportant) async {
    await (_db.update(_db.noteTable)..where((t) => t.id.equals(id))).write(
      NoteTableCompanion(isImportant: Value(isImportant)),
    );
  }

  Future<List<Note>> getAllNotes() async {
    final rows = await (_db.select(
      _db.noteTable,
    )..where((t) => t.deletedAt.isNull())).get();
    return Future.wait(
      rows.map((row) async {
        final tags = await getNoteTags(row.id);
        return _rowToNote(row, tags);
      }),
    );
  }

  Future<List<Note>> searchNotes(String keyword) async {
    // 태그로 검색
    final tagQuery = _db.select(_db.noteTagTable).join([
      innerJoin(
        _db.tagTable,
        _db.tagTable.id.equalsExp(_db.noteTagTable.tagId),
      ),
    ])..where(_db.tagTable.name.contains(keyword));
    final tagRows = await tagQuery.get();
    final tagNoteIds = tagRows
        .map((r) => r.readTable(_db.noteTagTable).noteId)
        .toSet();

    // 제목/내용으로 검색
    final rows =
        await (_db.select(_db.noteTable)..where(
              (t) => t.title.contains(keyword) | t.content.contains(keyword),
            ))
            .get();

    // 합치기 (중복 제거)
    final allIds = {...rows.map((r) => r.id), ...tagNoteIds};

    // 전체 노트 중 해당 id만 필터
    final allRows =
        await (_db.select(_db.noteTable)
              ..where((t) => t.id.isIn(allIds))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
            .get();

    return Future.wait(
      allRows.map((row) async {
        final tags = await getNoteTags(row.id);
        return Note(
          id: row.id,
          title: row.title,
          content: row.content,
          tags: tags,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
          folderId: row.folderId, // 추가
          sortOrder: row.sortOrder, // 추가
        );
      }),
    );
  }

  Future<Note> createNote({int? folderId, double sortOrder = 0.0}) async {
    final now = DateTime.now().toIso8601String();
    final id = await _db
        .into(_db.noteTable)
        .insert(
          NoteTableCompanion.insert(
            title: const Value(''),
            content: const Value(''),
            folderId: Value(folderId),
            sortOrder: Value(sortOrder),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return Note(
      id: id,
      title: '',
      content: '',
      createdAt: now,
      updatedAt: now,
      folderId: folderId,
      sortOrder: sortOrder,
    );
  }

  Future<void> saveNote(Note note) async {
    await (_db.update(
      _db.noteTable,
    )..where((t) => t.id.equals(note.id!))).write(
      NoteTableCompanion(
        title: Value(note.title),
        content: Value(note.content),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  // 소프트 삭제
  Future<void> deleteNote(int id) async {
    await (_db.update(_db.noteTable)..where((t) => t.id.equals(id))).write(
      NoteTableCompanion(deletedAt: Value(DateTime.now().toIso8601String())),
    );
  }

  // 휴지통 목록 (페이지네이션)
  Future<List<Note>> getDeletedNotes({int page = 0, int pageSize = 20}) async {
    final rows =
        await (_db.select(_db.noteTable)
              ..where((t) => t.deletedAt.isNotNull())
              ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)])
              ..limit(pageSize, offset: page * pageSize))
            .get();
    return Future.wait(
      rows.map((row) async {
        final tags = await getNoteTags(row.id);
        return _rowToNote(row, tags);
      }),
    );
  }

  // 복원
  Future<void> restoreNote(int id) async {
    await (_db.update(_db.noteTable)..where((t) => t.id.equals(id))).write(
      NoteTableCompanion(deletedAt: const Value(null)),
    );
  }

  // 영구 삭제
  Future<void> permanentlyDeleteNote(int id) async {
    await (_db.delete(_db.noteTable)..where((t) => t.id.equals(id))).go();
  }

  // 전체 비우기
  Future<void> emptyTrash() async {
    await (_db.delete(
      _db.noteTable,
    )..where((t) => t.deletedAt.isNotNull())).go();
  }

  // 30일 만료 자동 삭제
  Future<void> deleteExpiredNotes() async {
    final expiry = DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String();
    await (_db.delete(_db.noteTable)..where(
          (t) =>
              t.deletedAt.isNotNull() & t.deletedAt.isSmallerThanValue(expiry),
        ))
        .go();
  }

  Future<List<String>> getNoteTags(int noteId) async {
    final query = _db.select(_db.noteTagTable).join([
      innerJoin(
        _db.tagTable,
        _db.tagTable.id.equalsExp(_db.noteTagTable.tagId),
      ),
    ])..where(_db.noteTagTable.noteId.equals(noteId));
    final rows = await query.get();
    return rows.map((r) => r.readTable(_db.tagTable).name).toList();
  }

  Future<void> saveNoteTags(int noteId, List<String> tags) async {
    await (_db.delete(
      _db.noteTagTable,
    )..where((t) => t.noteId.equals(noteId))).go();

    for (final tag in tags) {
      await _db
          .into(_db.tagTable)
          .insertOnConflictUpdate(TagTableCompanion.insert(name: tag));
      final tagRow = await (_db.select(
        _db.tagTable,
      )..where((t) => t.name.equals(tag))).getSingle();
      await _db
          .into(_db.noteTagTable)
          .insertOnConflictUpdate(
            NoteTagTableCompanion.insert(noteId: noteId, tagId: tagRow.id),
          );
    }
  }

  Future<void> deleteNotesByFolder(int folderId) async {
    await (_db.delete(
      _db.noteTable,
    )..where((t) => t.folderId.equals(folderId))).go();
  }

  Future<void> moveNote(int noteId, int? newFolderId) async {
    await (_db.update(_db.noteTable)..where((t) => t.id.equals(noteId))).write(
      NoteTableCompanion(folderId: Value(newFolderId)),
    ); // Value(null) 허용
  }

  Future<void> updateSortOrders(Map<int, double> sortOrders) async {
    for (final entry in sortOrders.entries) {
      await (_db.update(_db.folderTable)..where((t) => t.id.equals(entry.key)))
          .write(FolderTableCompanion(sortOrder: Value(entry.value)));
    }
  }

  Future<void> updateNoteSortOrder(int noteId, double sortOrder) async {
    await (_db.update(_db.noteTable)..where((t) => t.id.equals(noteId))).write(
      NoteTableCompanion(sortOrder: Value(sortOrder)),
    );
  }
}

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return NoteRepository(db);
});
