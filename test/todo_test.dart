import 'package:flutter/gestures.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmanager/core/database/database.dart';
import 'package:taskmanager/core/database/database_provider.dart';
import 'package:taskmanager/core/theme/app_colors.dart';
import 'package:taskmanager/features/todo/todo_provider.dart';
import 'package:taskmanager/features/todo/todo_views.dart';

TodoItem _item(int id, String title, {DateTime? due, bool done = false}) =>
    TodoItem(
      id: id,
      title: title,
      due: due == null ? null : formatTodoDue(due),
      done: done,
      doneAt: done ? DateTime.now().toIso8601String() : null,
      createdAt: '',
    );

class _FakeTodos extends TodoListNotifier {
  _FakeTodos(this.items);
  final List<TodoItem> items;

  @override
  Future<List<TodoItem>> build() async => items;
}

void main() {
  test('todoBucketOf groups by due date', () {
    final now = DateTime(2026, 11, 18, 15, 30);
    expect(todoBucketOf(null, now), TodoBucket.none);
    expect(todoBucketOf(DateTime(2026, 11, 17), now), TodoBucket.overdue);
    expect(todoBucketOf(DateTime(2026, 11, 18), now), TodoBucket.today);
    expect(todoBucketOf(DateTime(2026, 11, 19), now), TodoBucket.week);
    expect(todoBucketOf(DateTime(2026, 11, 24), now), TodoBucket.week);
    expect(todoBucketOf(DateTime(2026, 11, 25), now), TodoBucket.later);
  });

  test('dueLabel', () {
    final now = DateTime(2026, 11, 18, 9);
    expect(dueLabel(DateTime(2026, 11, 18), now), '오늘');
    expect(dueLabel(DateTime(2026, 11, 19), now), '내일');
    expect(dueLabel(DateTime(2026, 11, 20), now), '11/20 (금)');
    expect(dueLabel(DateTime(2027, 1, 3), now), '2027/1/3');
  });

  test('todo list saves to the database', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final todos = container.read(todoListProvider.notifier);
    await container.read(todoListProvider.future);

    await todos.add('  장보기  ', due: DateTime(2026, 11, 20));
    await todos.add('   '); // 빈 글은 무시
    var items = container.read(todoListProvider).value!;
    expect(items.single.title, '장보기');
    expect(items.single.dueDate, DateTime(2026, 11, 20));

    final id = items.single.id;
    await todos.setDue(id, null);
    await todos.rename(id, '마트 장보기');
    await todos.setDone(id, true);
    items = container.read(todoListProvider).value!;
    expect(items.single.due, isNull);
    expect(items.single.title, '마트 장보기');
    expect(items.single.done, isTrue);
    expect(items.single.doneAt, isNotNull);

    final removed = items.single;
    await todos.delete(id);
    expect(container.read(todoListProvider).value, isEmpty);
    await todos.restore(removed);
    expect(container.read(todoListProvider).value!.single.title, '마트 장보기');
    await todos.clearDone();
    expect(container.read(todoListProvider).value, isEmpty);
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
        final today = DateTime.now();
        final items = [
          _item(1, '지난 일', due: today.subtract(const Duration(days: 2))),
          _item(2, '오늘 할 일 ' * 12, due: today),
          _item(3, '기한 없는 일'),
          _item(4, '끝낸 일', done: true),
        ];
        ColorScheme scheme(Brightness b) =>
            ColorScheme.fromSeed(seedColor: appSeedColor, brightness: b);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [todoListProvider.overrideWith(() => _FakeTodos(items))],
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
        expect(find.text('끝낸 일'), findsNothing); // 완료는 따로
        expect(find.text('기한 지남'), findsOneWidget); // 묶음 제목
        // 사이드 패널은 '할 일'과 '완료' 두 개뿐
        expect(find.text('전체'), findsNothing);
        expect(find.text('나중에'), findsNothing);
        expect(find.text('3개 남음'), findsWidgets);
        expect(find.text('할 일 추가 (Enter)'), findsOneWidget);

        // 완료 보기
        await tester.tap(find.text('완료').first);
        await tester.pumpAndSettle();
        expect(find.text('끝낸 일'), findsOneWidget);
        expect(find.text('지난 일'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  // 기한을 정하고 추가: 마우스가 다른 할 일 위에 있어도 오류 없이 앞쪽에 들어감
  testWidgets('add a todo with a due date', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          home: Scaffold(
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
    Future<void> settle() async {
      // DB 작업은 실제 비동기라 runAsync로 기다림
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> add(String text, {String? due}) async {
      if (due != null) {
        await tester.tap(find.byKey(const ValueKey('todo-add-due')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(due).last);
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byType(TextField).first, text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle();
    }

    await settle();
    await add('나중 일');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('todo-check')).first),
    );
    await tester.pump(const Duration(seconds: 1));
    await add('오늘 일', due: '오늘');

    expect(tester.takeException(), isNull);
    final items = await tester.runAsync(() => db.select(db.todoTable).get());
    final today = DateTime.now();
    expect(
      items!.firstWhere((t) => t.title == '오늘 일').dueDate,
      DateTime(today.year, today.month, today.day),
    );
    // 기한 있는 것이 위로
    expect(
      tester.getTopLeft(find.text('오늘 일')).dy,
      lessThan(tester.getTopLeft(find.text('나중 일')).dy),
    );
  });
}
