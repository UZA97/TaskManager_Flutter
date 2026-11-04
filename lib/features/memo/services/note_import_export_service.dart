import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/folder_repository.dart';
import '../data/note_repository.dart';
import '../editor_v2/editor_block.dart';
import '../models/folder.dart';
import '../models/note.dart';
import 'enex_converter.dart';
import 'markdown_converter.dart';

/// 가져오기 결과
class ImportResult {
  int notes = 0;
  final failed = <String>[];
}

/// 메모 ↔ 마크다운 파일, Evernote(.enex) 가져오기
class NoteImportExportService {
  NoteImportExportService(this._notes, this._folders);

  final NoteRepository _notes;
  final FolderRepository _folders;

  // ───────────── 내보내기

  /// 메모 하나를 [mdPath]에 저장. 그림·첨부파일은 옆의 `<이름>_files` 폴더로 복사.
  Future<void> exportNote({
    required Note note,
    required List<EditorBlock> blocks,
    required String mdPath,
  }) async {
    final dir = p.dirname(mdPath);
    final filesDir = '${p.basenameWithoutExtension(mdPath)}_files';
    await File(
      mdPath,
    ).writeAsString(await _markdownOf(note, blocks, dir, filesDir));
  }

  /// 모든 메모를 [targetDir] 아래에 폴더 구조 그대로 내보냄. 내보낸 메모 수.
  Future<int> exportAll(String targetDir) async {
    final folders = await _folders.getAllFolders();
    final notes = await _notes.getAllNotes();
    final byId = {for (final f in folders) f.id: f};

    // 폴더 id → 내보낼 경로 (같은 이름의 폴더는 번호를 붙여 구분)
    final folderPaths = <int?, String>{null: targetDir};
    final usedNames = <String>{};
    String folderPath(Folder folder, [Set<int?> seen = const {}]) {
      final cached = folderPaths[folder.id];
      if (cached != null) return cached;
      final parent = byId[folder.parentId];
      final parentPath = parent == null || seen.contains(parent.id)
          ? targetDir
          : folderPath(parent, {...seen, folder.id});
      final path = _unique(
        p.join(parentPath, _safeName(folder.name, '폴더')),
        usedNames,
      );
      return folderPaths[folder.id] = path;
    }

    var count = 0;
    for (final note in notes) {
      final folder = byId[note.folderId];
      final dir = folder == null ? targetDir : folderPath(folder);
      await Directory(dir).create(recursive: true);
      final mdPath = _unique(
        p.join(dir, '${_safeName(note.title, '제목 없음')}.md'),
        usedNames,
        extension: '.md',
      );
      try {
        final blocks = note.content.isEmpty
            ? <EditorBlock>[]
            : blocksFromJson(note.content);
        await File(mdPath).writeAsString(
          await _markdownOf(
            note,
            blocks,
            dir,
            '_attachments/${p.basenameWithoutExtension(mdPath)}',
          ),
        );
        for (final b in blocks) {
          b.dispose();
        }
        count++;
      } catch (_) {
        // 깨진 메모 하나 때문에 전체를 멈추지 않음
      }
    }
    return count;
  }

  Future<String> _markdownOf(
    Note note,
    List<EditorBlock> blocks,
    String dir,
    String filesDir,
  ) async {
    // 그림·첨부파일 복사 (같은 파일은 한 번만)
    final copied = <String, String>{};
    for (final block in blocks) {
      if (!block.isText) continue;
      for (final mark in block.controller.marks) {
        final src = (mark['image'] ?? mark['file']) as String?;
        if (src == null || copied.containsKey(src)) continue;
        final file = File(src);
        if (!await file.exists()) continue;
        final destDir = Directory(p.join(dir, filesDir));
        await destDir.create(recursive: true);
        var name = p.basename(src);
        while (copied.values.contains('$filesDir/$name')) {
          name = '${p.basenameWithoutExtension(name)}_1${p.extension(name)}';
        }
        await file.copy(p.join(destDir.path, name));
        copied[src] = '$filesDir/$name';
      }
    }

    final tags = note.tags.isNotEmpty
        ? note.tags
        : (note.id == null ? <String>[] : await _notes.getNoteTags(note.id!));
    final frontMatter = [
      '---',
      'title: ${jsonEncode(note.title)}',
      if (tags.isNotEmpty) 'tags: [${tags.map(jsonEncode).join(', ')}]',
      'created: ${note.createdAt}',
      'updated: ${note.updatedAt}',
      '---',
      '',
    ].join('\n');
    return frontMatter +
        blocksToMarkdown(blocks, linkOf: (src) => copied[src] ?? src);
  }

