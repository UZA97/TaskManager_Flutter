import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../../core/theme/app_colors.dart';
import 'block_editor_controller.dart';
import 'editor_block.dart';
import 'embed_video_dialog.dart';
import 'link_preview.dart';
import 'object_blocks.dart';

/// `/` 메뉴 항목
class SlashMenuItem {
  const SlashMenuItem(this.name, this.icon, this.keywords, this.onSelect);

  final String name;
  final IconData icon;
  final List<String> keywords;
  final VoidCallback onSelect;

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
        keywords.any((k) => k.toLowerCase().contains(q));
  }
}

const _cursorColor = Color(0xFF00BCF0);
const _selectionColor = Color(0x6600B0FF);
const _todoColor = Color(0xFF00BCF0);
const _indentWidth = 24.0;

/// 줄(블록)마다 Flutter 기본 입력창을 쓰는 메모 에디터.
/// 글자 입력과 한글 조합은 기본 입력창에 맡기고, 줄 나누기·합치기·이동만 직접 처리.
class BlockEditor extends StatefulWidget {
  const BlockEditor({
    super.key,
    required this.controller,
    this.extraSlashItems = const [],
    this.onPaste,
    this.onFind,
    this.padding = const EdgeInsets.symmetric(horizontal: 36),
  });

  final BlockEditorController controller;

  /// 기본 항목 뒤에 붙는 `/` 메뉴 항목 (위치·파일·AI 등)
  final List<SlashMenuItem> extraSlashItems;

  /// Ctrl+V. 이미지 등을 직접 처리했으면 true (아니면 텍스트 붙여넣기)
  final Future<bool> Function()? onPaste;

  /// Ctrl+F(false) / Ctrl+H(true)
  final void Function(bool replace)? onFind;

  final EdgeInsets padding;

