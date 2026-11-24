import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmanager/core/database/database.dart';
import 'package:taskmanager/core/database/database_provider.dart';
import 'package:taskmanager/core/theme/app_colors.dart';
import 'package:taskmanager/features/memo/editor_v2/editor_block.dart';
import 'package:taskmanager/features/todo/todo_memo.dart';
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
    await todos.restore([removed]);
    expect(container.read(todoListProvider).value!.single.title, '마트 장보기');
    await todos.clearDone();
    expect(container.read(todoListProvider).value, isEmpty);
  });

  test('subtasks are saved, deleted and cleared with their parent', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final todos = container.read(todoListProvider.notifier);
    await container.read(todoListProvider.future);

    await todos.add('여행 준비', subtasks: ['여권', '  ', '환전']);
    var items = container.read(todoListProvider).value!;
    final parent = items.firstWhere((t) => !t.isSubtask);
    expect(subtasksOf(items, parent.id).map((t) => t.title), ['여권', '환전']);

    await todos.addSubtask(parent.id, '숙소 예약');
    items = container.read(todoListProvider).value!;
    expect(subtasksOf(items, parent.id), hasLength(3));

    // 지우면 하위 할 일도 함께, 되살리면 함께
    final removed = await todos.delete(parent.id);
    expect(removed, hasLength(4));
    expect(container.read(todoListProvider).value, isEmpty);
    await todos.restore(removed);
    expect(container.read(todoListProvider).value, hasLength(4));

    // 완료 지우기: 끝낸 할 일과 그 하위 할 일만
    await todos.add('남은 일', subtasks: ['끝낸 하위']);
    items = container.read(todoListProvider).value!;
    final open = items.firstWhere((t) => t.title == '남은 일');
    final openSub = subtasksOf(items, open.id).single;
    await todos.setDone(openSub.id, true);
    await todos.setDone(parent.id, true);
    await todos.clearDone();
    items = container.read(todoListProvider).value!;
    expect(items.map((t) => t.title), unorderedEquals(['남은 일', '끝낸 하위']));
  });

  group('todo into memo', () {
    EditorBlock heading(String text, {int level = 1}) => EditorBlock(
      type: 'heading',
      data: {'level': level},
      delta: [
        {'insert': text},
      ],
    );
    EditorBlock line(String text, {int depth = 0}) => EditorBlock(
      type: 'paragraph',
      depth: depth,
      delta: [
        if (text.isNotEmpty) {'insert': text},
      ],
    );

    test('goes to the bottom of the chosen heading', () {
      final blocks = [
        heading('장보기'), // 0
        line('우유'), // 1
        heading('세부', level: 2), // 2
        line('계란'), // 3
        line(''), // 4  빈 줄 앞에
        heading('업무'), // 5
        line('보고서'), // 6
        line(''), // 7
      ];
      expect(memoOutlineOf(blocks).map((e) => e.text), ['장보기', '세부', '업무']);
      // H1 '장보기'의 내용은 H2 '세부'까지 포함, 다음 H1 전 빈 줄 앞
      expect(todoInsertPoint(blocks, 0), (index: 4, depth: 0));
      expect(todoInsertPoint(blocks, 2), (index: 4, depth: 0));
      expect(todoInsertPoint(blocks, 5), (index: 7, depth: 0));
      // 맨 끝 (끝의 빈 줄 앞)
      expect(todoInsertPoint(blocks, null), (index: 7, depth: 0));
    });

    test('goes inside a collapsible section', () {
      final blocks = [
        EditorBlock(
          type: collapsibleSectionType,
          data: {'collapsed': true},
          delta: [
            {'insert': '섹션'},
          ],
        ),
        line('내용', depth: 1),
        line('밖'),
      ];
      expect(todoInsertPoint(blocks, 0), (index: 2, depth: 1));
    });

    test('todo and subtasks become checklist lines', () {
      final parent = _item(1, '여행 준비');
      final sub = TodoItem(
        id: 2,
        title: '여권',
        done: true,
        createdAt: '',
        parentId: 1,
      );
      final blocks = memoTodoBlocks(memoTodoLines(parent, [sub]), 1);
      expect(blocks.map((b) => b.type), ['todo_list', 'todo_list']);
      expect(blocks.map((b) => b.depth), [1, 2]);
      expect(blocks.map((b) => b.controller.text), ['여행 준비', '여권']);
      expect(blocks.map((b) => b.checked), [false, true]);
    });
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
          const TodoItem(
            id: 5,
            title: '하위 일',
            done: false,
            createdAt: '',
            parentId: 3,
          ),
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
        expect(find.text('3개 남음'), findsWidgets); // 하위 할 일은 세지 않음
        expect(find.text('하위 일'), findsOneWidget);
        expect(find.text('0/1'), findsOneWidget);
        expect(find.text('할 일 추가 (Enter) · 하위 할 일 (Tab)'), findsOneWidget);

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

  // 제목 + 하위 할 일을 한 번에: Tab으로 하위 줄, Enter로 다음 줄, 빈 줄에서 Enter로 추가
  testWidgets('add a todo with subtasks from the keyboard', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: TodoView())),
      ),
    );
    Future<void> settle() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
    }

    await settle();
    await tester.enterText(find.byType(TextField).first, '여행 준비');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    await tester.enterText(find.byType(TextField).at(1), '여권');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));
    await tester.enterText(find.byType(TextField).at(2), '환전');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done); // 빈 줄
    await settle();

    expect(tester.takeException(), isNull);
    final items = await tester.runAsync(() => db.select(db.todoTable).get());
    final parent = items!.singleWhere((t) => !t.isSubtask);
    expect(parent.title, '여행 준비');
    expect(subtasksOf(items, parent.id).map((t) => t.title), ['여권', '환전']);
    expect(find.text('0/2'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget); // 하위 줄은 정리됨
  });

  // 줄을 눌러도 이름 바꾸기가 아님, 이름 바꾸는 중에도 더보기 메뉴가 눌림
  testWidgets(
    'rename only from the more menu, which works while renaming',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todoListProvider.overrideWith(() => _FakeTodos([_item(1, '장보기')])),
          ],
          child: const MaterialApp(home: Scaffold(body: TodoView())),
        ),
      );
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);

      Future<void> click(Finder finder) async {
        final at = tester.getCenter(finder);
        await mouse.moveTo(at);
        await tester.pump();
        await mouse.down(at);
        await tester.pump();
        await mouse.up();
        await tester.pumpAndSettle();
      }

      // 줄을 누르면 상세 패널이 열리고, 줄에서 이름 바꾸기는 시작하지 않음
      await click(find.text('장보기'));
      expect(find.byKey(const ValueKey('todo-detail')), findsOneWidget);
      expect(find.byKey(const ValueKey('todo-rename-field')), findsNothing);

      await click(find.byKey(const ValueKey('todo-more')));
      await click(find.text('이름 바꾸기'));
      expect(find.byKey(const ValueKey('todo-rename-field')), findsOneWidget);

      // 이름을 고치는 중에 더보기 메뉴
      await click(find.byKey(const ValueKey('todo-more')));
      expect(find.widgetWithText(PopupMenuItem<String>, '삭제'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  // 상세 패널: 제목 고치기, 하위 할 일 추가, Esc로 닫기. 묶음 접기.
  testWidgets('detail panel edits the todo, groups collapse', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: TodoView())),
      ),
    );
    Future<void> settle() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
    }

    await settle();
    await tester.enterText(find.byType(TextField).first, '보고서');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle();

    await tester.tap(find.text('보고서'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('todo-detail')), findsOneWidget);

    // 제목 고치기
    await tester.enterText(
      find.byKey(const ValueKey('todo-detail-title')),
      '주간 보고서',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle();

    // 하위 할 일 추가
    await tester.enterText(
      find.byKey(const ValueKey('todo-detail-sub-field')),
      '표 정리',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle();

    final items = await tester.runAsync(() => db.select(db.todoTable).get());
    final parent = items!.singleWhere((t) => !t.isSubtask);
    expect(parent.title, '주간 보고서');
    expect(subtasksOf(items, parent.id).map((t) => t.title), ['표 정리']);
    // 목록과 상세 패널 양쪽에 하위 할 일
    expect(find.text('표 정리'), findsNWidgets(2));

    // 하위 할 일 접기
    await tester.tap(find.byKey(const ValueKey('todo-tree')));
    await tester.pumpAndSettle();
    expect(find.text('표 정리'), findsOneWidget); // 상세 패널에만

    // Esc로 상세 닫기
    await tester.tap(find.byKey(const ValueKey('todo-detail-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('todo-detail')), findsNothing);

    // 묶음 접기
    await tester.tap(find.byKey(const ValueKey('todo-group-none')));
    await tester.pumpAndSettle();
    expect(find.text('주간 보고서'), findsNothing);
    expect(find.text('기한 없음'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('today progress counts due-today, overdue and done-today', () {
    final now = DateTime(2026, 11, 23, 10);
    final items = [
      _item(1, 'a', due: DateTime(2026, 11, 23)),
      _item(2, 'b', due: DateTime(2026, 11, 20)),
      _item(3, 'c', due: DateTime(2026, 11, 30)),
      _item(
        4,
        'd',
        done: true,
      ).copyWith(doneAt: const Value('2026-11-23T09:00:00')),
      _item(
        5,
        'e',
        done: true,
      ).copyWith(doneAt: const Value('2026-11-22T09:00:00')),
    ];
    expect(todayProgress(items, now), (done: 1, total: 3));
  });
}
