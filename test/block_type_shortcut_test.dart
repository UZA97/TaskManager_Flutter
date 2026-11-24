import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmanager/features/memo/editor_v2/block_editor.dart';
import 'package:taskmanager/features/memo/editor_v2/block_editor_controller.dart';
import 'package:taskmanager/features/memo/editor_v2/editor_block.dart';

EditorBlock _line(String type, String text) => EditorBlock(
  type: type,
  data: type == 'todo_list' ? {'checked': false} : null,
  delta: [
    {'insert': text},
  ],
);

void main() {
  // 빈 줄에서도 ↑/↓로 이웃 줄로 이동
  for (final down in [true, false]) {
    testWidgets('empty line arrow ${down ? 'down' : 'up'} moves', (
      tester,
    ) async {
      final controller = BlockEditorController([
        _line('paragraph', 'above'),
        _line('paragraph', ''),
        _line('paragraph', 'below'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BlockEditor(controller: controller)),
        ),
      );
      final empty = controller.blocks[1];
      controller.focus(empty, 0);
      await tester.pumpAndSettle();
      expect(empty.focusNode.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(
        down ? LogicalKeyboardKey.arrowDown : LogicalKeyboardKey.arrowUp,
      );
      await tester.pumpAndSettle();
      final target = controller.blocks[down ? 2 : 0];
      expect(target.focusNode.hasPrimaryFocus, isTrue);
    });
  }

  testWidgets('toolbar state follows cursor line and selection', (
    tester,
  ) async {
    final controller = BlockEditorController([
      EditorBlock(
        type: 'paragraph',
        delta: [
          {'insert': 'plain '},
          {
            'insert': 'bold',
            'attributes': {'bold': true},
          },
        ],
      ),
      _line('todo_list', 'todo'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BlockEditor(controller: controller)),
      ),
    );
    var notified = 0;
    controller.formatState.addListener(() => notified++);
    final first = controller.blocks[0];

    await tester.tap(find.text('todo'));
    await tester.pump();
    expect(notified, greaterThan(0));
    expect(controller.isBlockTypeActive('todo_list'), isTrue);
    expect(controller.isMarkActive('bold'), isFalse);

    first.focusNode.requestFocus();
    await tester.pump();
    expect(controller.isBlockTypeActive('todo_list'), isFalse);
    // 굵은 글자만 선택 → 켜짐, 일반 글자까지 걸치면 꺼짐
    notified = 0;
    first.controller.selection = const TextSelection(
      baseOffset: 6,
      extentOffset: 10,
    );
    expect(notified, greaterThan(0));
    expect(controller.isMarkActive('bold'), isTrue);
    first.controller.selection = const TextSelection(
      baseOffset: 2,
      extentOffset: 10,
    );
    expect(controller.isMarkActive('bold'), isFalse);
    // 커서만: 바로 앞 글자의 서식, Ctrl+B로 켠 서식
    first.controller.selection = const TextSelection.collapsed(offset: 3);
    expect(controller.isMarkActive('bold'), isFalse);
    expect(controller.isMarkActive('italic'), isFalse);
    notified = 0;
    controller.toggleMark('italic');
    expect(notified, greaterThan(0));
    expect(controller.isMarkActive('italic'), isTrue);

    notified = 0;
    controller.toggleBlockType('heading', level: 2);
    expect(notified, greaterThan(0));
    expect(controller.isBlockTypeActive('heading', level: 2), isTrue);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
  });

  // 줄 종류를 바꾸는 단축키(Ctrl+1~6) 뒤에도 커서·선택·입력 연결이 그대로여야 함
  for (final (from, digit) in [
    ('paragraph', LogicalKeyboardKey.digit6),
    ('paragraph', LogicalKeyboardKey.digit4),
    ('numbered_list', LogicalKeyboardKey.digit6),
    ('heading', LogicalKeyboardKey.digit6),
    ('paragraph', LogicalKeyboardKey.digit1),
    ('todo_list', LogicalKeyboardKey.digit1),
    ('todo_list', LogicalKeyboardKey.digit6),
    ('bulleted_list', LogicalKeyboardKey.digit5),
  ]) {
    testWidgets('$from + Ctrl+${digit.keyLabel} keeps cursor', (tester) async {
      final controller = BlockEditorController([
        _line('paragraph', 'first'),
        _line(from, 'hello world'),
        _line('paragraph', 'last'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BlockEditor(controller: controller)),
        ),
      );
      final block = controller.blocks[1];
      await tester.tap(find.text('hello world'));
      await tester.pump();
      const selection = TextSelection(baseOffset: 2, extentOffset: 7);
      block.controller.selection = selection;
      await tester.pump();
      expect(block.focusNode.hasPrimaryFocus, isTrue);
      final before = tester.state<EditableTextState>(
        find.descendant(
          of: find.byKey(GlobalObjectKey(block)),
          matching: find.byType(EditableText),
        ),
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(digit);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      final after = tester.state<EditableTextState>(
        find.descendant(
          of: find.byKey(GlobalObjectKey(block)),
          matching: find.byType(EditableText),
        ),
      );
      expect(identical(before, after), isTrue, reason: '입력창이 새로 만들어짐');
      expect(block.focusNode.hasPrimaryFocus, isTrue);
      expect(block.controller.selection, selection);
      expect(tester.testTextInput.hasAnyClients, isTrue);

      // 이어서 입력되는지
      tester.testTextInput.enterText('typed');
      await tester.pump();
      expect(block.controller.text, 'typed');
      await tester.pump(const Duration(seconds: 1)); // 실행 취소 기록 타이머
    });
  }

  // 줄 끝에 있는 링크: 줄의 빈 곳을 누르면 열리지 않고, 링크 글자를 누르면 열림
  testWidgets('link at line end opens only when its text is clicked', (
    tester,
  ) async {
    final opened = <int>[];
    final controller = BlockEditorController([
      EditorBlock(
        type: 'paragraph',
        delta: [
          {'insert': 'see '},
          {
            'insert': 'other',
            'attributes': {'href': '${noteLinkScheme}7'},
          },
        ],
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlockEditor(controller: controller, onOpenNoteLink: opened.add),
        ),
      ),
    );
    final line = find.byType(EditableText).first;
    // 줄 오른쪽 끝의 빈 곳
    await tester.tapAt(tester.getTopRight(line) + const Offset(-20, 8));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);

    // 링크 글자 위
    final editable = tester.state<EditableTextState>(line).renderEditable;
    final box = editable
        .getBoxesForSelection(
          const TextSelection(baseOffset: 6, extentOffset: 7),
        )
        .first
        .toRect();
    await tester.tapAt(editable.localToGlobal(box.center));
    await tester.pumpAndSettle();
    expect(opened, [7]);
  });

  // 체크리스트 줄의 캘린더 버튼: 누르는 순간 포커스가 풀려 버튼이 사라지지 않고 눌림
  testWidgets(
    'todo calendar button responds to a click',
    (tester) async {
      final tapped = <EditorBlock>[];
      final controller = BlockEditorController([
        _line('todo_list', 'buy milk'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlockEditor(
              controller: controller,
              onTodoCalendar: tapped.add,
            ),
          ),
        ),
      );
      final block = controller.blocks.single;
      controller.focus(block, 0);
      await tester.pumpAndSettle();
      // 실제처럼 누른 뒤 한 프레임 그리고 뗌 (그 사이 포커스가 풀리면 버튼이 사라짐)
      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.event_outlined)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tapped, [block]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  // 드래그하다 화면 아래 끝을 넘으면 저절로 내려가며 선택이 넓어짐
  testWidgets(
    'drag selection auto-scrolls past the bottom edge',
    (tester) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = BlockEditorController([
        for (var i = 0; i < 80; i++) _line('paragraph', 'line $i'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BlockEditor(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(scroll.pixels, 0);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      final start = tester.getTopLeft(find.text('line 0')) + const Offset(2, 5);
      await mouse.down(start);
      await tester.pump();
      // 창 아래 끝 밖으로 끌고 그대로 잠시 둠
      await mouse.moveTo(const Offset(100, 395));
      await mouse.moveTo(const Offset(100, 420));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final scrolled = scroll.pixels;
      expect(scrolled, greaterThan(100));

      final range = controller.selectedRange;
      expect(range, isNotNull);
      expect(range!.si, 0);
      // 처음 화면(400px)에 보이던 줄보다 훨씬 아래까지 선택
      final lastVisibleAtStart = controller.blocks.indexWhere(
        (b) => b.controller.text == 'line 15',
      );
      expect(range.ei, greaterThan(lastVisibleAtStart));

      // 떼면 멈춤
      await mouse.up();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(scroll.pixels, scrolled);
      expect(controller.selection, isNotNull);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  // 메모 맨 끝 아래 빈 곳에서 위로 끌어도 마지막 줄 끝부터 선택되며 위로 굴러감
  testWidgets(
    'drag from below the last line selects upward with auto-scroll',
    (tester) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = BlockEditorController([
        for (var i = 0; i < 80; i++) _line('paragraph', 'line $i'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BlockEditor(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pumpAndSettle();
      final bottom = scroll.pixels;

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      final start =
          tester.getBottomLeft(find.text('line 79')) + const Offset(30, 40);
      await mouse.down(start);
      await tester.pump();
      await mouse.moveTo(Offset(100, start.dy / 2));
      await mouse.moveTo(const Offset(100, -20));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(scroll.pixels, lessThan(bottom - 100));
      final range = controller.selectedRange;
      expect(range, isNotNull);
      expect((range!.ei, range.eo), (79, 'line 79'.length)); // 마지막 줄 끝
      expect(range.si, lessThan(70));
      await mouse.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  // 드래그 중 굴러간 뒤 마우스를 조금 움직여도 시작한 줄로 되돌아가지 않음,
  // 누른 채 휠로 멀리 굴린 뒤 움직여도 오류 없음
  testWidgets(
    'drag keeps scroll position and survives scrolling far away',
    (tester) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = BlockEditorController([
        for (var i = 0; i < 200; i++) _line('paragraph', 'line $i'),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BlockEditor(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.down(
        tester.getTopLeft(find.text('line 0')) + const Offset(2, 5),
      );
      await tester.pump();
      await mouse.moveTo(const Offset(100, 395));
      await mouse.moveTo(const Offset(100, 420));
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // 화면 안으로 돌아와 조금 움직임 (자동 스크롤 멈춤)
      await mouse.moveTo(const Offset(100, 200));
      await tester.pump();
      final stopped = scroll.pixels;
      expect(stopped, greaterThan(100));
      await mouse.moveTo(const Offset(110, 205));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(scroll.pixels, stopped); // 시작한 줄로 되돌아가지 않음

      // 누른 채로 멀리 굴림 (휠) → 다시 움직임
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pump();
      final far = scroll.pixels;
      await mouse.moveTo(const Offset(120, 210));
      await tester.pump();
      await mouse.moveTo(const Offset(130, 220));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(scroll.pixels, far);
      final range = controller.selectedRange;
      expect(range!.si, 0);
      expect(range.ei, greaterThan(100));
      await mouse.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  // 들여쓴 빈 체크리스트 줄에서 Enter: 체크박스 해제 → 한 단계씩 내어쓰기 → 새 줄
  testWidgets('enter on an empty indented line steps out one level', (
    tester,
  ) async {
    EditorBlock todo(String text, int depth) => EditorBlock(
      type: 'todo_list',
      depth: depth,
      data: {'checked': false},
      delta: [
        if (text.isNotEmpty) {'insert': text},
      ],
    );
    final empty = todo('', 2);
    final controller = BlockEditorController([
      todo('부모', 0),
      todo('자식', 1),
      todo('손자', 2),
      empty,
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BlockEditor(controller: controller)),
      ),
    );
    controller.focus(empty, 0);
    await tester.pumpAndSettle();

    Future<void> enter() async {
      tester.testTextInput.enterText('\n');
      await tester.pumpAndSettle();
    }

    // 1) 체크박스 해제 (들여쓰기 그대로)
    await enter();
    expect((empty.type, empty.depth), ('paragraph', 2));
    // 2) 한 단계씩 내어쓰기
    await enter();
    expect((empty.type, empty.depth), ('paragraph', 1));
    await enter();
    expect((empty.type, empty.depth), ('paragraph', 0));
    expect(controller.blocks.length, 4); // 아직 새 줄은 없음
    expect(empty.focusNode.hasPrimaryFocus, isTrue);
    // 3) 맨 앞에서는 새 줄
    await enter();
    expect(controller.blocks.length, 5);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1)); // 실행 취소 기록 타이머
  });
}
