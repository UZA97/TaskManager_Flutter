import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 메모의 예전 버전 하나
class NoteVersion {
  final DateTime time;
  final String title;
  final String content;
  final File file;

  const NoteVersion(this.time, this.title, this.content, this.file);
}

/// 메모 버전 기록: 앱 데이터 폴더의 NoteVersions/<메모 id>/<시각>.json
/// 메모를 열 때와, 편집 중에는 [interval]마다 한 번 저장. 메모마다 최근 [maxVersions]개만 보관.
class NoteVersionService {
  static const interval = Duration(minutes: 10);
  static const maxVersions = 50;

  static Future<Directory> _dir(int noteId) async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, 'NoteVersions', '$noteId'));
  }

  /// 버전 파일 목록 (파일 이름의 시각만, 최근 것부터. 내용은 읽지 않음)
  static Future<List<(int, File)>> _files(int noteId) async {
    final dir = await _dir(noteId);
    if (!await dir.exists()) return [];
    final files = <(int, File)>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final millis = int.tryParse(p.basenameWithoutExtension(entity.path));
      if (millis != null) files.add((millis, entity));
    }
    files.sort((a, b) => b.$1.compareTo(a.$1));
    return files;
  }

  static Future<NoteVersion?> _read(int millis, File file) async {
    try {
      final json = jsonDecode(await file.readAsString()) as Map;
      return NoteVersion(
        DateTime.fromMillisecondsSinceEpoch(millis),
        json['title'] as String? ?? '',
        json['content'] as String? ?? '',
        file,
      );
    } catch (_) {
      return null; // 깨진 파일은 건너뜀
    }
  }

  /// 최근 버전부터
  static Future<List<NoteVersion>> list(int noteId) async {
    final versions = <NoteVersion>[];
    for (final (millis, file) in await _files(noteId)) {
      final version = await _read(millis, file);
      if (version != null) versions.add(version);
    }
    return versions;
  }

  /// 지금 내용을 버전으로 남김. 마지막 버전과 같거나, [force]가 아니면서 마지막 버전이
  /// [interval]보다 최근이면 건너뜀.
  static Future<void> snapshot(
    int noteId,
    String title,
    String content, {
    bool force = false,
  }) async {
    if (content.isEmpty && title.isEmpty) return;
    // 자동 저장마다 불리므로 파일 이름으로 시각만 먼저 보고, 내용은 마지막 하나만 읽음
    final files = await _files(noteId);
    if (files.isNotEmpty) {
      final (millis, file) = files.first;
      final time = DateTime.fromMillisecondsSinceEpoch(millis);
      if (!force && DateTime.now().difference(time) < interval) return;
      final last = await _read(millis, file);
      if (last != null && last.content == content && last.title == title) {
        return;
      }
    }
    final dir = await _dir(noteId);
    await dir.create(recursive: true);
    final file = File(
      p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.json'),
    );
    await file.writeAsString(jsonEncode({'title': title, 'content': content}));
    // 오래된 버전 정리
    for (final (_, old) in files.skip(maxVersions - 1)) {
      await old.delete().catchError((_) => old);
    }
  }
}

/// 메모 본문(appflowy 문서 JSON)의 글자만 줄 단위로 (미리보기·글자 수)
List<String> noteContentLines(String content) {
  final lines = <String>[];
  Map? document;
  try {
    document = (jsonDecode(content) as Map)['document'] as Map?;
  } catch (_) {
    return content.split('\n'); // 예전 마크다운 메모
  }

  void visit(List? children, int depth) {
    for (final node in children?.whereType<Map>() ?? const <Map>[]) {
      final data = node['data'] as Map? ?? const {};
      final delta = data['delta'];
      final indent = '  ' * depth;
      if (delta is List) {
        final text = delta
            .whereType<Map>()
            .map((op) => op['insert'])
            .whereType<String>()
            .join()
            .replaceAll('￼', ''); // 줄 안의 그림 자리
        final prefix = switch (node['type']) {
          'todo_list' => data['checked'] == true ? '☑ ' : '☐ ',
          'bulleted_list' => '• ',
          'quote' => '│ ',
          _ => '',
        };
        lines.add('$indent$prefix$text');
      } else if (node['type'] == 'local_table') {
        for (final row in (data['rows'] as List?) ?? const []) {
          if (row is List) lines.add('$indent| ${row.join(' | ')} |');
        }
      } else if (node['type'] == 'local_code') {
        lines.addAll('${data['code'] ?? ''}'.split('\n'));
      } else if (node['type'] == 'divider') {
        lines.add('$indent───');
      }
      visit(node['children'] as List?, depth + 1);
    }
  }

  visit(document?['children'] as List?, 0);
  return lines;
}
