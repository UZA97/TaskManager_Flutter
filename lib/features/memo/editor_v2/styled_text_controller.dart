import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'inline_image.dart';

/// 글자 하나의 서식 (appflowy delta의 attributes와 같은 키: bold, italic, font_color ...)
typedef Marks = Map<String, Object?>;

/// 글자마다 서식을 가진 입력 컨트롤러.
///
/// 글자 입력·한글 조합(IME)은 Flutter 기본 입력창이 그대로 처리하고,
/// 이 컨트롤러는 바뀐 텍스트에 맞춰 서식 목록만 따라 맞춤.
class StyledTextController extends TextEditingController {
  StyledTextController._(String text, this._marks) : super(text: text);

  /// appflowy delta(`[{insert, attributes}]`)에서 생성
  factory StyledTextController.fromDelta(List<Map<String, Object?>> delta) {
    final buffer = StringBuffer();
    final marks = <Marks>[];
    for (final op in delta) {
      final insert = op['insert'];
      if (insert is! String) continue;
      final attributes = op['attributes'];
      final mark = attributes is Map
          ? Map<String, Object?>.from(attributes)
          : const <String, Object?>{};
      buffer.write(insert);
      marks.addAll(List.filled(insert.length, mark));
    }
    return StyledTextController._(buffer.toString(), marks);
  }

  List<Marks> _marks;

  /// 이 입력창의 포커스 (줄 안의 그림을 누르면 커서를 놓으려고)
  FocusNode? focusNode;

  /// focusNode가 없을 때 쓰는 공용 노드 (그릴 때마다 새로 만들지 않게)
  static final _noFocus = FocusNode(debugLabel: 'inline object fallback');

  /// 그림 크기 조절·삭제처럼 입력창 밖에서 내용을 바꿨을 때 (저장용)
  VoidCallback? onEdited;

  /// 커서만 있을 때 Ctrl+B 등으로 켠 서식 (다음에 입력하는 글자에 적용)
  Marks? _pending;

  List<Marks> get marks => List.unmodifiable(_marks);

