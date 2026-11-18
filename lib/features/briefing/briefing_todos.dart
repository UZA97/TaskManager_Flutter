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

/// 메모 본문에서 [path] 위치 체크박스의 체크 여부를 바꾼 새 본문.
/// 그 자리가 체크박스가 아니거나, [expectedText]와 글자가 다르면(그사이 메모가 바뀜) null.
String? setTodoCheckedAt(
  String noteContent,
  List<int> path,
  bool checked, {
  String? expectedText,
}) {
  if (path.isEmpty) return null;
  try {
    final root = jsonDecode(noteContent) as Map;
    var nodes = ((root['document'] as Map)['children'] as List?) ?? const [];
    Map? node;
    for (final i in path) {
      if (i < 0 || i >= nodes.length || nodes[i] is! Map) return null;
      node = nodes[i] as Map;
      nodes = (node['children'] as List?) ?? const [];
    }
    if (node == null || node['type'] != 'todo_list') return null;
    final data = (node['data'] ??= <String, Object?>{}) as Map;
    if (expectedText != null &&
        _plainText(data['delta']).trim() != expectedText) {
      return null;
    }
    data['checked'] = checked;
    return jsonEncode(root);
  } catch (_) {
    return null;
  }
}

String _plainText(Object? delta) => delta is List
    ? delta
          .whereType<Map>()
          .map((op) => op['insert'])
          .whereType<String>()
          .join()
          .replaceAll('￼', '') // 줄 안의 그림 자리
    : '';