  // ───────────── 가져오기

  /// 마크다운·텍스트·.enex 파일들을 가져옴.
  /// 마크다운은 "가져온 메모" 폴더에, .enex는 노트북(파일) 이름의 폴더에.
  Future<ImportResult> importFiles(List<String> paths) async {
    final result = ImportResult();
    int? markdownFolder;
    for (final path in paths) {
      try {
        if (p.extension(path).toLowerCase() == '.enex') {
          final folder = await _folders.createFolder(
            name: p.basenameWithoutExtension(path),
          );
          result.notes += await _importEnex(path, folder.id!);
        } else {
          markdownFolder ??= (await _folders.createFolder(name: '가져온 메모')).id;
          await _importMarkdown(path, markdownFolder);
          result.notes++;
        }
      } catch (_) {
        result.failed.add(p.basename(path));
      }
    }
    return result;
  }

  /// 폴더째 가져오기 (Obsidian 보관함, 이 앱에서 전체 내보낸 폴더 등).
  /// 하위 폴더도 그대로 만듦.
  Future<ImportResult> importDirectory(String dirPath) async {
    final result = ImportResult();

    Future<void> visit(Directory dir, int? parentId) async {
      final folder = await _folders.createFolder(
        name: p.basename(dir.path),
        parentId: parentId,
      );
      final entries = await dir.list().toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final entry in entries) {
        final name = p.basename(entry.path);
        if (name.startsWith('.') || name.startsWith('_')) continue;
        if (entry is Directory) {
          // 메모 하나 내보내기의 첨부 폴더, 그림만 있는 폴더는 건너뜀
          if (name.endsWith('_files') || !await _hasNoteFiles(entry)) continue;
          await visit(entry, folder.id);
        } else if (entry is File && _isMarkdown(entry.path)) {
          try {
            await _importMarkdown(entry.path, folder.id);
            result.notes++;
          } catch (_) {
            result.failed.add(name);
          }
        } else if (entry is File &&
            p.extension(entry.path).toLowerCase() == '.enex') {
          try {
            result.notes += await _importEnex(entry.path, folder.id!);
          } catch (_) {
            result.failed.add(name);
          }
        }
      }
    }

