import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'editor_block.dart';
import 'styled_text_controller.dart';

/// 글자색 (Alt+1~8, 기존 에디터와 같은 순서)
const editorTextColors = [
  Color(0xFFE53935), // 빨강
  Color(0xFFFF9800), // 주황
  Color(0xFFFFEB3B), // 노랑
  Color(0xFF4CAF50), // 초록
  Color(0xFF2196F3), // 파랑
  Color(0xFF3F51B5), // 남색
  Color(0xFF9C27B0), // 보라
  Color(0xFF9E9E9E), // 회색
];

/// 형광펜 (Alt+Shift+1~8)
const editorHighlightColors = [
  Color(0xFFFFCDD2),
  Color(0xFFFFE0B2),
  Color(0xFFFFF9C4),
  Color(0xFFC8E6C9),
  Color(0xFFBBDEFB),
  Color(0xFFC5CAE9),
  Color(0xFFE1BEE7),
  Color(0xFFF5F5F5),
];

/// appflowy와 같은 색 문자열 (0xffrrggbb)
String colorToHex(Color color) =>
    '0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toLowerCase()}';

class FindMatch {
  const FindMatch(this.block, this.start, this.end);

  final EditorBlock block;
  final int start;
  final int end;
}

/// 블록 목록과 편집 명령. 툴바·단축키·메뉴가 모두 이 명령을 사용.
class BlockEditorController extends ChangeNotifier {
  BlockEditorController(List<EditorBlock> blocks)
    : blocks = blocks.isEmpty ? [EditorBlock(type: 'paragraph')] : blocks {
    for (final block in this.blocks) {
      _register(block);
    }
    _current = _snapshot();
  }

  final List<EditorBlock> blocks;

  /// 내용이 바뀔 때마다 호출 (저장용)
  VoidCallback? onContentChanged;

  /// 블록별 키 처리 (에디터 위젯이 지정)
  KeyEventResult Function(EditorBlock block, KeyEvent event)? keyHandler;

  EditorBlock? _active;

  /// 마지막으로 커서가 있던 텍스트 블록 (툴바 버튼을 눌러 포커스가 빠져도 유지)
  EditorBlock? get activeBlock =>
      _active != null && blocks.contains(_active) ? _active : null;

  EditorBlock _register(EditorBlock block) {
    block.focusNode.onKeyEvent = (_, event) =>
        keyHandler?.call(block, event) ?? KeyEventResult.ignored;
    block.focusNode.addListener(() {
      if (block.focusNode.hasFocus) _active = block;
    });
    return block;
  }

  /// 새로 만든 블록을 에디터에 연결
  EditorBlock register(EditorBlock block) => _register(block);

  /// 블록 구성이 바뀜 → 다시 그리고 저장, 실행 취소 기록
  void contentChanged() {
    notifyListeners();
    onContentChanged?.call();
    _recordHistory(immediate: true);
  }

  /// 글자만 바뀜 → 저장 (입력창이 스스로 다시 그림), 잠시 멈추면 실행 취소 기록
  void textChanged() {
    onContentChanged?.call();
    _recordHistory();
  }

  String toJsonString() => jsonEncode(blocksToJson(blocks));

  @override
  void dispose() {
    _historyTimer?.cancel();
    for (final block in blocks) {
      block.dispose();
    }
    super.dispose();
  }