  /// 서식이 바뀔 때마다 늘어남 (서식 기준으로 다시 계산할지 판단용)
  int get marksRevision => _marksRevision;
  int _marksRevision = 0;

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final newText = newValue.text;
    if (oldText != newText) {
      // 앞뒤로 같은 부분을 제외한 가운데가 바뀐 범위
      var start = 0;
      final maxStart = min(oldText.length, newText.length);
      while (start < maxStart &&
          oldText.codeUnitAt(start) == newText.codeUnitAt(start)) {
        start++;
      }
      var end = 0;
      while (end < oldText.length - start &&
          end < newText.length - start &&
          oldText.codeUnitAt(oldText.length - 1 - end) ==
              newText.codeUnitAt(newText.length - 1 - end)) {
        end++;
      }
      final inserted = newText.length - start - end;
      final removed = oldText.length - start - end;
      // 새 글자는 바로 앞 글자의 서식을 이어받음.
      // 글자를 바꿔 넣을 때(한글 조합 ㄱ→가 등)는 바뀌는 글자의 서식을 이어받음
      // (Ctrl+B 후 조합 중인 글자가 굵게 유지되도록)
      var inherit =
          _pending ??
          (removed > 0 && start < _marks.length
              ? _marks[start]
              : start > 0
              ? _marks[start - 1]
              : (_marks.isNotEmpty ? _marks.first : const <String, Object?>{}));
      // 그림 뒤에 친 글자는 그림이 아님
      inherit = _withoutImage(inherit);
      // 링크 끝에 이어 친 글자는 링크가 아님 (링크 가운데에 넣을 때만 이어받음)
      final next = oldText.length - end;
      if (inherit['href'] != null &&
          (next >= _marks.length || _marks[next]['href'] != inherit['href'])) {
        inherit = {...inherit}..remove('href');
      }
      _marksRevision++;
      _marks = [
        ..._marks.sublist(0, start),
        ...List.filled(inserted, inherit),
        ..._marks.sublist(oldText.length - end),
      ];
      if (inserted > 0) _pending = null;
    } else if (newValue.selection != selection) {
      _pending = null;
    }
    super.value = newValue;
  }

  /// 텍스트와 서식을 통째로 바꿈 (블록 나누기·합치기)
  void setContent(String text, List<Marks> marks, int caret) {
    assert(text.length == marks.length);
    _marksRevision++;
    _marks = [...marks];
    _pending = null;
    super.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  /// 선택 범위의 서식을 켜고 끔. 선택이 없으면 다음 입력에 적용.
  void toggleMark(String key) {
    final sel = selection;
    if (!sel.isValid) return;
    if (sel.isCollapsed) {
      final base = _withoutImage(
        _pending ??
            (sel.start > 0 ? _marks[sel.start - 1] : const <String, Object?>{}),
      );
      _pending = _withMark(base, key, base[key] != true);
      return;
    }
    final enable = !_marks
        .sublist(sel.start, sel.end)
        .every((m) => m[key] == true);
    for (var i = sel.start; i < sel.end; i++) {
      _marks[i] = _withMark(_marks[i], key, enable);
    }
    _marksRevision++;
    notifyListeners();
  }

  static Marks _withoutImage(Marks marks) =>
      inlineObjectKeys.any(marks.containsKey)
      ? ({...marks}..removeWhere((key, _) => inlineObjectKeys.contains(key)))
      : marks;

  bool _isObjectChar(int offset) =>
      offset >= 0 && offset < text.length && text[offset] == inlineImageChar;

  /// [offset] 글자가 줄 안의 그림인지
  bool isImageAt(int offset) =>
      _isObjectChar(offset) && _marks[offset][imageMarkKey] is String;

  /// [offset] 글자가 줄 안의 첨부파일인지
  bool isFileAt(int offset) =>
      _isObjectChar(offset) && _marks[offset][fileMarkKey] is String;

  bool _isObjectAt(int offset) => isImageAt(offset) || isFileAt(offset);

  /// 커서 위치에 그림을 넣고 커서를 그 뒤로
  void insertImage(String src) =>
      insertStyled(inlineImageChar, [inlineImageMarks(src)]);

  /// 커서 위치에 첨부파일을 넣고 커서를 그 뒤로
  void insertFile(String src, String fileName) =>
      insertStyled(inlineImageChar, [inlineFileMarks(src, fileName)]);

  /// 그림·파일을 고름 (그 글자 하나를 선택)
  void _selectObject(int offset) {
    value = value.copyWith(
      selection: TextSelection(baseOffset: offset, extentOffset: offset + 1),
      composing: TextRange.empty,
    );
    focusNode?.requestFocus();
  }

  void _resizeImage(int offset, double width) {
    if (!isImageAt(offset)) return;
    _marks[offset] = {..._marks[offset], imageWidthKey: width};
    _marksRevision++;
    notifyListeners();
    onEdited?.call();
  }

  void _deleteObject(int offset) {
    if (!_isObjectAt(offset)) return;
    value = TextEditingValue(
      text: text.replaceRange(offset, offset + 1, ''),
      selection: TextSelection.collapsed(offset: offset),
    );
    onEdited?.call();
  }

  static Marks _withMark(Marks marks, String key, bool on) =>
      on ? {...marks, key: true} : ({...marks}..remove(key));

  /// 선택 범위의 [key] 값을 [value]로. 이미 전부 그 값이면 해제 (글자색·형광펜).
  void toggleMarkValue(String key, Object value) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final clear = _marks
        .sublist(sel.start, sel.end)
        .every((m) => m[key] == value);
    for (var i = sel.start; i < sel.end; i++) {
      _marks[i] = clear
          ? ({..._marks[i]}..remove(key))
          : {..._marks[i], key: value};
    }
    _marksRevision++;
    notifyListeners();
  }

  /// 선택 범위를 [text]로 바꿔 넣고 커서를 그 뒤로 (붙여넣기)
  void insertText(String text) {
    final sel = selection.isValid
        ? selection
        : TextSelection.collapsed(offset: this.text.length);
    value = TextEditingValue(
      text: this.text.replaceRange(sel.start, sel.end, text),
      selection: TextSelection.collapsed(offset: sel.start + text.length),
    );
  }

  /// 선택 범위를 서식 있는 글자로 바꿔 넣음 (내부 복사본 붙여넣기)
  void insertStyled(String text, List<Marks> marks) {
    final sel = selection.isValid
        ? selection
        : TextSelection.collapsed(offset: this.text.length);
    setContent(this.text.replaceRange(sel.start, sel.end, text), [
      ..._marks.sublist(0, sel.start),
      ...marks,
      ..._marks.sublist(sel.end),
    ], sel.start + text.length);
  }

  /// [start, end) 범위가 전부 [key] = [value]인지
  bool rangeHas(String key, Object value, int start, int end) =>
      _marks.sublist(start, end).every((m) => m[key] == value);

  /// [start, end) 범위의 [key]를 [value]로 (null이면 해제)
  void applyMark(String key, Object? value, int start, int end) {
    for (var i = start; i < end; i++) {
      _marks[i] = value == null
          ? ({..._marks[i]}..remove(key))
          : {..._marks[i], key: value};
    }
    _marksRevision++;
    notifyListeners();
  }

  static final _urlPattern = RegExp(r'''(?:https?://|www\.)[^\s<>"']+''');

  /// [start, end) 범위에 걸친 웹 주소에 링크(href)를 걺 (이미 링크인 곳은 그대로)
  void linkify([int start = 0, int? end]) {
    final stop = end ?? text.length;
    var changed = false;
    for (final match in _urlPattern.allMatches(text)) {
      var matchEnd = match.end;
      // 문장 끝 문장부호는 주소에서 제외
      while (matchEnd > match.start &&
          '.,;:!?)]}'.contains(text[matchEnd - 1])) {
        matchEnd--;
      }
      if (matchEnd <= start || match.start >= stop) continue;
      if (_marks.sublist(match.start, matchEnd).any((m) => m['href'] != null)) {
        continue;
      }
      final url = text.substring(match.start, matchEnd);
      final href = url.startsWith('www.') ? 'https://$url' : url;
      for (var i = match.start; i < matchEnd; i++) {
        _marks[i] = {..._marks[i], 'href': href};
      }
      changed = true;
    }
    if (changed) {
      _marksRevision++;
      notifyListeners();
    }
  }

  /// [offset] 글자의 링크 주소
  String? linkAt(int offset) {
    if (offset < 0 || offset >= _marks.length) return null;
    return _marks[offset]['href'] as String?;
  }

  // ───────────── 여러 줄 선택 표시 (포커스가 없는 줄은 입력창이 선택을 그리지 않음)

  TextRange? _selectionHighlight;

  void setSelectionHighlight(TextRange? range) {
    if (range == _selectionHighlight) return;
    _selectionHighlight = range;
    notifyListeners();
  }

  /// appflowy delta로 변환 (같은 서식이 이어지는 글자끼리 묶음).
  /// [start]~[end]를 주면 그 부분만.
  List<Map<String, Object?>> toDelta([int start = 0, int? end]) {
    final stop = end ?? text.length;
    final ops = <Map<String, Object?>>[];
    var i = start;
    while (i < stop) {
      var j = i + 1;
      while (j < stop && mapEquals(_marks[j], _marks[i])) {
        j++;
      }
      ops.add({
        'insert': text.substring(i, j),
        if (_marks[i].isNotEmpty) 'attributes': _marks[i],
      });
      i = j;
    }
    return ops;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    // 조합 중인 글자(IME)는 기본 입력창처럼 밑줄 표시
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    bool inComposing(int i) => i >= composing.start && i < composing.end;
    final overlays = _overlayColors();
    Color? overlayAt(int i) => overlays?[i];

    final children = <InlineSpan>[];
    var i = 0;
    while (i < text.length) {
      if (_isObjectAt(i)) {
        children.add(_objectSpan(i));
        i++;
        continue;
      }
      var j = i + 1;
      while (j < text.length &&
          !_isObjectAt(j) &&
          mapEquals(_marks[j], _marks[i]) &&
          inComposing(j) == inComposing(i) &&
          overlayAt(j) == overlayAt(i)) {
        j++;
      }
      var spanStyle = _styleFor(_marks[i], inComposing(i));
      final overlay = overlayAt(i);
      if (overlay != null) {
        spanStyle = spanStyle.copyWith(backgroundColor: overlay);
      }
      children.add(
        TextSpan(
          text: text.substring(i, j),
          style: spanStyle,
          // 링크 위에서는 손가락 모양 (누르면 열림)
          mouseCursor: _marks[i]['href'] != null
              ? SystemMouseCursors.click
              : MouseCursor.defer,
        ),
      );
      i = j;
    }
    return TextSpan(style: style, children: children);
  }

  WidgetSpan _objectSpan(int offset) {
    final marks = _marks[offset];
    final sel = selection;
    final inSelection = sel.isValid && sel.start <= offset && sel.end > offset;
    final highlight = _selectionHighlight;
    final highlighted =
        highlight != null &&
        highlight.start <= offset &&
        highlight.end > offset;
    final focus = focusNode ?? _noFocus;
    return WidgetSpan(
      // 아래쪽을 글자 아래쪽에 맞춤 (옆 글자는 그림 아래쪽에 붙음)
      alignment: PlaceholderAlignment.bottom,
      // 입력창 속 위젯의 접근성 정보는 Windows에서 AXTree 오류 로그를 쏟아냄
      child: ExcludeSemantics(
        child: isImageAt(offset)
            ? InlineImage(
                src: marks[imageMarkKey] as String,
                width:
                    (marks[imageWidthKey] as num?)?.toDouble() ??
                    defaultImageWidth,
                focusNode: focus,
                inSelection: inSelection,
                highlighted: highlighted,
                onSelect: () => _selectObject(offset),
                onResize: (width) => _resizeImage(offset, width),
                onDelete: () => _deleteObject(offset),
              )
            : InlineFile(
                src: marks[fileMarkKey] as String,
                fileName: marks[fileNameKey] as String? ?? '첨부파일',
                focusNode: focus,
                inSelection: inSelection,
                highlighted: highlighted,
                onSelect: () => _selectObject(offset),
                onDelete: () => _deleteObject(offset),
              ),
      ),
    );
  }

  // ───────────── 찾기 강조 표시 (저장되지 않음)

  List<TextRange> _findMatches = const [];
  TextRange? _findCurrent;

  void setFindHighlights(List<TextRange> matches, TextRange? current) {
    if (listEquals(matches, _findMatches) && current == _findCurrent) return;
    _findMatches = matches;
    _findCurrent = current;
    notifyListeners();
  }

  /// 글자별 배경색 (여러 줄 선택 > 현재 찾은 위치 > 찾은 위치 순).
  /// 칠할 것이 없으면 null. 범위마다 한 번씩만 칠해 글자 수에 비례.
  List<Color?>? _overlayColors() {
    if (_selectionHighlight == null &&
        _findCurrent == null &&
        _findMatches.isEmpty) {
      return null;
    }
    final colors = List<Color?>.filled(text.length, null);
    // 낮은 순위부터 칠해 높은 순위가 덮음 (편집 뒤 남은 범위는 글자 수로 자름)
    void paint(TextRange? r, Color color) {
      if (r == null) return;
      final end = min(r.end, text.length);
      for (var i = max(r.start, 0); i < end; i++) {
        colors[i] = color;
      }
    }

    for (final m in _findMatches) {
      paint(m, const Color(0x80FFEB3B));
    }
    paint(_findCurrent, const Color(0xFFFFB74D));
    paint(_selectionHighlight, const Color(0x6600B0FF));
    return colors;
  }

  static TextStyle _styleFor(Marks marks, bool composing) {
    final decorations = [
      if (marks['underline'] == true || composing) TextDecoration.underline,
      if (marks['strikethrough'] == true) TextDecoration.lineThrough,
    ];
    final isLink = marks['href'] != null;
    return TextStyle(
      fontWeight: marks['bold'] == true ? FontWeight.bold : null,
      fontStyle: marks['italic'] == true ? FontStyle.italic : null,
      decoration: isLink
          ? TextDecoration.underline
          : TextDecoration.combine(decorations),
      // 배경색만 있는 글자는 다크 모드에서도 검은 글씨 (밝은 배경 위)
      color: isLink
          ? Colors.blue
          : _parseColor(marks['font_color']) ??
                (marks['bg_color'] != null ? Colors.black : null),
      backgroundColor: marks['code'] == true
          ? const Color(0x14000000)
          : _parseColor(marks['bg_color']),
      fontFamily: marks['code'] == true ? 'monospace' : null,
    );
  }

  static Color? _parseColor(Object? value) {
    if (value is! String) return null;
    final parsed = int.tryParse(value);
    return parsed == null ? null : Color(parsed);
  }
}
