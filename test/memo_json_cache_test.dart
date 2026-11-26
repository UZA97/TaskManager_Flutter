import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmanager/core/database/database.dart';
import 'package:taskmanager/features/memo/data/note_repository.dart';
import 'package:taskmanager/features/memo/editor_v2/editor_block.dart';
import 'package:taskmanager/features/memo/providers/note_provider.dart';

String _old(List<EditorBlock> blocks) => jsonEncode(blocksToJson(blocks));

EditorBlock _text(String type, String text, {int depth = 0, Map<String, Object?>? data}) =>
    EditorBlock(
      type: type,
      depth: depth,
      data: data,
      delta: [
        {'insert': text},
        {
          'insert': ' 굵게',
          'attributes': {'bold': true},
        },
      ],
    );

void main() {
  // 줄마다 기억해 둔 JSON으로 만든 문자열이 예전 방식과 글자 하나까지 같아야 함
  test('blocksToJsonString은 예전 저장 형식과 같음', () {
    final blocks = [
      _text('heading', '제목', data: {'level': 2}),
      _text('paragraph', '문단'),
      _text('bulleted_list', '하위', depth: 1),
      _text('bulleted_list', '더 깊게 (추가 들여쓰기)', depth: 3),
      EditorBlock.divider(),
      EditorBlock.table(rows: 2, columns: 2),
      _text('todo_list', '할 일', depth: 1, data: {'checked': true}),
      EditorBlock.code(code: 'print("a\\n")'),
      _text('paragraph', ''),
      EditorBlock(type: 'paragraph'),
      _text('numbered_list', '"따옴표"와 \\ 역슬래시', depth: 2),
      EditorBlock.divider()..depth = 2,
      _text('paragraph', '끝'),
    ];
    expect(blocksToJsonString(blocks), _old(blocks));
    // 키가 겹치는 드문 경우
    final odd = [
      _text('paragraph', '끝'),
      _text('paragraph', 'x', depth: 1, data: {'extra_indent': 5}),
      _text('paragraph', 'y', depth: 3, data: {'delta': 1}),
    ];
    expect(blocksToJsonString(odd), _old(odd));
    // 다시 읽으면 같은 문서
    final again = blocksFromJson(blocksToJsonString(blocks));
    expect(_old(again), _old(blocks));
    expect(blocksToJsonString([EditorBlock(type: 'paragraph')]),
        _old([EditorBlock(type: 'paragraph')]));
  });

  test('글자·서식·줄 종류를 바꾸면 기억해 둔 JSON도 바뀜', () {
    final block = _text('paragraph', 'hello');
    final blocks = [block, _text('paragraph', 'b')];
    expect(blocksToJsonString(blocks), _old(blocks));

    block.controller.text = 'hello world';
    expect(blocksToJsonString(blocks), _old(blocks));

    block.controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
    block.controller.toggleMark('italic');
    expect(blocksToJsonString(blocks), contains('"italic":true'));
    expect(blocksToJsonString(blocks), _old(blocks));

    block.controller.applyMark('href', 'https://a.b', 0, 3);
    expect(blocksToJsonString(blocks), _old(blocks));

    // 글자는 그대로 두고 서식만 통째로 바꿈
    final text = block.controller.text;
    block.controller.setContent(
      text,
      List.filled(text.length, const {'underline': true}),
      0,
    );
    expect(blocksToJsonString(blocks), contains('"underline":true'));
    expect(blocksToJsonString(blocks), _old(blocks));

    block.changeType('todo_list');
    block.data['checked'] = true;
    block.depth = 1;
    expect(blocksToJsonString(blocks), _old(blocks));
  });

  test('자동 저장 후 메모 목록에는 본문을 두지 않음', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [noteRepositoryProvider.overrideWithValue(NoteRepository(db))],
    );
    addTearDown(container.dispose);
    final list = container.read(noteListProvider.notifier);
    await container.read(noteListProvider.future);
    await list.createNote();
    final note = container.read(noteListProvider).value!.first;

    await list.saveNote(note.copyWith(title: '제목', content: '{"긴":"본문"}'));
    final listed = container.read(noteListProvider).value!.first;
    expect(listed.title, '제목');
    expect(listed.contentLoaded, isFalse);
    expect(listed.content, isEmpty);
    // 본문은 DB에 저장됨
    expect((await list.loadContent(listed)).content, '{"긴":"본문"}');
  });
}
