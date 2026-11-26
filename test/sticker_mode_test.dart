import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmanager/core/database/database.dart';
import 'package:taskmanager/core/database/database_provider.dart';
import 'package:taskmanager/core/providers/navigation_provider.dart';
import 'package:taskmanager/features/todo/sticker_mode.dart';
import 'package:taskmanager/features/todo/todo_provider.dart';
import 'package:taskmanager/features/todo/todo_views.dart';

/// 실제 창은 건드리지 않고 불린 것만 기록
class _FakeWindow extends StickerWindow {
  _FakeWindow(super.db);
  final calls = <String>[];

  @override
  Future<void> enter() async => calls.add('enter');
  @override
  Future<void> exit() async => calls.add('exit');
  @override
  Future<void> setAlwaysOnTop(bool value) async => calls.add('top:$value');
  @override
  Future<void> startDragging() async => calls.add('drag');
}

/// 앱 화면처럼 스티커 모드면 스티커 화면, 아니면 할 일 화면
class _Shell extends ConsumerWidget {
  const _Shell();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(stickerModeProvider.select((s) => s.on))
      ? const StickerTodoView()
      : const Scaffold(body: TodoView());
}

void main() {
  test('스티커 창 위치 저장 형식', () {
    const r = Rect.fromLTWH(100, -20.4, 300, 420);
    expect(formatStickerBounds(r), '100,-20,300,420');
    expect(
      parseStickerBounds('100,-20,300,420'),
      const Rect.fromLTWH(100, -20, 300, 420),
    );
    expect(parseStickerBounds(null), isNull);
    expect(parseStickerBounds('1,2,3'), isNull);
    expect(parseStickerBounds('a,b,c,d'), isNull);
    expect(parseStickerBounds('0,0,10,10'), isNull); // 너무 작으면 기본 크기로
  });

  testWidgets('스티커 모드: 켜기·추가·완료·항상 위·원래 창으로', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final window = _FakeWindow(db);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        stickerWindowProvider.overrideWithValue(window),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(todoListProvider.notifier)
        .add('기한 지난 일', due: DateTime.now().subtract(const Duration(days: 1)));
    await container.read(todoListProvider.notifier).add('두 번째 일');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: _Shell()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('todo-sticker')));
    await tester.pumpAndSettle();
    expect(window.calls, ['enter']);
    expect(find.byType(StickerTodoView), findsOneWidget);
    expect(find.text('할 일 · 2'), findsOneWidget);

    // 작은 창 크기에서도 넘치지 않음
    tester.view.physicalSize = const Size(220, 160);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(300, 420);
    await tester.pumpAndSettle();

    // 추가
    await tester.enterText(find.byKey(const ValueKey('sticker-add')), '새 일');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('새 일'), findsOneWidget);
    expect(find.text('할 일 · 3'), findsOneWidget);

    // 완료: 줄을 그어 남겨 두고, 다시 누르면 되돌림
    final first = container
        .read(todoListProvider)
        .value!
        .firstWhere((t) => t.title == '두 번째 일');
    await tester.tap(find.byKey(ValueKey('sticker-check-${first.id}')));
    await tester.pumpAndSettle();
    expect(find.text('할 일 · 2'), findsOneWidget);
    expect(find.text('두 번째 일'), findsOneWidget);
    expect(
      container
          .read(todoListProvider)
          .value!
          .firstWhere((t) => t.id == first.id)
          .done,
      isTrue,
    );
    await tester.tap(find.byKey(ValueKey('sticker-check-${first.id}')));
    await tester.pumpAndSettle();
    expect(find.text('할 일 · 3'), findsOneWidget);

    // 기한: 오른쪽 클릭 → 내일
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    await tester.tap(find.text('두 번째 일'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('내일'));
    await tester.pumpAndSettle();
    TodoItem byTitle(String title) => container
        .read(todoListProvider)
        .value!
        .firstWhere((t) => t.title == title);
    expect(byTitle('두 번째 일').due, formatTodoDue(tomorrow));
    expect(
      find.descendant(
        of: find.byKey(ValueKey('sticker-due-${first.id}')),
        matching: find.text('내일'),
      ),
      findsOneWidget,
    );

    // 기한 글자를 눌러 지우기
    await tester.tap(find.byKey(ValueKey('sticker-due-${first.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기한 지우기'));
    await tester.pumpAndSettle();
    expect(byTitle('두 번째 일').due, isNull);

    // 새 할 일에 기한을 정해 추가
    await tester.tap(find.byKey(const ValueKey('sticker-add-due')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오늘'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sticker-add')), '오늘 일');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(byTitle('오늘 일').due, formatTodoDue(today));
    // 추가한 뒤에는 기한 선택이 비워짐
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sticker-add-due')),
        matching: find.byIcon(Icons.event_outlined),
      ),
      findsOneWidget,
    );

    // 가장 작은 창에서도 기한이 붙은 줄이 넘치지 않음
    tester.view.physicalSize = const Size(220, 160);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(300, 420);
    await tester.pumpAndSettle();

    // 한 번 누르면 펼쳐서 하위 할 일 추가
    await tester.tap(find.text('두 번째 일'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sticker-sub-add')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('sticker-sub-add')),
      '하위 1',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final sub = byTitle('하위 1');
    expect(sub.parentId, first.id);
    expect(find.text('하위 1'), findsOneWidget);
    // 추가 칸은 남아 있어 이어서 입력 가능
    expect(find.byKey(const ValueKey('sticker-sub-add')), findsOneWidget);
    // 하위 할 일 완료
    await tester.tap(find.byKey(ValueKey('sticker-subcheck-${sub.id}')));
    await tester.pumpAndSettle();
    expect(byTitle('하위 1').done, isTrue);
    // 하위 할 일을 누르면 이름 바꾸기
    await tester.enterText(
      find.byKey(const ValueKey('sticker-sub-add')),
      '하위 2',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final sub2 = byTitle('하위 2');
    await tester.tap(find.byKey(ValueKey('sticker-subtitle-${sub2.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('sticker-sub-rename')),
      '하위 이름',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(
      container
          .read(todoListProvider)
          .value!
          .firstWhere((t) => t.id == sub2.id)
          .title,
      '하위 이름',
    );
    expect(find.text('하위 이름'), findsOneWidget);
    // 마우스를 올리면 삭제 버튼
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('하위 이름')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('sticker-subdelete-${sub2.id}')));
    await tester.pumpAndSettle();
    expect(
      container.read(todoListProvider).value!.any((t) => t.id == sub2.id),
      isFalse,
    );
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    // 펼친 채로 가장 작은 창에서도 넘치지 않음
    tester.view.physicalSize = const Size(220, 160);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(300, 420);
    await tester.pumpAndSettle();
    // 빈 칸에서 Enter → 접힘
    await tester.enterText(find.byKey(const ValueKey('sticker-sub-add')), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sticker-sub-add')), findsNothing);
    expect(find.text('하위 1/1'), findsOneWidget);
    // 다시 펼치고 Esc로 접기
    await tester.tap(find.text('두 번째 일'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sticker-sub-add')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sticker-sub-add')), findsNothing);

    // 항상 위 끄기
    await tester.tap(find.byKey(const ValueKey('sticker-pin')));
    await tester.pumpAndSettle();
    expect(window.calls.last, 'top:false');

    // 두 번 누르면 원래 창에서 그 할 일을 엶
    tester.view.physicalSize = const Size(1000, 700);
    await tester.tap(find.text('두 번째 일'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('두 번째 일'));
    await tester.pumpAndSettle();
    expect(window.calls.last, 'exit');
    expect(find.byType(StickerTodoView), findsNothing);
    expect(container.read(navigationProvider), todoTabIndex);
    expect(container.read(todoSelectedProvider), first.id);
  });

  testWidgets('할 일 탭: 하위 할 일 누르면 이름 바꾸기, 오른쪽 버튼은 삭제', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container
        .read(todoListProvider.notifier)
        .add('상위', subtasks: ['하위 A', '하위 B']);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TodoView())),
      ),
    );
    await tester.pumpAndSettle();
    TodoItem byTitle(String title) => container
        .read(todoListProvider)
        .value!
        .firstWhere((t) => t.title == title);

    // 누르면 이름 바꾸기 (상세 패널이 열리지 않음)
    await tester.tap(find.text('하위 A'));
    await tester.pumpAndSettle();
    expect(container.read(todoSelectedProvider), isNull);
    await tester.enterText(
      find.byKey(const ValueKey('todo-rename-field')),
      '하위 가',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(byTitle('하위 가').isSubtask, isTrue);

    // 마우스를 올리면 ⋯ 대신 삭제 버튼
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('하위 B')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('todo-more')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('todo-sub-delete')));
    await tester.pumpAndSettle();
    expect(
      container.read(todoListProvider).value!.any((t) => t.title == '하위 B'),
      isFalse,
    );
    expect(find.text('하위 가'), findsOneWidget);
  });
}
