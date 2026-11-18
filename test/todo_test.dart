import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskmanager/features/briefing/briefing_todos.dart';
import 'package:taskmanager/features/todo/todo_provider.dart';

String _doc(List<Map<String, Object?>> children) => jsonEncode({
  'document': {'type': 'page', 'children': children},
});

Map<String, Object?> _todo(
  String text, {
  bool checked = false,
  String? due,
  List<Map<String, Object?>> children = const [],
}) => {
  'type': 'todo_list',
  'data': {
    'checked': checked,
    'due': ?due,
    'delta': [
      {'insert': text},
    ],
  },
  'children': children,
};

void main() {
  group('setTodoCheckedAt', () {
    final content = _doc([
      {
        'type': 'paragraph',
        'data': {
          'delta': [
            {'insert': '머리말'},
          ],
        },
      },
      _todo('부모', children: [_todo('자식')]),
    ]);

    test('checks a nested todo and keeps the rest', () {
      final updated = setTodoCheckedAt(content, [
        1,
        0,
      ], true, expectedText: '자식');
      expect(updated, isNotNull);
      final left = uncheckedTodos(updated!).map((t) => t.text).toList();
      expect(left, ['부모']);
      // 다시 해제하면 원래대로
      final restored = setTodoCheckedAt(updated, [1, 0], false);
      expect(uncheckedTodos(restored!).map((t) => t.text), ['부모', '자식']);
    });

    test('refuses when the text changed or the spot is not a todo', () {
      expect(setTodoCheckedAt(content, [1], true, expectedText: '다름'), isNull);
      expect(setTodoCheckedAt(content, [0], true), isNull); // 문단
      expect(setTodoCheckedAt(content, [5], true), isNull); // 없는 자리
      expect(setTodoCheckedAt('not json', [0], true), isNull);
    });
  });

  test('todoBucketOf groups by due date', () {
    final now = DateTime(2026, 11, 18, 15, 30);
    expect(todoBucketOf(null, now), TodoBucket.none);
    expect(todoBucketOf(DateTime(2026, 11, 17), now), TodoBucket.overdue);
    expect(todoBucketOf(DateTime(2026, 11, 18), now), TodoBucket.today);
    expect(todoBucketOf(DateTime(2026, 11, 19), now), TodoBucket.week);
    expect(todoBucketOf(DateTime(2026, 11, 24), now), TodoBucket.week);
    expect(todoBucketOf(DateTime(2026, 11, 25), now), TodoBucket.later);
  });

  test('uncheckedTodos reads due dates for the todo tab', () {
    final todos = uncheckedTodos(
      _doc([
        _todo('완료됨', checked: true),
        _todo('마감 있음', due: '2026-11-20'),
      ]),
    );
    expect(todos.single.text, '마감 있음');
    expect(todos.single.due, DateTime(2026, 11, 20));
  });
}
