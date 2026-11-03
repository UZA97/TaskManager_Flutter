import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskmanager/features/briefing/briefing_todos.dart';

Map<String, Object?> _node(
  String type,
  String text, {
  bool? checked,
  String? due,
  List<Map<String, Object?>>? children,
}) => {
  'type': type,
  'data': {
    'delta': [
      {'insert': text},
    ],
    if (checked != null) 'checked': checked,
    if (due != null) 'due': due,
  },
  if (children != null) 'children': children,
};

String _note(List<Map<String, Object?>> nodes) => jsonEncode({
  'document': {'type': 'page', 'children': nodes},
});

void main() {
  test('체크 안 된 항목만, 하위 항목 포함', () {
    final content = _note([
      _node('paragraph', '메모'),
      _node('todo_list', '끝난 일', checked: true),
      _node(
        'todo_list',
        '장보기',
        checked: false,
        due: '2026-10-29',
        children: [
          _node('todo_list', '우유', checked: false),
          _node('todo_list', '빵', checked: true),
        ],
      ),
      _node('todo_list', '  ', checked: false), // 빈 항목 제외
    ]);

    final todos = uncheckedTodos(content);
    expect(todos.map((t) => t.text), ['장보기', '우유']);
    expect(todos.map((t) => t.path), [
      [2],
      [2, 0],
    ]);
    expect(todos.first.due, DateTime(2026, 10, 29));
    expect(todos.last.due, isNull);
  });

  test('JSON이 아닌 예전 메모나 빈 내용은 빈 목록', () {
    expect(uncheckedTodos(''), isEmpty);
    expect(uncheckedTodos('# 마크다운 메모\n- [ ] 할 일'), isEmpty);
  });
}
