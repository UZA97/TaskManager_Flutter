import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../data/attachment_repository.dart';
import 'note_provider.dart';

class AttachmentNotifier extends AsyncNotifier<List<Attachment>> {
  @override
  Future<List<Attachment>> build() async {
    final note = ref.watch(selectedNoteProvider);
    if (note == null) return [];
    final repo = ref.read(attachmentRepositoryProvider);
    return repo.getAttachments(note.id!);
  }

  Future<Directory> _getAttachDir(int noteId) async {
    final appDir = await getApplicationSupportDirectory();
    final attachDir = Directory('${appDir.path}\\Attachments\\$noteId');
    await attachDir.create(recursive: true);
    return attachDir;
  }

  Future<String> _copyFile(String srcPath, Directory destDir) async {
    final fileName = path.basename(srcPath);
    String destPath = '${destDir.path}\\$fileName';
    String finalName = fileName;

    // 동일 파일명 처리
    if (File(destPath).existsSync()) {
      final ext = path.extension(fileName);
      final name = path.basenameWithoutExtension(fileName);
      final now = DateTime.now().millisecondsSinceEpoch;
      finalName = '${name}_$now$ext';
      destPath = '${destDir.path}\\$finalName';
    }

    await File(srcPath).copy(destPath);
    return finalName;
  }

  Future<void> addAttachment() async {
    final note = ref.read(selectedNoteProvider);
    if (note == null) return;

    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;

    await _processFiles(
      note: note,
      filePaths: result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList(),
    );
  }

  Future<void> addAttachmentFromDrop(List<String> filePaths) async {
    final note = ref.read(selectedNoteProvider);
    if (note == null) return;
    await _processFiles(note: note, filePaths: filePaths);
  }

  Future<void> _processFiles({
    required dynamic note,
    required List<String> filePaths,
  }) async {
    final repo = ref.read(attachmentRepositoryProvider);
    final attachDir = await _getAttachDir(note.id!);

    for (final filePath in filePaths) {
      final finalName = await _copyFile(filePath, attachDir);
      final finalPath = '${attachDir.path}\\$finalName';
      await repo.addAttachment(
        noteId: note.id!,
        fileName: finalName,
        filePath: finalPath,
      );
    }

    ref.invalidateSelf();
  }

  Future<void> deleteAttachment(int id, String filePath) async {
    final repo = ref.read(attachmentRepositoryProvider);
    final file = File(filePath);
    if (file.existsSync()) await file.delete();
    await repo.deleteAttachment(id);
    ref.invalidateSelf();
  }

  Future<void> openAttachment(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return;
    await Process.run('explorer', [filePath]);
  }

  bool isImage(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext);
  }
}

final attachmentProvider =
    AsyncNotifierProvider<AttachmentNotifier, List<Attachment>>(
  AttachmentNotifier.new,
);
