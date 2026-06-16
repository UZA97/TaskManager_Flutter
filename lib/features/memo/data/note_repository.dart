import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../models/note.dart';

class NoteRepository {
  final AppDatabase _db;

  NoteRepository(this._db);

  // 전체 메모 불러오기
  Future<List<Note>> getAllNotes() async {
    final rows = await _db.select(_db.notes).get();
    return Future.wait(rows.map((row) async {
      final tags = await getNoteTags(row.id);
      return Note(
        id: row.id,
        title: row.title,
        content: row.content,
        tags: tags,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
    }));
  }

  // 메모 검색
  Future<List<Note>> searchNotes(String keyword) async {
    final rows = await (_db.select(_db.notes)
          ..where((t) =>
              t.title.contains(keyword) | t.content.contains(keyword)))
        .get();
    return Future.wait(rows.map((row) async {
      final tags = await getNoteTags(row.id);
      return Note(
        id: row.id,
        title: row.title,
        content: row.content,
        tags: tags,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
    }));
  }

  // 메모 생성
  Future<Note> createNote() async {
    final now = DateTime.now().toIso8601String();
    final id = await _db.into(_db.notes).insert(
          NotesCompanion.insert(
            title: const Value(''),
            content: const Value(''),
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
    );
  }

  // 메모 저장
  Future<void> saveNote(Note note) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(note.id!)))
        .write(
      NotesCompanion(
        title: Value(note.title),
        content: Value(note.content),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  // 메모 삭제
  Future<void> deleteNote(int id) async {
    await (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go();
  }

  // 태그 불러오기
  Future<List<String>> getNoteTags(int noteId) async {
    final query = _db.select(_db.noteTags).join([
      innerJoin(_db.tags, _db.tags.id.equalsExp(_db.noteTags.tagId)),
    ])
      ..where(_db.noteTags.noteId.equals(noteId));
    final rows = await query.get();
    return rows.map((r) => r.readTable(_db.tags).name).toList();
  }

  // 태그 저장
  Future<void> saveNoteTags(int noteId, List<String> tags) async {
    await (_db.delete(_db.noteTags)
          ..where((t) => t.noteId.equals(noteId)))
        .go();

    for (final tag in tags) {
      await _db.into(_db.tags).insertOnConflictUpdate(
            TagsCompanion.insert(name: tag),
          );
      final tagRow =
          await (_db.select(_db.tags)..where((t) => t.name.equals(tag)))
              .getSingle();
      await _db.into(_db.noteTags).insertOnConflictUpdate(
            NoteTagsCompanion.insert(noteId: noteId, tagId: tagRow.id),
          );
    }
  }
}

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return NoteRepository(db);
});