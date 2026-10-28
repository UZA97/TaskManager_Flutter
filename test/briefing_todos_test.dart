import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmanager/features/briefing/briefing_todos.dart';

String _note(List<Node> nodes) {
  final document = Document.blank()..insert([0], nodes);
  return jsonEncode(document.toJson());
}

void main() {
  test('체크 안 된 항목만, 하위 항목 포함', () {
    final parent = todoListNode(checked: false, text: '장보기')
      ..insert(todoListNode(checked: false, text: '우유'))
      ..insert(todoListNode(checked: true, text: '빵'));
    final content = _note([
      paragraphNode(text: '메모'),
      todoListNode(checked: true, text: '끝난 일'),
      parent,
      todoListNode(checked: false, text: '  '), // 빈 항목 제외
    ]);

    final todos = uncheckedTodos(content);
    expect(todos.map((t) => t.text), ['장보기', '우유']);
    expect(todos.map((t) => t.path), [
      [2],
      [2, 0],
    ]);
  });

  test('위치로 찾고, 위치가 바뀌었으면 텍스트로 찾음', () {
    final document = Document.blank()
      ..insert([0], [
        paragraphNode(text: '새로 추가한 줄'),
        todoListNode(checked: true, text: '우유'),
        todoListNode(checked: false, text: '장보기')
          ..insert(todoListNode(checked: false, text: '우유')),
      ]);

    expect(findUncheckedTodo(document, [2], '장보기')?.path, [2]);
    // 저장 당시 [1]이었지만 앞에 줄이 생겨 [2]로 밀린 경우
    expect(findUncheckedTodo(document, [1], '장보기')?.path, [2]);
    // 체크된 '우유'는 건너뛰고 하위 항목을 찾음
    expect(findUncheckedTodo(document, [1], '우유')?.path, [2, 0]);
    expect(findUncheckedTodo(document, [0], '없는 항목'), isNull);
  });

  test('JSON이 아닌 예전 메모나 빈 내용은 빈 목록', () {
    expect(uncheckedTodos(''), isEmpty);
    expect(uncheckedTodos('# 마크다운 메모\n- [ ] 할 일'), isEmpty);
  });
}
