import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 저장해 둔 메모 양식
class NoteTemplate {
  final String name;
  final String content;
  final File file;

  const NoteTemplate(this.name, this.content, this.file);
}

/// 메모 템플릿: 앱 데이터 폴더의 NoteTemplates/<만든 시각>.json
class NoteTemplateService {
  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    return Directory(p.join(base.path, 'NoteTemplates'));
  }

  /// 만든 순서대로
  static Future<List<NoteTemplate>> list() async {
    final dir = await _dir();
    if (!await dir.exists()) return [];
    final files =
        (await dir.list().toList())
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final templates = <NoteTemplate>[];
    for (final file in files) {
      try {
        final json = jsonDecode(await file.readAsString()) as Map;
        templates.add(
          NoteTemplate(
            json['name'] as String? ?? '템플릿',
            json['content'] as String? ?? '',
            file,
          ),
        );
      } catch (_) {
        // 깨진 파일은 건너뜀
      }
    }
    return templates;
  }

  static Future<void> save(String name, String content) async {
    final dir = await _dir();
    await dir.create(recursive: true);
    await File(
      p.join(dir.path, '${DateTime.now().millisecondsSinceEpoch}.json'),
    ).writeAsString(jsonEncode({'name': name, 'content': content}));
  }

  static Future<void> delete(NoteTemplate template) async {
    if (await template.file.exists()) await template.file.delete();
  }
}

/// 두 메모 본문(appflowy 문서 JSON)을 이어 붙임 (템플릿을 기존 내용 아래에 넣을 때)
String appendNoteContent(String content, String addition) {
  List children(String json) {
    try {
      final document = (jsonDecode(json) as Map)['document'] as Map;
      return (document['children'] as List?) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  return jsonEncode({
    'document': {
      'type': 'page',
      'children': [...children(content), ...children(addition)],
    },
  });
}