    await visit(Directory(dirPath), null);
    return result;
  }

  /// 폴더 안(하위 폴더 포함)에 가져올 메모 파일이 있는지
  static Future<bool> _hasNoteFiles(Directory dir) => dir
      .list(recursive: true)
      .any(
        (e) =>
            e is File &&
            (_isMarkdown(e.path) ||
                p.extension(e.path).toLowerCase() == '.enex'),
      );

  static bool _isMarkdown(String path) => const {
    '.md',
    '.markdown',
    '.txt',
  }.contains(p.extension(path).toLowerCase());

  Future<void> _importMarkdown(String path, int? folderId) async {
    final raw = await _readText(File(path));
    final (body, front) = splitFrontMatter(raw);
    final mdDir = p.dirname(path);

    final note = await _notes.createNote(
      folderId: folderId,
      createdAt: front.created?.toIso8601String(),
    );
    final attachDir = await _attachmentsDir(note.id!);
    final copied = <String, String>{};

    // 마크다운이 가리키는 로컬 파일을 이 메모의 첨부 폴더로 복사
    String? attachmentOf(String target) {
      if (RegExp(r'^[a-zA-Z][\w+.-]+:').hasMatch(target) &&
          !RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(target)) {
        return null; // http:, mailto: 등 (C:\ 같은 드라이브 경로는 제외)
      }
      final decoded = _decode(target.split('#').first);
      final source = p.isAbsolute(decoded) ? decoded : p.join(mdDir, decoded);
      final cached = copied[source];
      if (cached != null) return cached;
      final file = File(source);
      if (!file.existsSync()) return null;
      attachDir.createSync(recursive: true);
      var dest = p.join(attachDir.path, p.basename(source));
      if (File(dest).existsSync()) {
        dest = p.join(
          attachDir.path,
          '${p.basenameWithoutExtension(source)}_${copied.length}'
          '${p.extension(source)}',
        );
      }
      file.copySync(dest);
      return copied[source] = dest;
    }

    final blocks = markdownToBlocks(body, attachmentOf: attachmentOf);
    var title = front.title ?? p.basenameWithoutExtension(path);
    // 맨 위 # 제목이 메모 제목과 같으면 본문에서 뺌
    final first = blocks.first;
    if (first.type == 'heading' &&
        first.level == 1 &&
        (front.title == null || first.controller.text.trim() == title)) {
      title = first.controller.text.trim();
      if (blocks.length > 1) blocks.removeAt(0).dispose();
    }
    await _save(note, title, blocks, front.tags);
  }

  Future<int> _importEnex(String path, int folderId) async {
    final notes = parseEnex(await _readText(File(path)));
    for (final enex in notes) {
      final note = await _notes.createNote(
        folderId: folderId,
        createdAt: enex.created?.toIso8601String(),
      );
      final attachDir = await _attachmentsDir(note.id!);
      final mediaPath = <String, String>{};
      for (final (i, resource) in enex.resources.indexed) {
        await attachDir.create(recursive: true);
        final name = _safeName(
          resource.fileName ?? 'file_$i${_extensionOf(resource.mime)}',
          'file_$i',
        );
        var dest = p.join(attachDir.path, name);
        if (await File(dest).exists()) {
          dest = p.join(
            attachDir.path,
            '${p.basenameWithoutExtension(name)}_$i${p.extension(name)}',
          );
        }
        await File(dest).writeAsBytes(resource.bytes);
        mediaPath[resource.hash] = dest;
      }
      final markdown = enmlToMarkdown(enex.enml, mediaPath);
      final local = mediaPath.values.toSet();
      final blocks = markdownToBlocks(
        markdown,
        attachmentOf: (target) => local.contains(target) ? target : null,
      );
      await _save(note, enex.title, blocks, enex.tags);
    }
    return notes.length;
  }

  Future<void> _save(
    Note note,
    String title,
    List<EditorBlock> blocks,
    List<String> tags,
  ) async {
    await _notes.saveNote(
      note.copyWith(title: title, content: jsonEncode(blocksToJson(blocks))),
    );
    if (tags.isNotEmpty) await _notes.saveNoteTags(note.id!, tags);
    for (final b in blocks) {
      b.dispose();
    }
  }

  // ───────────── 도움 함수

  /// UTF-8로 읽고, 실패하면 (예전 윈도우 메모장 등) latin1로
  static Future<String> _readText(File file) async {
    final bytes = await file.readAsBytes();
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  /// %20 같은 인코딩 풀기 (잘못된 % 가 있으면 그대로)
  static String _decode(String target) {
    try {
      return Uri.decodeFull(target);
    } catch (_) {
      return target;
    }
  }

  static Future<Directory> _attachmentsDir(int noteId) async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, 'Attachments', '$noteId'));
  }

  /// 파일·폴더 이름에 못 쓰는 글자 제거
  static String _safeName(String name, String fallback) {
    final cleaned = name
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll(RegExp(r'[. ]+$'), '');
    if (cleaned.isEmpty) return fallback;
    return cleaned.length > 80 ? cleaned.substring(0, 80).trim() : cleaned;
  }

  /// 이미 쓴 경로면 " (2)" 등을 붙임
  static String _unique(
    String path,
    Set<String> used, {
    String extension = '',
  }) {
    final base = extension.isEmpty
        ? path
        : path.substring(0, path.length - extension.length);
    var candidate = path;
    for (var n = 2; used.contains(candidate.toLowerCase()); n++) {
      candidate = '$base ($n)$extension';
    }
    used.add(candidate.toLowerCase());
    return candidate;
  }

  static String _extensionOf(String mime) => switch (mime) {
    'image/png' => '.png',
    'image/jpeg' => '.jpg',
    'image/gif' => '.gif',
    'image/webp' => '.webp',
    'image/bmp' => '.bmp',
    'application/pdf' => '.pdf',
    'audio/mpeg' => '.mp3',
    'audio/wav' => '.wav',
    'video/mp4' => '.mp4',
    _ => '',
  };
}

final noteImportExportProvider = Provider<NoteImportExportService>(
  (ref) => NoteImportExportService(
    ref.watch(noteRepositoryProvider),
    ref.watch(folderRepositoryProvider),
  ),
);