  void _disposeLater(Iterable<EditorBlock> removed) {
    final list = removed.toList();
    // 포커스가 다른 블록으로 옮겨간 뒤에 정리
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final block in list) {
        block.dispose();
      }
    });
  }

  // ───────────── 위치 계산

  /// [index] 블록과 그 하위 블록이 끝나는 위치 (다음 형제의 위치)
  int subtreeEnd(int index) {
    final depth = blocks[index].depth;
    var end = index + 1;
    while (end < blocks.length && blocks[end].depth > depth) {
      end++;
    }
    return end;
  }

  /// 접힌 섹션 안에 있어 보이지 않는 블록인지
  bool isHidden(int index) {
    var depth = blocks[index].depth;
    for (var i = index - 1; i >= 0 && depth > 0; i--) {
      final block = blocks[i];
      if (block.depth >= depth) continue;
      if (block.isSection && block.collapsed) return true;
      depth = block.depth;
    }
    return false;
  }

  /// 기존 문서 기준 경로 ([2, 0] = 세 번째 블록의 첫 자식)
  List<int> pathOf(int index) {
    final counters = <int>[];
    final depths = treeDepthsOf(blocks.sublist(0, index + 1));
    for (var i = 0; i <= index; i++) {
      final depth = min(depths[i], counters.length);
      if (depth < counters.length) {
        counters.removeRange(depth + 1, counters.length);
        counters[depth] += 1;
      } else {
        counters.add(0);
      }
    }
    return counters;
  }

  // ───────────── 커서

  /// 화면 밖이라 아직 만들어지지 않은 블록까지 스크롤 (에디터 위젯이 지정)
  Future<void> Function(EditorBlock block, double alignment)? revealer;

  Future<void> reveal(EditorBlock block, {double alignment = 0.5}) async {
    await revealer?.call(block, alignment);
  }

  void focus(EditorBlock block, int offset) {
    // 새로 만든 블록은 다음 프레임에 화면에 붙으므로 그 뒤에 포커스
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!blocks.contains(block) || !block.isText) return;
      if (!block.isOnScreen) await reveal(block);
      if (!blocks.contains(block)) return;
      block.controller.selection = TextSelection.collapsed(
        offset: offset.clamp(0, block.controller.text.length),
      );
      block.focusNode.requestFocus();
    });
    WidgetsBinding.instance.scheduleFrame(); // 그릴 것이 없어도 위 콜백이 실행되도록
  }

  /// 선택 범위를 유지한 채 다시 포커스 (툴바 버튼 사용 후)
  void refocus(EditorBlock block) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!blocks.contains(block) || !block.isText) return;
      if (!block.isOnScreen) await reveal(block);
      if (blocks.contains(block)) block.focusNode.requestFocus();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  // ───────────── 서식

  void toggleMark(String key) {
    if (_selection != null) return _toggleMarkInSelection(key, true);
    final block = activeBlock;
    if (block == null) return;
    block.controller.toggleMark(key);
    textChanged();
    refocus(block);
  }

  void toggleColor(String key, Color color) {
    if (_selection != null) {
      return _toggleMarkInSelection(key, colorToHex(color));
    }
    final block = activeBlock;
    if (block == null) return;
    block.controller.toggleMarkValue(key, colorToHex(color));
    textChanged();
    refocus(block);
  }

  /// 여러 줄 선택: 전부 이미 그 서식이면 해제, 아니면 적용
  void _toggleMarkInSelection(String key, Object value) {
    final parts = [
      for (final (block, start, end) in selectedParts)
        if (block.isText && start < end) (block, start, end),
    ];
    if (parts.isEmpty) return;
    final clear = parts.every(
      (p) => p.$1.controller.rangeHas(key, value, p.$2, p.$3),
    );
    for (final (block, start, end) in parts) {
      block.controller.applyMark(key, clear ? null : value, start, end);
    }
    applySelectionHighlights();
    textChanged();
  }

  void setAlign(String align) {
    final block = activeBlock;
    if (block == null) return;
    block.data['align'] = align;
    contentChanged();
    refocus(block);
  }

  /// 블록 종류 전환. 이미 그 종류면 일반 문단으로.
  void toggleBlockType(String type, {int? level}) {
    final active = activeBlock;
    // 여러 줄 선택이면 선택한 줄 전부 (섹션 제외)
    final targets = _selection != null
        ? [
            for (final (block, _, _) in selectedParts)
              if (block.isText && !block.isSection) block,
          ]
        : [?active];
    if (targets.isEmpty) return;
    final same = targets.every(
      (b) => b.type == type && (level == null || b.level == level),
    );
    for (final block in targets) {
      block.changeType(same ? 'paragraph' : type, level: level);
    }
    contentChanged();
    if (active != null) refocus(active);
  }

  /// 여러 줄 선택 안의 체크박스 전부: 모두 체크돼 있으면 해제, 아니면 전부 체크
  void toggleTodosInSelection() {
    final todos = [
      for (final (block, _, _) in selectedParts)
        if (block.type == 'todo_list') block,
    ];
    if (todos.isEmpty) return;
    final check = !todos.every((b) => b.checked);
    for (final block in todos) {
      block.data['checked'] = check;
    }
    contentChanged();
  }

  void toggleTodo(EditorBlock block) {
    block.data['checked'] = !block.checked;
    contentChanged();
  }

  void toggleCollapsed(EditorBlock section) {
    section.data['collapsed'] = !section.collapsed;
    contentChanged();
  }

  // ───────────── 블록 추가·삭제·이동

  /// 커서 블록 다음에 [newBlocks]를 넣음 (빈 문단이면 그 자리를 대체).
  /// [newBlocks]의 depth는 첫 블록 기준 상대값.
  void insertBlocks(List<EditorBlock> newBlocks, {EditorBlock? focusTarget}) {
    if (newBlocks.isEmpty) return;
    final active = activeBlock;
    var insertAt = blocks.length;
    var depth = 0;
    if (active != null) {
      final index = blocks.indexOf(active);
      depth = active.depth;
      final isEmptyLine =
          active.type == 'paragraph' &&
          active.controller.text.isEmpty &&
          subtreeEnd(index) == index + 1;
      if (isEmptyLine && blocks.length > 1) {
        blocks.removeAt(index);
        _disposeLater([active]);
        insertAt = index;
      } else {
        insertAt = subtreeEnd(index);
      }
    }

    for (final block in newBlocks) {
      block.depth += depth;
      _register(block);
    }
    blocks.insertAll(insertAt, newBlocks);

    // 텍스트가 아닌 블록 뒤에는 이어서 쓸 빈 줄
    final after = insertAt + newBlocks.length;
    if (!newBlocks.last.isText &&
        (after >= blocks.length || !blocks[after].isText)) {
      final line = _register(EditorBlock(type: 'paragraph', depth: depth));
      blocks.insert(after, line);
    }
    contentChanged();

    // 코드 블록은 자기 입력칸에 바로 커서가 감
    if (focusTarget == null && newBlocks.last.type == localCodeType) return;
    final target =
        focusTarget ??
        (newBlocks.last.isText
            ? newBlocks.last
            : (after < blocks.length ? blocks[after] : null));
    if (target != null) focus(target, target.controller.text.length);
  }

  /// 접기 섹션 (제목 + 빈 내용 한 줄)
  void insertSection() {
    final section = EditorBlock(type: collapsibleSectionType)
      ..changeType(collapsibleSectionType);
    final body = EditorBlock(type: 'paragraph', depth: 1);
    insertBlocks([section, body], focusTarget: section);
  }

  /// 블록과 그 하위 블록을 삭제
  void removeBlock(EditorBlock block) {
    final start = blocks.indexOf(block);
    if (start < 0) return;
    final end = subtreeEnd(start);
    final removed = blocks.sublist(start, end);
    blocks.removeRange(start, end);
    if (blocks.isEmpty) blocks.add(_register(EditorBlock(type: 'paragraph')));
    contentChanged();
    _disposeLater(removed);
  }

  /// Alt+↑/↓: 같은 단계의 이웃 블록과 자리 바꾸기 (하위 블록 포함)
  void moveBlock(EditorBlock block, int direction) {
    final start = blocks.indexOf(block);
    if (start < 0) return;
    final end = subtreeEnd(start);
    final moving = blocks.sublist(start, end);
    if (direction < 0) {
      var previous = start - 1;
      while (previous >= 0 && blocks[previous].depth > block.depth) {
        previous--;
      }
      if (previous < 0 || blocks[previous].depth != block.depth) return;
      blocks.removeRange(start, end);
      blocks.insertAll(previous, moving);
    } else {
      if (end >= blocks.length || blocks[end].depth != block.depth) return;
      final nextEnd = subtreeEnd(end);
      blocks.removeRange(start, end);
      blocks.insertAll(nextEnd - moving.length, moving);
    }
    contentChanged();
    refocus(block);
  }

  static const maxIndentDepth = 10;

  /// 들여쓰기(Tab) / 내어쓰기(Shift+Tab). 하위 블록도 같이 옮기고,
  /// 이미 같이 옮겨진 하위 블록은 다시 옮기지 않음.
  void indentBlocks(Iterable<EditorBlock> targets, {required bool outdent}) {
    var changed = false;
    var movedUntil = -1;
    for (final block in targets) {
      final index = blocks.indexOf(block);
      if (index < 0 || index < movedUntil) continue;
      // 업노트처럼 위 줄과 상관없이 몇 단계든 (최대 [maxIndentDepth])
      if (outdent ? block.depth == 0 : block.depth >= maxIndentDepth) continue;
      final end = subtreeEnd(index);
      for (var i = index; i < end; i++) {
        blocks[i].depth += outdent ? -1 : 1;
      }
      movedUntil = end;
      changed = true;
    }
    if (changed) contentChanged();
  }

  /// 그 블록 다음에 빈 줄
  void insertParagraphAfter(EditorBlock block) {
    final index = blocks.indexOf(block);
    if (index < 0) return;
    final line = _register(EditorBlock(type: 'paragraph', depth: block.depth));
    blocks.insert(subtreeEnd(index), line);
    contentChanged();
    focus(line, 0);
  }

  // ───────────── 찾기·바꾸기

  List<FindMatch> find(String query) {
    if (query.isEmpty) return const [];
    final needle = query.toLowerCase();
    final result = <FindMatch>[];
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (!block.isText || isHidden(i)) continue;
      final haystack = block.controller.text.toLowerCase();
      var from = 0;
      while (true) {
        final at = haystack.indexOf(needle, from);
        if (at < 0) break;
        result.add(FindMatch(block, at, at + needle.length));
        from = at + needle.length;
      }
    }
    return result;
  }

  void showFindHighlights(List<FindMatch> matches, FindMatch? current) {
    for (final block in blocks) {
      if (!block.isText) continue;
      block.controller.setFindHighlights(
        [
          for (final m in matches)
            if (m.block == block) TextRange(start: m.start, end: m.end),
        ],
        current?.block == block
            ? TextRange(start: current!.start, end: current.end)
            : null,
      );
    }
  }

  void clearFindHighlights() => showFindHighlights(const [], null);

  void replace(FindMatch match, String replacement) {
    final controller = match.block.controller;
    controller.value = TextEditingValue(
      text: controller.text.replaceRange(match.start, match.end, replacement),
      selection: TextSelection.collapsed(
        offset: match.start + replacement.length,
      ),
    );
    textChanged();
  }

  // ───────────── 여러 줄 선택

  BlockSelection? _selection;

  /// 여러 블록에 걸친 선택 (한 줄 안의 선택은 입력창이 직접 관리하므로 null)
  BlockSelection? get selection => _selection;

  /// 선택 범위를 문서 순서로 (시작 블록·위치, 끝 블록·위치)
  ({int si, int so, int ei, int eo})? get selectedRange {
    final s = _selection;
    if (s == null) return null;
    final bi = blocks.indexOf(s.baseBlock);
    final xi = blocks.indexOf(s.extentBlock);
    if (bi < 0 || xi < 0) return null;
    if (bi < xi || (bi == xi && s.baseOffset <= s.extentOffset)) {
      return (si: bi, so: s.baseOffset, ei: xi, eo: s.extentOffset);
    }
    return (si: xi, so: s.extentOffset, ei: bi, eo: s.baseOffset);
  }

  /// 선택 범위에 든 블록과 각 블록의 선택 구간 [start, end)
  /// (텍스트가 아닌 블록은 통째로 (0, 1))
  List<(EditorBlock, int, int)> get selectedParts {
    final r = selectedRange;
    if (r == null) return const [];
    return [
      for (var i = r.si; i <= r.ei; i++)
        if (!blocks[i].isText)
          (blocks[i], 0, 1)
        else
          (
            blocks[i],
            i == r.si ? r.so.clamp(0, blocks[i].controller.text.length) : 0,
            i == r.ei
                ? r.eo.clamp(0, blocks[i].controller.text.length)
                : blocks[i].controller.text.length,
          ),
    ];
  }

  /// 줄 전체가 선택되어 배경을 칠해야 하는 블록 (글자가 없어 글자 배경으로는 안 보이는 줄)
  Set<EditorBlock> get selectedRows => {
    for (final (b, _, _) in selectedParts)
      if (!b.isText || b.controller.text.isEmpty) b,
  };

  void setSelection(BlockSelection? selection) {
    if (selection != null &&
        selection.baseBlock == selection.extentBlock &&
        selection.baseBlock.isText) {
      // 한 줄 안이면 입력창의 일반 선택으로
      clearSelection();
      selection.baseBlock.controller.selection = TextSelection(
        baseOffset: selection.baseOffset,
        extentOffset: selection.extentOffset,
      );
      return;
    }
    _selection = selection;
    applySelectionHighlights();
    notifyListeners();
  }

  void clearSelection() {
    if (_selection == null) return;
    _selection = null;
    for (final block in blocks) {
      if (block.isText) block.controller.setSelectionHighlight(null);
    }
    notifyListeners();
  }

  /// 포커스 있는 줄은 입력창 선택으로, 나머지 줄은 글자 배경으로 선택 표시
  void applySelectionHighlights() {
    final parts = {for (final p in selectedParts) p.$1: p};
    for (final block in blocks) {
      if (!block.isText) continue;
      final part = parts[block];
      if (part != null && block.focusNode.hasFocus) {
        block.controller.setSelectionHighlight(null);
        final (_, start, end) = part;
        final sel = TextSelection(baseOffset: start, extentOffset: end);
        if (block.controller.selection != sel) {
          block.controller.selection = sel;
        }
      } else {
        block.controller.setSelectionHighlight(
          part == null || part.$2 == part.$3
              ? null
              : TextRange(start: part.$2, end: part.$3),
        );
      }
    }
  }

  /// 문서 전체 선택
  void selectAll() {
    setSelection(
      BlockSelection(
        blocks.first,
        0,
        blocks.last,
        blocks.last.isText ? blocks.last.controller.text.length : 1,
      ),
    );
  }

  /// 선택한 내용을 지우고 그 자리에 커서
  void deleteSelection() {
    final r = selectedRange;
    if (r == null) return;
    final first = blocks[r.si];
    final last = blocks[r.ei];

    // 앞부분(첫 줄의 선택 앞) + 뒷부분(마지막 줄의 선택 뒤)을 한 줄로
    var head = '';
    var headMarks = const <Marks>[];
    if (first.isText) {
      final so = r.so.clamp(0, first.controller.text.length);
      head = first.controller.text.substring(0, so);
      headMarks = first.controller.marks.sublist(0, so);
    }
    var tail = '';
    var tailMarks = const <Marks>[];
    if (last.isText) {
      final eo = r.eo.clamp(0, last.controller.text.length);
      tail = last.controller.text.substring(eo);
      tailMarks = last.controller.marks.sublist(eo);
    }

    // 남길 줄: 포커스가 있는 줄 (지금 누른 글자·한글 조합이 그 입력창으로 들어가므로)
    final active = activeBlock;
    final rangeBlocks = blocks.sublist(r.si, r.ei + 1);
    final EditorBlock survivor;
    if (active != null &&
        active.isText &&
        !active.isSection &&
        rangeBlocks.contains(active)) {
      survivor = active;
    } else if (first.isText) {
      survivor = first;
    } else {
      survivor = _register(EditorBlock(type: 'paragraph', depth: first.depth));
    }
    // 남는 줄은 첫 줄의 종류·단계를 이어받음
    if (survivor != first && first.isText && !first.isSection) {
      survivor.type = first.type;
      survivor.data
        ..clear()
        ..addAll(jsonDecode(jsonEncode(first.data)) as Map<String, Object?>);
    }
    if (survivor != first) survivor.depth = first.depth;
    survivor.controller.setContent(head + tail, [
      ...headMarks,
      ...tailMarks,
    ], head.length);

    final removed = [
      for (final b in rangeBlocks)
        if (b != survivor) b,
    ];
    blocks.removeRange(r.si, r.ei + 1);
    blocks.insert(r.si, survivor);
    _active = survivor;
    _selection = null;
    for (final block in blocks) {
      if (block.isText) block.controller.setSelectionHighlight(null);
    }
    contentChanged();
    _disposeLater(removed);
    focus(survivor, head.length);
  }

  // ───────────── 복사·붙여넣기 (서식 유지)

  /// 마지막 내부 복사본. 클립보드 글자가 이것과 같을 때만 서식째 붙여넣음
  /// (그 뒤 다른 곳에서 복사했으면 일반 붙여넣기). 메모 사이에서도 유지.
  static _InternalClipboard? _clipboard;

  static String _normalize(String? text) =>
      (text ?? '').replaceAll('\r\n', '\n');

  /// 선택 내용을 복사. 복사할 게 없으면 false.
  bool copySelection() {
    var parts = selectedParts;
    if (parts.isEmpty) {
      final block = activeBlock;
      final sel = block?.controller.selection;
      if (block == null || sel == null || !sel.isValid || sel.isCollapsed) {
        return false;
      }
      final c = block.controller;
      final whole = sel.start == 0 && sel.end == c.text.length;
      if (!whole || block.type == 'paragraph') {
        // 한 줄 안의 일부: 글자 서식만 유지
        final text = c.text.substring(sel.start, sel.end);
        _clipboard = _InternalClipboard(
          plain: text,
          inlineMarks: c.marks.sublist(sel.start, sel.end),
        );
        Clipboard.setData(ClipboardData(text: text));
        return true;
      }
      // 체크박스·목록 줄 전체: 블록 종류까지 유지
      parts = [(block, 0, c.text.length)];
    }

    final minDepth = parts.map((p) => p.$1.depth).reduce(min);
    final clones = [
      for (final (block, start, end) in parts)
        block.isText
            ? EditorBlock(
                type: block.type,
                depth: block.depth - minDepth,
                data:
                    jsonDecode(jsonEncode(block.data)) as Map<String, Object?>,
                delta: block.controller.toDelta(start, end),
              )
            : EditorBlock(
                type: block.type,
                depth: block.depth - minDepth,
                raw: jsonDecode(jsonEncode(block.raw)) as Map<String, Object?>,
              ),
    ];
    final plain = _plainText(clones);
    final nodes =
        (blocksToJson(clones)['document'] as Map)['children'] as List<Object?>;
    for (final clone in clones) {
      clone.dispose();
    }
    _clipboard = _InternalClipboard(plain: plain, nodesJson: jsonEncode(nodes));
    Clipboard.setData(ClipboardData(text: plain));
    return true;
  }

  /// 다른 앱에 붙여넣을 글자 (목록은 •, 1. 표시)
  static String _plainText(List<EditorBlock> blocks) {
    final lines = <String>[];
    var number = 1;
    for (final block in blocks) {
      final indent = '    ' * block.depth;
      final text = block.isText ? block.controller.text : '';
      switch (block.type) {
        case 'bulleted_list':
          lines.add('$indent• $text');
        case 'numbered_list':
          lines.add('$indent$number. $text');
          number++;
          continue;
        default:
          lines.add('$indent$text');
      }
      number = 1;
    }
    return lines.join('\n');
  }

  /// 클립보드 글자가 마지막 내부 복사본이면 서식째 붙여넣고 true
  bool pasteInternal(String? clipboardText) {
    final clip = _clipboard;
    if (clip == null || _normalize(clipboardText) != _normalize(clip.plain)) {
      return false;
    }
    if (_selection != null) deleteSelection();
    final block = activeBlock;
    if (block == null) return false;

    final inline = clip.inlineMarks;
    if (inline != null) {
      block.controller.insertStyled(clip.plain, inline);
      textChanged();
      return true;
    }
    final pasted = blocksFromJson(
      jsonEncode({
        'document': {'type': 'page', 'children': jsonDecode(clip.nodesJson!)},
      }),
    );
    insertBlocks(pasted);
    return true;
  }

  // ───────────── 실행 취소 (줄 나누기·합치기·이동까지 문서 전체 기준)

  final _undo = <_Snapshot>[];
  final _redo = <_Snapshot>[];
  late _Snapshot _current;
  Timer? _historyTimer;
  bool _restoring = false;

  _Snapshot _snapshot() {
    final active = activeBlock;
    return _Snapshot(
      toJsonString(),
      active == null ? -1 : blocks.indexOf(active),
      active?.controller.selection.baseOffset ?? 0,
    );
  }

  /// 구조 변경은 바로, 글자 입력은 잠시 멈췄을 때 한 단계로 기록
  void _recordHistory({bool immediate = false}) {
    if (_restoring) return;
    _historyTimer?.cancel();
    if (immediate) {
      _commitHistory();
    } else {
      _historyTimer = Timer(const Duration(milliseconds: 600), _commitHistory);
    }
  }

  void _commitHistory() {
    _historyTimer?.cancel();
    final snapshot = _snapshot();
    if (snapshot.json == _current.json) return;
    _undo.add(_current);
    if (_undo.length > 200) _undo.removeAt(0);
    _redo.clear();
    _current = snapshot;
  }

  bool get canUndo => _undo.isNotEmpty || _snapshot().json != _current.json;

  void undo() {
    _commitHistory(); // 아직 기록 안 된 입력부터 한 단계로
    if (_undo.isEmpty) return;
    _redo.add(_current);
    _current = _undo.removeLast();
    _restore(_current);
  }

  void redo() {
    _commitHistory();
    if (_redo.isEmpty) return;
    _undo.add(_current);
    _current = _redo.removeLast();
    _restore(_current);
  }

  void _restore(_Snapshot snapshot) {
    _restoring = true;
    final old = [...blocks];
    _selection = null;
    blocks
      ..clear()
      ..addAll(blocksFromJson(snapshot.json).map(_register));
    notifyListeners();
    onContentChanged?.call();
    _disposeLater(old);
    final index = snapshot.activeIndex.clamp(0, blocks.length - 1);
    final target = blocks[index].isText
        ? blocks[index]
        : blocks.firstWhere((b) => b.isText, orElse: () => blocks[index]);
    focus(target, snapshot.offset);
    _restoring = false;
  }
}

class BlockSelection {
  const BlockSelection(
    this.baseBlock,
    this.baseOffset,
    this.extentBlock,
    this.extentOffset,
  );

  /// 선택을 시작한 곳
  final EditorBlock baseBlock;
  final int baseOffset;

  /// 선택이 끝난 곳 (드래그·Shift+방향키로 움직이는 쪽)
  final EditorBlock extentBlock;
  final int extentOffset;
}

class _InternalClipboard {
  const _InternalClipboard({
    required this.plain,
    this.inlineMarks,
    this.nodesJson,
  });

  final String plain;

  /// 한 줄 안의 일부를 복사했을 때 글자별 서식
  final List<Marks>? inlineMarks;

  /// 여러 줄(블록)을 복사했을 때 문서 JSON
  final String? nodesJson;
}

class _Snapshot {
  const _Snapshot(this.json, this.activeIndex, this.offset);

  final String json;
  final int activeIndex;
  final int offset;
}
