import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';

class Attachment {
  final int? id;
  final int noteId;
  final String fileName;
  final String filePath;
  final String createdAt;

  const Attachment({
    this.id,
    required this.noteId,
    required this.fileName,
    required this.filePath,
    required this.createdAt,
  });
}

class AttachmentRepository {
  final AppDatabase _db;

  AttachmentRepository(this._db);

  Future<List<Attachment>> getAttachments(int noteId) async {
    final rows =
        await (_db.select(_db.attachmentTable)
              ..where((t) => t.noteId.equals(noteId))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get();
    return rows
        .map(
          (row) => Attachment(
            id: row.id,
            noteId: row.noteId,
            fileName: row.fileName,
            filePath: row.filePath,
            createdAt: row.createdAt,
          ),
        )
        .toList();
  }

  Future<Attachment> addAttachment({
    required int noteId,
    required String fileName,
    required String filePath,
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = await _db
        .into(_db.attachmentTable)
        .insert(
          AttachmentTableCompanion.insert(
            noteId: noteId,
            fileName: fileName,
            filePath: filePath,
            createdAt: now,
          ),
        );
    return Attachment(
      id: id,
      noteId: noteId,
      fileName: fileName,
      filePath: filePath,
      createdAt: now,
    );
  }

  Future<void> deleteAttachment(int id) async {
    await (_db.delete(_db.attachmentTable)..where((t) => t.id.equals(id))).go();
  }
}

final attachmentRepositoryProvider = Provider<AttachmentRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AttachmentRepository(db);
});
