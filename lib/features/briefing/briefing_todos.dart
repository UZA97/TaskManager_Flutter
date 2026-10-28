import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';

/// 메모 본문(appflowy 문서 JSON)에서 체크되지 않은 체크박스 항목의 위치와 텍스트.
/// JSON이 아닌 예전(마크다운) 메모나 손상된 내용은 빈 목록.
List<({List<int> path, String text})> uncheckedTodos(String noteContent) {
  if (noteContent.isEmpty) return const [];
  final Document document;
  try {
    document = Document.fromJson(
      Map<String, Object>.from(jsonDecode(noteContent) as Map),
    );
  } catch (_) {
    return const [];
  }

  final result = <({List<int> path, String text})>[];
  void visit(Iterable<Node> nodes) {
    for (final node in nodes) {
      if (_isUncheckedTodo(node)) {
        final text = node.delta?.toPlainText().trim() ?? '';
        if (text.isNotEmpty) result.add((path: node.path, text: text));
      }
      visit(node.children);
    }
  }

  visit(document.root.children);
  return result;
}

/// 브리핑에서 고른 체크리스트 항목을 문서에서 찾음.
/// 저장 이후 편집으로 위치가 바뀌었을 수 있어, 위치가 맞지 않으면 같은 텍스트로 찾음.
Node? findUncheckedTodo(Document document, List<int> path, String text) {
  bool matches(Node node) =>
      _isUncheckedTodo(node) && node.delta?.toPlainText().trim() == text;

  final atPath = document.nodeAtPath(path);
  if (atPath != null && matches(atPath)) return atPath;

  Node? search(Iterable<Node> nodes) {
    for (final node in nodes) {
      if (matches(node)) return node;
      final found = search(node.children);
      if (found != null) return found;
    }
    return null;
  }

  return search(document.root.children);
}

bool _isUncheckedTodo(Node node) =>
    node.type == TodoListBlockKeys.type &&
    node.attributes[TodoListBlockKeys.checked] != true;
