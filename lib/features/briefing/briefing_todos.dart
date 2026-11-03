import 'dart:convert';

import '../memo/editor_v2/todo_due.dart';

/// 메모 본문(appflowy 문서 JSON)에서 체크되지 않은 체크박스 항목의 위치·텍스트·마감일.
/// JSON이 아닌 예전(마크다운) 메모나 손상된 내용은 빈 목록.
List<({List<int> path, String text, DateTime? due})> uncheckedTodos(
  String noteContent,
) {
  if (noteContent.isEmpty) return const [];
  final List children;
  try {
    final document = (jsonDecode(noteContent) as Map)['document'] as Map;
    children = (document['children'] as List?) ?? const [];
  } catch (_) {
    return const [];
  }

  final result = <({List<int> path, String text, DateTime? due})>[];
  void visit(List nodes, List<int> parentPath) {
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node is! Map) continue;
      final path = [...parentPath, i];
      final data = (node['data'] as Map?) ?? const {};
      if (node['type'] == 'todo_list' && data['checked'] != true) {
        final text = _plainText(data['delta']).trim();
        final due = data[todoDueKey];
        if (text.isNotEmpty) {
          result.add((
            path: path,
            text: text,
            due: due is String ? DateTime.tryParse(due) : null,
          ));
        }
      }
      visit((node['children'] as List?) ?? const [], path);
    }
  }

  visit(children, const []);
  return result;
}

String _plainText(Object? delta) => delta is List
    ? delta
          .whereType<Map>()
          .map((op) => op['insert'])
          .whereType<String>()
          .join()
          .replaceAll('￼', '') // 줄 안의 그림 자리
    : '';