  @override
  State<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends State<BlockEditor> {
  BlockEditorController get _c => widget.controller;
  List<EditorBlock> get _blocks => _c.blocks;

  // `/` 메뉴 상태
  final _slashPortal = OverlayPortalController();
  EditorBlock? _slashBlock;
  int _slashStart = 0;
  String _slashQuery = '';
  int _slashIndex = 0;

  @override
  void initState() {
    super.initState();
    _c.keyHandler = _onKey;
    _c.revealer = _reveal;
    _c.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(BlockEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      _closeSlash();
      _c.keyHandler = _onKey;
      _c.revealer = _reveal;
      _c.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    _scroll.dispose();
    _list.dispose();
    super.dispose();
  }

  final _scroll = ScrollController();

  /// 줄 번호로 바로 이동 (중간 줄을 하나씩 만들지 않고 높이를 추정해서 건너뜀)
  final _list = ListController();

  /// 화면에 보이는 줄만 만들기 때문에, 멀리 있는 블록은 그 항목으로 바로 이동해
  /// 만들어지게 한 뒤 정확한 위치로 맞춤
  Future<void> _reveal(EditorBlock block, double alignment) async {
    final context = GlobalObjectKey(block).currentContext;
    if (context == null || !context.mounted) {
      final item = _itemOf[block] ?? _itemOf[_sectionOf(block)];
      if (item == null || !_scroll.hasClients || !_list.isAttached) return;
      _list.jumpToItem(
        index: item,
        scrollController: _scroll,
        alignment: alignment,
      );
      await WidgetsBinding.instance.endOfFrame;
    }
    // 섹션 안의 줄이면 섹션 안에서의 위치까지 맞춤
    final built = GlobalObjectKey(block).currentContext;
    if (built != null && built.mounted) {
      await Scrollable.ensureVisible(built, alignment: alignment);
    }
  }

  /// 블록이 들어 있는 맨 바깥 섹션
  EditorBlock? _sectionOf(EditorBlock block) {
    final index = _blocks.indexOf(block);
    EditorBlock? section;
    var depth = index < 0 ? 0 : _blocks[index].depth;
    for (var i = index - 1; i >= 0 && depth > 0; i--) {
      if (_blocks[i].depth < depth) {
        depth = _blocks[i].depth;
        if (_blocks[i].isSection) section = _blocks[i];
      }
    }
    return section;
  }

  /// Ctrl+Home / Ctrl+End: 문서 첫 줄 처음 / 마지막 줄 끝
  void _jumpToEdge({required bool start}) {
    _c.clearSelection();
    final visible = [
      for (var i = 0; i < _blocks.length; i++)
        if (_blocks[i].isText && !_c.isHidden(i)) _blocks[i],
    ];
    if (visible.isEmpty) return;
    final target = start ? visible.first : visible.last;
    if (_scroll.hasClients && _list.isAttached && _items.isNotEmpty) {
      _list.jumpToItem(
        index: start ? 0 : _items.length, // 끝: 맨 아래 빈 공간까지
        scrollController: _scroll,
        alignment: start ? 0 : 1,
      );
    }
    _c.focus(target, start ? 0 : target.controller.text.length);
  }

  /// Page Up / Page Down: 한 화면만큼 스크롤하고, 커서는 화면에서 같은 높이의 줄로
  void _page(EditorBlock block, int direction) {
    _c.clearSelection();
    final editable = _renderEditableOf(block);
    if (!_scroll.hasClients || editable == null) return;
    final position = _scroll.position;
    final caret = editable.getLocalRectForCaret(
      TextPosition(offset: block.controller.selection.extentOffset),
    );
    final caretPoint = editable.localToGlobal(caret.center);
    final target =
        (position.pixels + direction * position.viewportDimension * 0.9).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    if (target == position.pixels) {
      // 더 넘길 곳이 없으면 문서 처음/끝으로
      return _jumpToEdge(start: direction < 0);
    }
    _scroll.jumpTo(target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final next = _textBlockAt(caretPoint);
      if (next == null) return;
      _c.focus(next, _offsetAt(next, caretPoint));
    });
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  // ───────────── `/` 메뉴

  List<SlashMenuItem> get _slashItems {
    void turnInto(String type, {int? level}) {
      final block = _c.activeBlock;
      if (block == null) return;
      block.changeType(type, level: level);
      _c.contentChanged();
      _c.refocus(block);
    }

    return [
      SlashMenuItem('Text', Icons.text_fields, [
        'text',
        'paragraph',
        '텍스트',
      ], () => turnInto('paragraph')),
      SlashMenuItem('Heading 1', Icons.title, [
        'h1',
        'heading',
        '제목',
      ], () => turnInto('heading', level: 1)),
      SlashMenuItem('Heading 2', Icons.title, [
        'h2',
        'heading',
        '제목',
      ], () => turnInto('heading', level: 2)),
      SlashMenuItem('Heading 3', Icons.title, [
        'h3',
        'heading',
        '제목',
      ], () => turnInto('heading', level: 3)),
      SlashMenuItem('Bulleted List', Icons.format_list_bulleted, [
        'bulleted',
        'list',
        '목록',
      ], () => turnInto('bulleted_list')),
      SlashMenuItem('Numbered List', Icons.format_list_numbered, [
        'numbered',
        'list',
        '번호',
      ], () => turnInto('numbered_list')),
      SlashMenuItem('To-do List', Icons.check_box_outlined, [
        'todo',
        'checkbox',
        '체크',
        '할일',
      ], () => turnInto('todo_list')),
      SlashMenuItem('Quote', Icons.format_quote, [
        'quote',
        '인용',
      ], () => turnInto('quote')),
      SlashMenuItem(
        'Divider',
        Icons.horizontal_rule,
        ['divider', 'line', '구분선'],
        () => _c.insertBlocks([EditorBlock.divider()]),
      ),
      SlashMenuItem('Embed Video', Icons.smart_display, [
        'embed',
        'video',
        'youtube',
        '동영상',
        '영상',
        '유튜브',
      ], _embedVideo),
      SlashMenuItem('Section', Icons.unfold_less, [
        'section',
        'toggle',
        '접기',
        '섹션',
      ], _c.insertSection),
      ...widget.extraSlashItems,
    ];
  }

  /// 링크를 받아 그 링크만 있는 줄을 넣음 (줄 아래에 유튜브 미리보기가 붙음)
  Future<void> _embedVideo() async {
    final block = _c.activeBlock;
    final url = await showEmbedVideoDialog(context);
    if (!mounted) return;
    if (url == null) {
      if (block != null) _c.refocus(block);
      return;
    }
    final next = EditorBlock(type: 'paragraph'); // 이어서 쓸 줄
    _c.insertBlocks([
      EditorBlock(
        type: 'paragraph',
        delta: [
          {
            'insert': url,
            'attributes': {'href': url},
          },
        ],
      ),
      next,
    ], focusTarget: next);
  }

  List<SlashMenuItem> get _filteredSlashItems =>
      _slashItems.where((item) => item.matches(_slashQuery)).toList();

  void _updateSlash(EditorBlock block) {
    final controller = block.controller;
    final text = controller.text;
    final caret = controller.selection.baseOffset;

    if (_slashBlock == block) {
      final valid =
          caret > _slashStart &&
          caret <= text.length &&
          _slashStart < text.length &&
          text[_slashStart] == '/' &&
          !text.substring(_slashStart + 1, caret).contains(' ');
      if (!valid) return _closeSlash();
      setState(() {
        _slashQuery = text.substring(_slashStart + 1, caret);
        _slashIndex = 0;
      });
      if (_filteredSlashItems.isEmpty) _closeSlash();
      return;
    }

    // 줄 맨 앞이나 공백 뒤에서 `/`를 치면 메뉴 열기
    if (caret > 0 &&
        caret <= text.length &&
        text[caret - 1] == '/' &&
        (caret == 1 || text[caret - 2] == ' ')) {
      setState(() {
        _slashBlock = block;
        _slashStart = caret - 1;
        _slashQuery = '';
        _slashIndex = 0;
      });
      _slashPortal.show();
    }
  }

  void _closeSlash() {
    if (_slashBlock == null) return;
    _slashPortal.hide();
    if (mounted) setState(() => _slashBlock = null);
  }

  void _runSlashItem(SlashMenuItem item) {
    final block = _slashBlock;
    if (block == null) return;
    final controller = block.controller;
    final caret = controller.selection.baseOffset.clamp(
      _slashStart,
      controller.text.length,
    );
    // `/검색어` 지우기
    controller
        .setContent(controller.text.replaceRange(_slashStart, caret, ''), [
          ...controller.marks.sublist(0, _slashStart),
          ...controller.marks.sublist(caret),
        ], _slashStart);
    _closeSlash();
    item.onSelect();
    _c.textChanged();
  }

  Widget _buildSlashMenu(BuildContext context) {
    final items = _filteredSlashItems;
    final block = _slashBlock;
    if (block == null || items.isEmpty) return const SizedBox.shrink();
    return CompositedTransformFollower(
      link: block.layerLink,
      targetAnchor: Alignment.bottomLeft,
      offset: const Offset(0, 4),
      child: Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          color: context.popupSurface,
          borderRadius: BorderRadius.circular(6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240, maxHeight: 320),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final selected = i == _slashIndex;
                return InkWell(
                  onTap: () => _runSlashItem(item),
                  child: Container(
                    color: selected
                        ? context.accent.withValues(alpha: 0.15)
                        : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          size: 18,
                          color: context.isDark
                              ? Colors.grey[400]
                              : Colors.grey[700],
                        ),
                        const SizedBox(width: 10),
                        Text(item.name, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ───────────── 텍스트 변경: 줄바꿈 → 블록 나누기, 마크다운 단축 입력

  void _onTextChanged(EditorBlock block) {
    _updateSlash(block);
    final controller = block.controller;
    if (controller.value.composing.isValid) {
      _c.textChanged();
      return; // 한글 조합 중에는 구조를 바꾸지 않음
    }
    // 웹 주소를 치고 띄어쓰기·Enter를 누르면 링크로
    final text = controller.text;
    final caret = controller.selection.baseOffset;
    if (caret >= 2 &&
        caret <= text.length &&
        _whitespace.hasMatch(text[caret - 1])) {
      final wordStart = text.lastIndexOf(_whitespace, caret - 2) + 1;
      controller.linkify(wordStart, caret - 1);
    }
    if (text.contains('\n')) {
      _closeSlash();
      _split(block);
    } else if (block.type == 'paragraph') {
      _applyMarkdownShortcut(block);
    }
    _c.textChanged();
  }

  static final _whitespace = RegExp(r'\s');

  /// Enter(또는 여러 줄 붙여넣기)로 생긴 줄바꿈마다 블록을 나눔
  void _split(EditorBlock block) {
    final controller = block.controller;
    final text = controller.text;
    final marks = controller.marks;
    final caret = controller.selection.baseOffset;
    final lines = text.split('\n');

    // 빈 목록 항목에서 Enter → 목록 끝내기 (일반 문단으로)
    if (text == '\n' && continuingBlockTypes.contains(block.type)) {
      block.changeType('paragraph');
      controller.setContent('', const [], 0);
      _c.contentChanged();
      return;
    }

    final newType = continuingBlockTypes.contains(block.type)
        ? block.type
        : 'paragraph';
    // 섹션 제목에서 Enter → 섹션 안 첫 줄로
    final newDepth = block.isSection ? block.depth + 1 : block.depth;
    final index = _blocks.indexOf(block);
    var start = 0;
    EditorBlock? caretBlock;
    var caretOffset = 0;
    final created = <EditorBlock>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineMarks = marks.sublist(start, start + line.length);
      final EditorBlock target;
      if (i == 0) {
        target = block;
      } else {
        target = _c.register(
          EditorBlock(type: newType, depth: newDepth)..changeType(newType),
        );
        if (block.align != null) target.data['align'] = block.align;
        created.add(target);
      }
      if (caret >= start && caret <= start + line.length) {
        caretBlock = target;
        caretOffset = caret - start;
      }
      target.controller.setContent(line, lineMarks, 0);
      start += line.length + 1; // '\n'
    }

    if (block.isSection && block.collapsed) block.data['collapsed'] = false;
    _blocks.insertAll(index + 1, created);
    _c.contentChanged();
    _c.focus(caretBlock ?? created.last, caretOffset);
  }

  static final _shortcuts = <RegExp, void Function(EditorBlock)>{
    RegExp(r'^\[ ?\] '): (b) => b.changeType('todo_list'),
    RegExp(r'^[-*] '): (b) => b.changeType('bulleted_list'),
    RegExp(r'^1\. '): (b) => b.changeType('numbered_list'),
    RegExp(r'^> '): (b) => b.changeType('quote'),
    RegExp(r'^### '): (b) => b.changeType('heading', level: 3),
    RegExp(r'^## '): (b) => b.changeType('heading', level: 2),
    RegExp(r'^# '): (b) => b.changeType('heading', level: 1),
  };

  /// 줄 맨 앞에 `[] `, `- `, `1. `, `# ` 등을 치면 블록 종류로 바꿈
  void _applyMarkdownShortcut(EditorBlock block) {
    final controller = block.controller;
    final caret = controller.selection.baseOffset;
    for (final entry in _shortcuts.entries) {
      final match = entry.key.firstMatch(controller.text);
      if (match == null || match.end != caret) continue;
      entry.value(block);
      controller.setContent(
        controller.text.substring(match.end),
        controller.marks.sublist(match.end),
        0,
      );
      _c.contentChanged();
      return;
    }
  }

  /// 붙여넣기: 이미지 → 내부 복사본(서식 유지) → 일반 글자 순
  Future<void> _paste(EditorBlock block) async {
    if (await widget.onPaste?.call() ?? false) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (_c.pasteInternal(data?.text)) return;
    final text = data?.text?.replaceAll('\r\n', '\n');
    if (text == null || text.isEmpty) return;
    if (_c.selection != null) _c.deleteSelection();
    final target = _c.activeBlock ?? block;
    if (!_blocks.contains(target) || !target.isText) return;
    final controller = target.controller;
    final start = controller.selection.isValid
        ? controller.selection.start
        : controller.text.length;
    controller.insertText(text);
    controller.linkify(start, start + text.length); // 붙여넣은 주소는 링크로
    _onTextChanged(target);
  }

  void _cut() {
    if (!_c.copySelection()) return;
    if (_c.selection != null) {
      _c.deleteSelection();
    } else {
      final block = _c.activeBlock;
      if (block == null) return;
      block.controller.insertText('');
      _c.textChanged();
    }
  }

  // 글자를 입력하지 않는 키 (여러 줄 선택 중에 눌러도 선택을 지우지 않음)
  static final _modifierKeys = {
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  };

  static final _nonTypingKeys = {
    ..._modifierKeys,
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.escape,
    LogicalKeyboardKey.tab,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.home,
    LogicalKeyboardKey.end,
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.insert,
    LogicalKeyboardKey.contextMenu,
    LogicalKeyboardKey.lang1, // 한/영
    LogicalKeyboardKey.lang2, // 한자
    LogicalKeyboardKey.hangulMode,
    LogicalKeyboardKey.hanjaMode,
    LogicalKeyboardKey.f1,
    LogicalKeyboardKey.f2,
    LogicalKeyboardKey.f3,
    LogicalKeyboardKey.f4,
    LogicalKeyboardKey.f5,
    LogicalKeyboardKey.f6,
    LogicalKeyboardKey.f7,
    LogicalKeyboardKey.f8,
    LogicalKeyboardKey.f9,
    LogicalKeyboardKey.f10,
    LogicalKeyboardKey.f11,
    LogicalKeyboardKey.f12,
  };

  /// 다음(이전) 보이는 텍스트 블록
  EditorBlock? _neighborText(EditorBlock block, int direction) {
    var i = _blocks.indexOf(block) + direction;
    while (i >= 0 &&
        i < _blocks.length &&
        (!_blocks[i].isText || _c.isHidden(i))) {
      i += direction;
    }
    return i < 0 || i >= _blocks.length ? null : _blocks[i];
  }

  /// Shift+방향키로 선택을 다른 줄까지 넓힘. 넓혔으면 true.
  bool _extendSelection(EditorBlock block, LogicalKeyboardKey key) {
    final sel = block.controller.selection;
    final current = _c.selection;
    final baseBlock = current?.baseBlock ?? block;
    final baseOffset = current?.baseOffset ?? sel.baseOffset;
    var extentBlock = current?.extentBlock ?? block;
    var extentOffset = current?.extentOffset ?? sel.extentOffset;
    final extentLength = extentBlock.isText
        ? extentBlock.controller.text.length
        : 1;

    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final down = key == LogicalKeyboardKey.arrowDown;
      // 한 줄 안에서는 입력창이 처리 (줄의 첫/마지막 줄에서만 넘어감)
      if (current == null && !_caretOnEdgeLine(block, !down, extent: true)) {
        return false;
      }
      final next = _neighborText(extentBlock, down ? 1 : -1);
      if (next == null) return false;
      extentBlock = next;
      extentOffset = down ? next.controller.text.length : 0;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (current == null && extentOffset < extentLength) return false;
      if (extentOffset < extentLength) {
        extentOffset++;
      } else {
        final next = _neighborText(extentBlock, 1);
        if (next == null) return false;
        extentBlock = next;
        extentOffset = 0;
      }
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      if (current == null && extentOffset > 0) return false;
      if (extentOffset > 0) {
        extentOffset--;
      } else {
        final previous = _neighborText(extentBlock, -1);
        if (previous == null) return false;
        extentBlock = previous;
        extentOffset = previous.controller.text.length;
      }
    } else {
      return false;
    }
    _c.setSelection(
      BlockSelection(baseBlock, baseOffset, extentBlock, extentOffset),
    );
    return true;
  }

  /// 여러 줄 선택 중의 키 처리. 처리하지 않으면 null.
  KeyEventResult? _onKeyWithSelection(EditorBlock block, KeyEvent event) {
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final ctrl = keyboard.isControlPressed;
    final shift = keyboard.isShiftPressed;
    KeyEventResult done(VoidCallback action) {
      action();
      return KeyEventResult.handled;
    }

    if (ctrl) {
      return switch (key) {
        LogicalKeyboardKey.keyC => done(_c.copySelection),
        LogicalKeyboardKey.keyX => done(_cut),
        LogicalKeyboardKey.keyA => done(_c.selectAll),
        // 선택한 줄의 체크박스 전부
        LogicalKeyboardKey.enter ||
        LogicalKeyboardKey.numpadEnter => done(_c.toggleTodosInSelection),
        LogicalKeyboardKey.home || LogicalKeyboardKey.end => null,
        LogicalKeyboardKey.keyZ ||
        LogicalKeyboardKey.keyY => null, // 아래 공통 처리 (실행 취소)
        _ => null, // 서식 단축키 등은 선택 전체에 적용
      };
    }
    if (key == LogicalKeyboardKey.escape) return done(_c.clearSelection);
    if (key == LogicalKeyboardKey.tab) {
      // 선택한 줄 전부 들여쓰기 / 내어쓰기
      return done(
        () => _c.indentBlocks([
          for (final (b, _, _) in _c.selectedParts) b,
        ], outdent: shift),
      );
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      return done(_c.deleteSelection);
    }
    if (shift && _extendSelection(block, key)) return KeyEventResult.handled;
    // Shift 등 보조키만 누른 것은 선택 유지 (Shift+Tab 등)
    if (_modifierKeys.contains(key)) return KeyEventResult.ignored;
    if (_nonTypingKeys.contains(key)) {
      // 방향키 등: 선택 해제 후 입력창 기본 동작
      _c.clearSelection();
      return KeyEventResult.ignored;
    }
    // 글자 입력(한글 조합 포함)·Enter: 선택을 지운 뒤 그 자리에 입력되도록
    // 포커스 있는 줄을 남기므로 입력창이 이어서 글자를 넣음
    if (!keyboard.isAltPressed) _c.deleteSelection();
    return KeyEventResult.ignored;
  }

  // ───────────── 키 입력

  KeyEventResult _onKey(EditorBlock block, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final controller = block.controller;
    // 한글 조합 중인 키는 전부 기본 입력창(IME)에 맡김
    if (controller.value.composing.isValid) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final ctrl = keyboard.isControlPressed;
    final shift = keyboard.isShiftPressed;
    final alt = keyboard.isAltPressed;
    final sel = controller.selection;
    final atStart = sel.isCollapsed && sel.start == 0;
    final atEnd = sel.isCollapsed && sel.end == controller.text.length;

    KeyEventResult done(VoidCallback action) {
      action();
      return KeyEventResult.handled;
    }

    // `/` 메뉴가 열려 있으면 방향키·Enter·Esc는 메뉴용
    if (_slashBlock == block) {
      final items = _filteredSlashItems;
      if (key == LogicalKeyboardKey.escape) return done(_closeSlash);
      if (items.isNotEmpty) {
        if (key == LogicalKeyboardKey.arrowDown) {
          return done(
            () =>
                setState(() => _slashIndex = (_slashIndex + 1) % items.length),
          );
        }
        if (key == LogicalKeyboardKey.arrowUp) {
          return done(
            () => setState(
              () =>
                  _slashIndex = (_slashIndex - 1 + items.length) % items.length,
            ),
          );
        }
        if (key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) {
          return done(
            () => _runSlashItem(items[_slashIndex.clamp(0, items.length - 1)]),
          );
        }
      }
    }

    // 여러 줄 선택 중: 복사·삭제·입력 등은 선택 전체에
    if (_c.selection != null) {
      final result = _onKeyWithSelection(block, event);
      if (result != null) return result;
    }

    // Alt+1~8 글자색, Alt+Shift+1~8 형광펜, Alt+↑/↓ 블록 이동
    if (alt && !ctrl) {
      final digit = _digitOf(key);
      if (digit != null && digit >= 1 && digit <= 8) {
        return done(
          () => shift
              ? _c.toggleColor('bg_color', editorHighlightColors[digit - 1])
              : _c.toggleColor('font_color', editorTextColors[digit - 1]),
        );
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        return done(() => _c.moveBlock(block, -1));
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        return done(() => _c.moveBlock(block, 1));
      }
      return KeyEventResult.ignored;
    }

    if (ctrl && shift) {
      return switch (key) {
        LogicalKeyboardKey.keyZ => done(_c.redo),
        LogicalKeyboardKey.keyX => done(() => _c.toggleMark('strikethrough')),
        LogicalKeyboardKey.keyH => done(
          () => _c.insertBlocks([EditorBlock.divider()]),
        ),
        LogicalKeyboardKey.keyC => done(
          () => _c.insertBlocks([EditorBlock.code()]),
        ),
        LogicalKeyboardKey.keyL => done(() => _c.setAlign('left')),
        LogicalKeyboardKey.keyR => done(() => _c.setAlign('right')),
        LogicalKeyboardKey.keyV => done(() => _paste(block)),
        _ => KeyEventResult.ignored,
      };
    }

    if (ctrl) {
      final digit = _digitOf(key);
      if (digit != null) {
        final VoidCallback? action = switch (digit) {
          1 || 2 || 3 => () => _c.toggleBlockType('heading', level: digit),
          4 => () => _c.toggleBlockType('bulleted_list'),
          5 => () => _c.toggleBlockType('numbered_list'),
          6 => () => _c.toggleBlockType('todo_list'),
          _ => null,
        };
        if (action != null) return done(action);
      }
      return switch (key) {
        // 실행 취소: 줄 나누기·합치기까지 문서 전체 기준
        LogicalKeyboardKey.keyZ => done(_c.undo),
        LogicalKeyboardKey.keyY => done(_c.redo),
        // 문서 처음·끝
        LogicalKeyboardKey.home => done(() => _jumpToEdge(start: true)),
        LogicalKeyboardKey.end => done(() => _jumpToEdge(start: false)),
        // 복사·잘라내기: 서식 유지 (복사할 게 없으면 기본 동작)
        LogicalKeyboardKey.keyC =>
          _c.copySelection() ? KeyEventResult.handled : KeyEventResult.ignored,
        LogicalKeyboardKey.keyX when !sel.isCollapsed => done(_cut),
        // 줄 전체가 이미 선택되어 있으면 문서 전체 선택
        LogicalKeyboardKey.keyA
            when controller.text.isEmpty ||
                (sel.start == 0 && sel.end == controller.text.length) =>
          done(_c.selectAll),
        LogicalKeyboardKey.keyB => done(() => _c.toggleMark('bold')),
        LogicalKeyboardKey.keyI => done(() => _c.toggleMark('italic')),
        LogicalKeyboardKey.keyU => done(() => _c.toggleMark('underline')),
        LogicalKeyboardKey.keyV => done(() => _paste(block)),
        LogicalKeyboardKey.keyF => done(() => widget.onFind?.call(false)),
        LogicalKeyboardKey.keyH => done(() => widget.onFind?.call(true)),
        LogicalKeyboardKey.enter when block.type == 'todo_list' => done(
          () => _c.toggleTodo(block),
        ),
        _ => KeyEventResult.ignored,
      };
    }

    if (key == LogicalKeyboardKey.pageUp) return done(() => _page(block, -1));
    if (key == LogicalKeyboardKey.pageDown) return done(() => _page(block, 1));
    if (key == LogicalKeyboardKey.tab) {
      return done(() => shift ? _outdent(block) : _indent(block));
    }
    if (key == LogicalKeyboardKey.backspace && atStart) {
      return done(() => _backspaceAtStart(block));
    }
    if (key == LogicalKeyboardKey.delete && atEnd) {
      return done(() => _deleteAtEnd(block));
    }
    if (shift) {
      // Shift+방향키가 줄 끝에 닿으면 다음 줄까지 선택
      return _extendSelection(block, key)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowUp && _caretOnEdgeLine(block, true)) {
      return _moveTo(block, -1, toEnd: true);
    }
    if (key == LogicalKeyboardKey.arrowDown && _caretOnEdgeLine(block, false)) {
      return _moveTo(block, 1, toEnd: false);
    }
    if (key == LogicalKeyboardKey.arrowLeft && atStart) {
      return _moveTo(block, -1, toEnd: true);
    }
    if (key == LogicalKeyboardKey.arrowRight && atEnd) {
      return _moveTo(block, 1, toEnd: false);
    }
    return KeyEventResult.ignored;
  }

  static int? _digitOf(LogicalKeyboardKey key) {
    const digits = [
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    final index = digits.indexOf(key);
    return index < 0 ? null : index;
  }

  /// 이웃한 텍스트 블록으로 커서 이동 (텍스트가 아닌 블록·접힌 내용은 건너뜀)
  KeyEventResult _moveTo(
    EditorBlock block,
    int direction, {
    required bool toEnd,
  }) {
    var i = _blocks.indexOf(block) + direction;
    while (i >= 0 &&
        i < _blocks.length &&
        (!_blocks[i].isText || _c.isHidden(i))) {
      i += direction;
    }
    if (i < 0 || i >= _blocks.length) return KeyEventResult.ignored;
    final target = _blocks[i];
    _c.focus(target, toEnd ? target.controller.text.length : 0);
    return KeyEventResult.handled;
  }

  /// 커서가 블록의 첫 줄(또는 마지막 줄)에 있는지. 한 블록도 화면에서는 여러 줄로 감길 수 있음.
  /// [extent]: 선택 중이면 움직이는 쪽(extent) 기준으로 판정
  bool _caretOnEdgeLine(EditorBlock block, bool first, {bool extent = false}) {
    final controller = block.controller;
    if (!extent && !controller.selection.isCollapsed) return false;
    if (block.width <= 0) return true;
    final painter = TextPainter(
      text: controller.buildTextSpan(
        context: context,
        style: _effectiveStyle(block),
        withComposing: false,
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: block.width - 3); // 커서 폭만큼 여유
    final caret = painter.getOffsetForCaret(
      TextPosition(offset: controller.selection.extentOffset),
      Rect.zero,
    );
    final lines = painter.computeLineMetrics();
    final height = painter.height;
    painter.dispose();
    if (lines.length <= 1) return true;
    return first
        ? caret.dy < lines.first.height / 2
        : caret.dy > height - lines.last.height * 1.5;
  }

  void _indent(EditorBlock block) => _c.indentBlocks([block], outdent: false);

  void _outdent(EditorBlock block) => _c.indentBlocks([block], outdent: true);

  Future<void> _deleteObject(EditorBlock block) async {
    if (block.type != dividerType &&
        !await confirmBlockDelete(context, block)) {
      return;
    }
    _c.removeBlock(block);
  }

  /// 줄 맨 앞에서 Backspace: 목록 해제 → 내어쓰기 → 윗줄과 합치기 순
  void _backspaceAtStart(EditorBlock block) {
    if (block.isSection) {
      // 빈 섹션 제목에서 Backspace → 섹션을 일반 줄로
      if (block.controller.text.isEmpty) {
        block.changeType('paragraph');
        _c.contentChanged();
      }
      return;
    }
    if (block.type != 'paragraph') {
      block.changeType('paragraph');
      _c.contentChanged();
      return;
    }
    final index = _blocks.indexOf(block);
    final previous = index > 0 ? _blocks[index - 1] : null;
    // 첫 자식 줄이면 내어쓰기 (단, 섹션의 첫 줄은 섹션 안에 남김)
    if (block.depth > 0 &&
        (previous == null || previous.depth < block.depth) &&
        !(previous?.isSection ?? false)) {
      _outdent(block);
      return;
    }
    if (previous == null) return;
    if (!previous.isText) {
      _deleteObject(previous);
      return;
    }
    if (_c.isHidden(index - 1) || previous.isSection) {
      _moveTo(block, -1, toEnd: true);
      return;
    }
    _mergeInto(previous, block);
  }

  /// 줄 맨 끝에서 Delete: 아랫줄을 끌어올림
  void _deleteAtEnd(EditorBlock block) {
    final index = _blocks.indexOf(block);
    if (index + 1 >= _blocks.length) return;
    final next = _blocks[index + 1];
    if (!next.isText) {
      _deleteObject(next);
      return;
    }
    if (next.isSection || _c.isHidden(index + 1)) return;
    _mergeInto(block, next);
  }

  /// [source]의 내용을 [target] 끝에 붙이고 [source]를 지움 (하위 블록은 한 단계 올림)
  void _mergeInto(EditorBlock target, EditorBlock source) {
    final joinAt = target.controller.text.length;
    target.controller.setContent(
      target.controller.text + source.controller.text,
      [...target.controller.marks, ...source.controller.marks],
      joinAt,
    );
    final index = _blocks.indexOf(source);
    final end = _c.subtreeEnd(index);
    for (var i = index + 1; i < end; i++) {
      _blocks[i].depth--;
    }
    _blocks.removeAt(index);
    WidgetsBinding.instance.addPostFrameCallback((_) => source.dispose());
    _c.contentChanged();
    _c.focus(target, joinAt);
  }

  // ───────────── 화면

  TextStyle _baseStyle(EditorBlock block) {
    // 다크 모드에서는 흰 글씨
    var style = TextStyle(
      fontSize: 16,
      color: context.isDark ? darkText : Colors.black,
    );
    if (block.type == 'heading') {
      // 기존 에디터와 같은 크기 (1: 28, 2: 24, 3: 18)
      style = style.copyWith(
        fontSize: const {1: 28.0, 2: 24.0}[block.level] ?? 18.0,
        fontWeight: FontWeight.bold,
      );
    }
    if (block.isSection) style = style.copyWith(fontWeight: FontWeight.w600);
    if (block.type == 'todo_list' && block.checked) {
      style = style.copyWith(
        decoration: TextDecoration.lineThrough,
        color: Colors.grey.shade400,
      );
    }
    return style;
  }

  /// 입력창이 실제로 쓰는 스타일 (테마 기본값과 합친 것)
  TextStyle _effectiveStyle(EditorBlock block) =>
      Theme.of(context).textTheme.titleMedium!.merge(_baseStyle(block));

  Widget? _leading(EditorBlock block, int index) {
    const bullets = ['●', '◯', '□'];
    final style = _baseStyle(block);
    Widget box(Widget child) => Container(
      constraints: const BoxConstraints(minWidth: 26, minHeight: 22),
      padding: const EdgeInsets.only(right: 4),
      child: child,
    );
    return switch (block.type) {
      'todo_list' => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _c.toggleTodo(block),
          child: box(
            Icon(
              block.checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: block.checked ? _todoColor : Colors.grey.shade600,
            ),
          ),
        ),
      ),
      'bulleted_list' => box(
        Center(
          child: Text(
            bullets[block.depth % bullets.length],
            style: style,
            textScaler: const TextScaler.linear(0.5),
          ),
        ),
      ),
      'numbered_list' => box(
        Center(child: Text('${_numbers[block] ?? 1}.', style: style)),
      ),
      _ => null,
    };
  }

  TextAlign _textAlign(EditorBlock block) => switch (block.align) {
    'center' => TextAlign.center,
    'right' => TextAlign.right,
    _ => TextAlign.left,
  };

  /// 입력창. 감싸는 위젯 구조가 바뀌면 입력창이 새로 만들어져 포커스·한글 입력이
  /// 끊기므로, 블록 종류와 상관없이 항상 같은 구조로 감쌈.
  Widget _textField(EditorBlock block, {String? hint}) {
    final quote = block.type == 'quote';
    return Container(
      // 인용: 왼쪽 막대 (기존 에디터의 인용 모양)
      padding: EdgeInsets.only(left: quote ? 8 : 0),
      decoration: BoxDecoration(
        border: quote
            ? const Border(left: BorderSide(color: _todoColor, width: 4))
            : null,
      ),
      child: CompositedTransformTarget(
        link: block.layerLink, // `/` 메뉴 위치
        child: LayoutBuilder(
          builder: (context, constraints) {
            block.width = constraints.maxWidth;
            return TextField(
              controller: block.controller,
              focusNode: block.focusNode,
              maxLines: null,
              style: _baseStyle(block),
              textAlign: _textAlign(block),
              cursorColor: _cursorColor,
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey[400]),
              ),
              onChanged: (_) => _onTextChanged(block),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextBlock(int index) {
    final block = _blocks[index];
    final leading = _leading(block, index);
    final field = _textField(block);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ?leading,
              Expanded(child: field),
            ],
          ),
          // 유튜브 링크가 있으면 미리보기 (없으면 빈 칸)
          YoutubePreview(controller: block.controller),
        ],
      ),
    );
  }

  Widget _buildObjectBlock(EditorBlock block) {
    void delete() => _deleteObject(block);
    return switch (block.type) {
      dividerType => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Divider(height: 16, thickness: 1, color: Color(0xFFAAAAAA)),
      ),
      localImageType => ImageBlockView(
        block: block,
        onChanged: _c.textChanged,
        onDelete: delete,
        onCut: () {
          Clipboard.setData(
            ClipboardData(text: block.rawData['src'] as String? ?? ''),
          );
          _c.removeBlock(block);
        },
      ),
      localFileType => FileBlockView(block: block, onDelete: delete),
      localLocationType => LocationBlockView(block: block, onDelete: delete),
      localCodeType => CodeBlockView(
        block: block,
        onChanged: _c.textChanged,
        onDelete: delete,
        startEditing: (block.rawData['code'] as String? ?? '').isEmpty,
      ),
      _ => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '지원하지 않는 블록: ${block.type} (내용은 보존됨)',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ),
    };
  }

  /// 다크 모드에서는 밝은 섹션 색을 옅게 깔아 흰 글씨가 보이게 함
  Color _sectionBackground(EditorBlock section) {
    final color = _sectionColor(section.data['backgroundColor'] as String?);
    return context.isDark ? color.withValues(alpha: 0.2) : color;
  }

  static Color _sectionColor(String? hex) {
    if (hex == null || hex == 'transparent') return Colors.transparent;
    return Color(int.tryParse(hex.replaceFirst('#', '0xFF')) ?? 0x00000000);
  }

  Future<void> _showSectionMenu(
    BuildContext context,
    EditorBlock section,
  ) async {
    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final position = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + box.size.height,
      offset.dx + box.size.width,
      offset.dy,
    );
    final action = await showMenu<String>(
      context: context,
      position: position,
      items: const [
        PopupMenuItem(
          value: 'color',
          child: Row(
            children: [
              Icon(Icons.palette, size: 16),
              SizedBox(width: 8),
              Text('색상 변경'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('삭제', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
    if (action == 'delete') return _c.removeBlock(section);
    if (action != 'color' || !context.mounted) return;

    const colors = [
      (Color(0xFFFFCDD2), '빨강', '#FFCDD2'),
      (Color(0xFFFFE0B2), '주황', '#FFE0B2'),
      (Color(0xFFFFF9C4), '노랑', '#FFF9C4'),
      (Color(0xFFC8E6C9), '초록', '#C8E6C9'),
      (Color(0xFFBBDEFB), '파랑', '#BBDEFB'),
      (Color(0xFFE1BEE7), '보라', '#E1BEE7'),
    ];
    final color = await showMenu<String>(
      context: context,
      position: position,
      items: [
        for (final (color, label, hex) in colors)
          PopupMenuItem<String>(
            value: hex,
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
                const SizedBox(width: 8),
                Text(label),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'transparent',
          child: Row(
            children: [
              Icon(Icons.format_color_reset, size: 16),
              SizedBox(width: 8),
              Text('배경색 해제'),
            ],
          ),
        ),
      ],
    );
    if (color == null) return;
    section.data['backgroundColor'] = color;
    _c.contentChanged();
  }

  /// 접기 섹션: 제목 + (펼쳐져 있으면) 하위 블록을 테두리 상자 안에
  Widget _buildSection(int index, int end) {
    final section = _blocks[index];
    final title = _textField(section, hint: '섹션 제목');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: _sectionBackground(section),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _c.toggleCollapsed(section),
                    child: Icon(
                      section.collapsed
                          ? Icons.arrow_right
                          : Icons.arrow_drop_down,
                      size: 20,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: title),
                  Builder(
                    builder: (ctx) => GestureDetector(
                      onTap: () => _showSectionMenu(ctx, section),
                      child: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!section.collapsed) ...[
              Divider(height: 1, color: context.lineSubtle),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _buildRange(index + 1, end, section.depth + 1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 블록별로 마지막에 만든 줄 위젯과 그때의 모양 정보.
  /// 모양 정보가 같으면 같은 위젯 객체를 다시 써서 Flutter가 그 줄을 다시 만들지 않음
  /// (긴 메모에서 한 줄이 바뀔 때 전체를 다시 만들지 않도록).
  final _rowCache = Expando<(Object, Widget)>();

  // 한 번 그릴 때마다 미리 계산 (줄마다 다시 계산하면 줄 수의 제곱만큼 느려짐)
  Map<EditorBlock, int> _numbers = const {};
  Set<EditorBlock> _selectedRows = const {};

  void _prepareBuild() {
    final numbers = <EditorBlock, int>{};
    final counters = <int, int>{}; // depth → 현재 번호
    for (final block in _blocks) {
      counters.removeWhere((depth, _) => depth > block.depth);
      if (block.type == 'numbered_list') {
        numbers[block] = counters[block.depth] =
            (counters[block.depth] ?? 0) + 1;
      } else {
        counters.remove(block.depth);
      }
    }
    _numbers = numbers;
    _selectedRows = _c.selectedRows;

    // 목록의 한 항목 = 섹션 밖의 줄 하나, 또는 섹션 하나(하위 블록 포함)
    final items = <int>[];
    final itemOf = <EditorBlock, int>{};
    var i = 0;
    while (i < _blocks.length) {
      itemOf[_blocks[i]] = items.length;
      items.add(i);
      i = _blocks[i].isSection ? _c.subtreeEnd(i) : i + 1;
    }
    _items = items;
    _itemOf = itemOf;
  }

  List<int> _items = const [];
  Map<EditorBlock, int> _itemOf = const {};

  Widget _buildItem(int item) {
    final start = _items[item];
    final end = item + 1 < _items.length ? _items[item + 1] : _blocks.length;
    return _buildRange(start, end, 0).single;
  }

  /// [start, end) 범위의 블록을 그림. 섹션은 자기 하위 범위를 상자 안에 그림.
  List<Widget> _buildRange(int start, int end, int baseDepth) {
    final widgets = <Widget>[];
    var i = start;
    while (i < end) {
      final block = _blocks[i];
      final indent = (block.depth - baseDepth).clamp(0, 20) * _indentWidth;
      final selected = _selectedRows.contains(block);
      var next = i + 1;

      if (block.isSection) {
        next = _c.subtreeEnd(i);
      } else {
        // 섹션이 아닌 줄은 모양이 그대로면 이전 위젯 재사용
        final signature = (
          block.type,
          indent,
          block.level,
          block.checked,
          block.align,
          _numbers[block],
          selected,
        );
        final cached = _rowCache[block];
        if (cached != null && cached.$1 == signature) {
          widgets.add(cached.$2);
          i = next;
          continue;
        }
        final row = _row(
          block,
          indent,
          selected,
          block.isText ? _buildTextBlock(i) : _buildObjectBlock(block),
        );
        _rowCache[block] = (signature, row);
        widgets.add(row);
        i = next;
        continue;
      }
      widgets.add(_row(block, indent, selected, _buildSection(i, next)));
      i = next;
    }
    return widgets;
  }

  Widget _row(EditorBlock block, double indent, bool selected, Widget content) {
    return RepaintBoundary(
      // 위치 찾기(_reveal)·목록에서 줄이 옮겨져도 같은 위젯으로 인식
      key: GlobalObjectKey(block),
      // 줄마다 따로 칠함: 한 줄 입력 시 다른 줄을 다시 칠하지 않음
      child: Padding(
        padding: EdgeInsets.only(left: indent),
        // 선택 여부와 상관없이 같은 구조 (입력창이 새로 만들어지지 않도록)
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? const Color(0x3300B0FF) : null,
          ),
          child: content,
        ),
      ),
    );
  }

  // ───────────── 마우스로 여러 줄 선택
  // 드래그는 시작한 줄의 입력창이 처리하고(그 줄 안의 선택), 포인터가 다른 줄로
  // 넘어가면 여기서 여러 줄 선택으로 넓힘.

  EditorBlock? _dragBase;

  /// 링크 위에서 누른 곳 (떼면 그 링크를 엶)
  (String, Offset)? _linkDown;
  int _dragBaseOffset = 0;

  RenderEditable? _renderEditableOf(EditorBlock block) {
    if (!block.isOnScreen) return null;
    final context = block.focusNode.context!;
    RenderEditable? found;
    void visit(Element element) {
      if (found != null) return;
      final renderObject = element.renderObject;
      if (renderObject is RenderEditable) {
        found = renderObject;
        return;
      }
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
    return found;
  }

  /// 포인터 높이에 있는(없으면 바로 위의) 보이는 텍스트 블록
  EditorBlock? _textBlockAt(Offset global) {
    EditorBlock? result;
    for (var i = 0; i < _blocks.length; i++) {
      final block = _blocks[i];
      if (!block.isText || _c.isHidden(i)) continue;
      final editable = _renderEditableOf(block);
      if (editable == null || !editable.attached) continue;
      final top = editable.localToGlobal(Offset.zero).dy;
      if (top > global.dy) return result ?? block;
      result = block;
    }
    return result;
  }

  int _offsetAt(EditorBlock block, Offset global) {
    final editable = _renderEditableOf(block);
    if (editable == null) return 0;
    return editable
        .getPositionForPoint(global)
        .offset
        .clamp(0, block.controller.text.length);
  }

  /// 포인터 아래 글자의 링크 주소
  String? _linkAt(EditorBlock block, Offset global) {
    final editable = _renderEditableOf(block);
    if (editable == null ||
        !(editable.localToGlobal(Offset.zero) & editable.size).contains(
          global,
        )) {
      return null;
    }
    final position = editable.getPositionForPoint(global);
    // 글자 경계에서는 어느 쪽 글자를 눌렀는지 affinity로 구분
    final index = position.affinity == TextAffinity.upstream
        ? position.offset - 1
        : position.offset;
    return block.controller.linkAt(index);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons & kPrimaryMouseButton == 0) return;
    final block = _textBlockAt(event.position);
    // 링크 클릭: 끌지 않고 그대로 떼면 열기 (끌면 일반 선택)
    _linkDown = null;
    final href = block == null ? null : _linkAt(block, event.position);
    if (href != null && !HardwareKeyboard.instance.isShiftPressed) {
      _linkDown = (href, event.position);
    }
    final active = _c.activeBlock;
    if (HardwareKeyboard.instance.isShiftPressed &&
        block != null &&
        active != null &&
        block != active) {
      // Shift+클릭: 지금 커서(또는 선택 시작점)부터 클릭한 곳까지
      final current = _c.selection;
      _dragBase = current?.baseBlock ?? active;
      _dragBaseOffset =
          current?.baseOffset ?? active.controller.selection.baseOffset;
      _c.setSelection(
        BlockSelection(
          _dragBase!,
          _dragBaseOffset,
          block,
          _offsetAt(block, event.position),
        ),
      );
      scheduleMicrotask(_c.applySelectionHighlights);
      return;
    }
    _c.clearSelection();
    // 글자 영역 안에서 시작한 드래그만 (블록 손잡이·이미지 크기 조절 등은 제외)
    final editable = block == null ? null : _renderEditableOf(block);
    final inText =
        editable != null &&
        (editable.localToGlobal(Offset.zero) & editable.size)
            .inflate(4)
            .contains(event.position);
    _dragBase = inText ? block : null;
    _dragBaseOffset = inText ? _offsetAt(block!, event.position) : 0;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final link = _linkDown;
    if (link != null && (event.position - link.$2).distance > 4) {
      _linkDown = null;
    }
    final base = _dragBase;
    if (base == null || event.buttons & kPrimaryMouseButton == 0) return;
    final target = _textBlockAt(event.position);
    if (target == null) return;
    if (target == base) {
      // 다시 시작한 줄로 돌아오면 그 줄 안의 선택 (입력창이 처리)
      _c.clearSelection();
      return;
    }
    _c.setSelection(
      BlockSelection(
        base,
        _dragBaseOffset,
        target,
        _offsetAt(target, event.position),
      ),
    );
    // 시작한 줄의 입력창이 이번 이동에서 자기 선택을 바꾼 뒤에 다시 맞춤
    scheduleMicrotask(_c.applySelectionHighlights);
  }

  void _onPointerUp(PointerUpEvent event) {
    final link = _linkDown;
    _linkDown = null;
    if (link != null) openLink(link.$1);
    _dragBase = null;
    if (_c.selection != null) scheduleMicrotask(_c.applySelectionHighlights);
  }

  @override
  Widget build(BuildContext context) {
    _prepareBuild();
    return TextSelectionTheme(
      data: const TextSelectionThemeData(selectionColor: _selectionColor),
      child: OverlayPortal(
        controller: _slashPortal,
        overlayChildBuilder: _buildSlashMenu,
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          // 화면 근처의 줄만 만들고 그림 (긴 메모에서 입력이 느려지지 않도록).
          // 포커스 있는 입력창은 화면 밖으로 나가도 유지됨 (EditableText의 keep-alive).
          child: SuperListView.builder(
            controller: _scroll,
            listController: _list,
            padding: widget.padding,
            cacheExtent: 800,
            addRepaintBoundaries: false, // 줄마다 직접 RepaintBoundary
            itemCount: _items.length + 1,
            findChildIndexCallback: (key) =>
                key is GlobalObjectKey ? _itemOf[key.value] : null,
            itemBuilder: (context, item) {
              if (item < _items.length) return _buildItem(item);
              // 아래 빈 곳을 누르면 마지막 줄 끝으로 (마지막이 텍스트가 아니면 새 줄)
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final last = _blocks.last;
                  if (last.isText && !_c.isHidden(_blocks.length - 1)) {
                    _c.focus(last, last.controller.text.length);
                  } else {
                    _c.insertParagraphAfter(last);
                  }
                },
                child: const SizedBox(height: 240),
              );
            },
          ),
        ),
      ),
    );
  }
}
