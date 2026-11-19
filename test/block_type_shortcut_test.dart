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
}
