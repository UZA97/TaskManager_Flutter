import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';
import '../models/note.dart';

class NoteRepository {
  final AppDatabase _db;

  NoteRepository(this._db);

  Future<List<Note>> getAllNotes() async {
    final rows = await _db.select(_db.noteTable).get();
    return Future.wait(
      rows.map((row) async {
        final tags = await getNoteTags(row.id);
        return Note(
          id: row.id,
          title: row.title,
          content: row.content,
          tags: tags,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        );
      }),
    );
  }

  Future<List<Note>> searchNotes(String keyword) async {
    final rows =
        await (_db.select(_db.noteTable)..where(
              (t) => t.title.contains(keyword) | t.content.contains(keyword),
            ))
            .get();
    return Future.wait(
      rows.map((row) async {
        final tags = await getNoteTags(row.id);
        return Note(
          id: row.id,
          title: row.title,
          content: row.content,
          tags: tags,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        );
      }),
    );
  }

  Future<Note> createNote() async {
    final now = DateTime.now().toIso8601String();
    final id = await _db
        .into(_db.noteTable)
        .insert(
          NoteTableCompanion.insert(
            title: const Value(''),
            content: const Value(''),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return Note(id: id, title: '', content: '', createdAt: now, updatedAt: now);
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

  Future<void> deleteNote(int id) async {
    await (_db.delete(_db.noteTable)..where((t) => t.id.equals(id))).go();
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
}

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return NoteRepository(db);
});
