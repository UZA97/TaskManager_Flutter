import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import 'block_editor_controller.dart';

/// 찾기/바꾸기 창 (에디터 오른쪽 위)
class FindBar extends StatefulWidget {
  const FindBar({
    super.key,
    required this.controller,
    required this.replaceMode,
    required this.onToggleReplace,
    required this.onClose,
  });

  final BlockEditorController controller;
  final bool replaceMode;
  final VoidCallback onToggleReplace;
  final VoidCallback onClose;

  @override
  State<FindBar> createState() => _FindBarState();
}

class _FindBarState extends State<FindBar> {
  final _findController = TextEditingController();
  final _replaceController = TextEditingController();
  final _findFocus = FocusNode();
  List<FindMatch> _matches = const [];
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // 선택한 글자가 있으면 그걸로 찾기 시작
    final block = widget.controller.activeBlock;
    final sel = block?.controller.selection;
    if (block != null && sel != null && sel.isValid && !sel.isCollapsed) {
      _findController.text = sel.textInside(block.controller.text);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _findFocus.requestFocus();
      _findController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _findController.text.length,
      );
      _search();
    });
  }

  @override
  void dispose() {
    _findController.dispose();
    _replaceController.dispose();
    _findFocus.dispose();
    super.dispose();
  }

  void _search({bool keepIndex = false}) {
    final matches = widget.controller.find(_findController.text);
    setState(() {
      _matches = matches;
      _index = matches.isEmpty
          ? 0
          : (keepIndex ? _index.clamp(0, matches.length - 1) : 0);
    });
    _show();
  }

  void _show() {
    final current = _matches.isEmpty ? null : _matches[_index];
    widget.controller.showFindHighlights(_matches, current);
    // 화면 밖이라 아직 만들어지지 않은 줄이어도 그 위치로 스크롤
    if (current != null) {
      widget.controller.reveal(current.block, alignment: 0.3);
    }
  }

  void _move(int delta) {
    if (_matches.isEmpty) return;
    setState(() => _index = (_index + delta) % _matches.length);
    _show();
  }

  void _replaceOne() {
    if (_matches.isEmpty) return;
    widget.controller.replace(_matches[_index], _replaceController.text);
    _search(keepIndex: true);
  }

  void _replaceAll() {
    // 뒤에서부터 바꿔야 앞쪽 위치가 밀리지 않음
    for (final match in _matches.reversed) {
      widget.controller.replace(match, _replaceController.text);
    }
    _search();
  }

  KeyEventResult _onFindKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _move(HardwareKeyboard.instance.isShiftPressed ? -1 : 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _iconButton(IconData icon, String tooltip, VoidCallback? onPressed) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
      onPressed: onPressed,
    );
  }

  Widget _field(
    TextEditingController controller,
    String hint, {
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
  }) {
    return SizedBox(
      width: 200,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasMatches = _matches.isNotEmpty;
    final count = _findController.text.isEmpty
        ? ''
        : hasMatches
        ? '${_index + 1}/${_matches.length}'
        : '결과 없음';

    return Material(
      elevation: 4,
      color: context.popupSurface,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _iconButton(
                  widget.replaceMode ? Icons.expand_less : Icons.expand_more,
                  '바꾸기',
                  widget.onToggleReplace,
                ),
                Focus(
                  onKeyEvent: _onFindKey,
                  child: _field(
                    _findController,
                    '찾기',
                    focusNode: _findFocus,
                    onChanged: (_) => _search(),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    count,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                _iconButton(
                  Icons.arrow_upward,
                  '이전',
                  hasMatches ? () => _move(-1) : null,
                ),
                _iconButton(
                  Icons.arrow_downward,
                  '다음',
                  hasMatches ? () => _move(1) : null,
                ),
                _iconButton(Icons.close, '닫기', widget.onClose),
              ],
            ),
            if (widget.replaceMode)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 26),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(_replaceController, '바꾸기'),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: hasMatches ? _replaceOne : null,
                      child: const Text('바꾸기'),
                    ),
                    TextButton(
                      onPressed: hasMatches ? _replaceAll : null,
                      child: const Text('모두 바꾸기'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
