import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmanager/core/theme/app_colors.dart';
import 'package:taskmanager/features/briefing/briefing_todos.dart';
import 'package:taskmanager/features/memo/models/note.dart';
import 'package:taskmanager/features/todo/todo_provider.dart';
import 'package:taskmanager/features/todo/todo_views.dart';

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

  // 라이트·다크 모드, 좁은 창에서도 오류 없이 그려지는지
  for (final dark in [false, true]) {
    for (final width in [900.0, 560.0]) {
      testWidgets('todo tab renders (${dark ? 'dark' : 'light'}, $width)', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const note = Note(
          id: 1,
          title: '아주 긴 메모 제목이 들어가서 칩이 넘치는지 확인하는 메모',
          content: '',
          createdAt: '',
          updatedAt: '',
        );
        final today = DateTime.now();
        final todos = [
          MemoTodo(note, '지난 일', const [0], today.subtract(const Duration(days: 2))),
          MemoTodo(note, '오늘 할 일 ' * 12, const [1], today),
          const MemoTodo(note, '기한 없는 일', [2], null),
        ];
        ColorScheme scheme(Brightness b) =>
            ColorScheme.fromSeed(seedColor: appSeedColor, brightness: b);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              allMemoTodosProvider.overrideWith((ref) async => todos),
            ],
            child: MaterialApp(
              theme: ThemeData(colorScheme: scheme(Brightness.light)),
              darkTheme: ThemeData(
                colorScheme: withDarkColors(scheme(Brightness.dark)),
              ),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              home: const Scaffold(
                body: Row(
                  children: [
                    SizedBox(width: 240, child: TodoSidebarView()),
                    Expanded(child: TodoView()),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('지난 일'), findsOneWidget);
        expect(find.text('기한 지남'), findsWidgets);
        expect(find.text('3개 남음'), findsOneWidget);
      });
    }
  }

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
