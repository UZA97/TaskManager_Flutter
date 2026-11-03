import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'editor_block.dart';

/// 표 블록: rawData['rows']에 칸 글자를 2차원 목록으로 저장 (첫 행은 머리글)
class TableBlockView extends StatefulWidget {
  const TableBlockView({
    super.key,
    required this.block,
    required this.onChanged,
    required this.onDelete,
  });

  final EditorBlock block;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  State<TableBlockView> createState() => _TableBlockViewState();
}

enum _TableAction {
  rowAbove,
  rowBelow,
  colLeft,
  colRight,
  deleteRow,
  deleteCol,
  deleteTable,
}

class _TableBlockViewState extends State<TableBlockView> {
  late List<List<TextEditingController>> _cells;

  /// 마우스를 올렸는지 (표 전체 대신 버튼·손잡이만 다시 그림)
  final _hovered = ValueNotifier(false);

  /// 열 너비 (null이면 표가 줄 너비를 똑같이 나눠 씀). 크기를 조절하면 저장됨.
  List<double>? _widths;
  bool _resizing = false;
  List<double> _dragStartWidths = const [];
  double _dragDistance = 0;
  final _tableKey = GlobalKey();
  late List<GlobalKey> _headerKeys;

  static const _minColumnWidth = 48.0;

  Map<String, Object?> get _data => widget.block.rawData;

  FocusNode get _focus => widget.block.focusNode;

  /// 표나 표의 칸에 커서가 있으면 고른 상태
  bool get _selected => _focus.hasFocus;

  @override
  void initState() {
    super.initState();
    _cells = [
      for (final row in tableRowsOf(widget.block))
        [for (final text in row) TextEditingController(text: text)],
    ];
    final widths = _data['col_widths'];
    if (widths is List && widths.length == _columns) {
      _widths = [for (final w in widths) (w as num).toDouble()];
    }
    _headerKeys = [for (var c = 0; c < _columns; c++) GlobalKey()];
    _focus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _hovered.dispose();
    for (final row in _cells) {
      for (final cell in row) {
        cell.dispose();
      }
    }
    super.dispose();
  }

  int get _columns => _cells.isEmpty ? 0 : _cells.first.length;

  void _save() {
    _data['rows'] = [
      for (final row in _cells) [for (final cell in row) cell.text],
    ];
    final widths = _widths;
    if (widths == null) {
      _data.remove('col_widths');
    } else {
      _data['col_widths'] = [for (final w in widths) w.roundToDouble()];
    }
    widget.onChanged();
  }

  // ───────────── 크기 조절

  /// 지금 화면에 보이는 열 너비
  List<double> _currentWidths() => [
    for (var c = 0; c < _columns; c++)
      (_headerKeys[c].currentContext?.findRenderObject() as RenderBox?)
              ?.size
              .width ??
          120,
  ];

  /// 표가 쓸 수 있는 최대 너비 (줄 너비)
  double get _maxTableWidth {
    final box = _tableKey.currentContext?.findRenderObject() as RenderBox?;
    final max = box?.constraints.maxWidth;
    return max == null || !max.isFinite ? 2000 : max;
  }

  void _startResize() {
    _dragStartWidths = _widths ?? _currentWidths();
    _dragDistance = 0;
    setState(() => _resizing = true);
  }

  /// 열 경계 끌기: 그 열만 넓히거나 좁힘
  void _resizeColumn(int column, double dx) {
    _dragDistance += dx;
    final others =
        _dragStartWidths.fold(0.0, (sum, w) => sum + w) -
        _dragStartWidths[column];
    final width = (_dragStartWidths[column] + _dragDistance)
        .clamp(_minColumnWidth, max(_minColumnWidth, _maxTableWidth - others))
        .toDouble();
    setState(() => _widths = [..._dragStartWidths]..[column] = width);
  }

  /// 오른쪽 아래 손잡이 끌기: 모든 열을 같은 비율로
  void _resizeTable(double dx) {
    _dragDistance += dx;
    final total = _dragStartWidths.fold(0.0, (sum, w) => sum + w);
    final target = (total + _dragDistance)
        .clamp(
          _minColumnWidth * _columns,
          max(_minColumnWidth * _columns, _maxTableWidth),
        )
        .toDouble();
    final scale = target / total;
    setState(() => _widths = [for (final w in _dragStartWidths) w * scale]);
  }

  void _endResize() {
    if (!_resizing) return;
    setState(() => _resizing = false);
    _save();
  }

  void _insertRow(int at) {
    setState(() {
      _cells.insert(at, [
        for (var c = 0; c < _columns; c++) TextEditingController(),
      ]);
    });
    _save();
  }

  void _insertColumn(int at) {
    setState(() {
      for (final row in _cells) {
        row.insert(at, TextEditingController());
      }
      _headerKeys.insert(at, GlobalKey());
      final widths = _widths;
      if (widths != null) {
        // 새 열은 다른 열의 평균 너비
        widths.insert(at, widths.fold(0.0, (a, b) => a + b) / widths.length);
      }
    });
    _save();
  }

  void _deleteRow(int index) {
    if (_cells.length <= 1) return widget.onDelete();
    setState(() {
      for (final cell in _cells.removeAt(index)) {
        cell.dispose();
      }
    });
    _save();
  }

  void _deleteColumn(int index) {
    if (_columns <= 1) return widget.onDelete();
    setState(() {
      for (final row in _cells) {
        row.removeAt(index).dispose();
      }
      _headerKeys.removeAt(index);
      _widths?.removeAt(index);
    });
    _save();
  }

  Future<void> _showMenu(Offset position, int row, int col) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    PopupMenuItem<_TableAction> item(_TableAction value, String label) =>
        PopupMenuItem(
          value: value,
          height: 36,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        );
    final action = await showMenu<_TableAction>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        item(_TableAction.rowAbove, '위에 행 추가'),
        item(_TableAction.rowBelow, '아래에 행 추가'),
        item(_TableAction.colLeft, '왼쪽에 열 추가'),
        item(_TableAction.colRight, '오른쪽에 열 추가'),
        const PopupMenuDivider(),
        item(_TableAction.deleteRow, '행 삭제'),
        item(_TableAction.deleteCol, '열 삭제'),
        item(_TableAction.deleteTable, '표 삭제'),
      ],
    );
    switch (action) {
      case _TableAction.rowAbove:
        _insertRow(row);
      case _TableAction.rowBelow:
        _insertRow(row + 1);
      case _TableAction.colLeft:
        _insertColumn(col);
      case _TableAction.colRight:
        _insertColumn(col + 1);
      case _TableAction.deleteRow:
        _deleteRow(row);
      case _TableAction.deleteCol:
        _deleteColumn(col);
      case _TableAction.deleteTable:
        widget.onDelete();
      case null:
    }
  }

  Widget _cell(int row, int col) {
    return GestureDetector(
      key: row == 0 ? _headerKeys[col] : null,
      onSecondaryTapDown: (details) =>
          _showMenu(details.globalPosition, row, col),
      child: Stack(
        children: [
          _cellField(row, col),
          // 칸 오른쪽 경계를 끌면 열 너비 조절
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 6,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => _startResize(),
                onHorizontalDragUpdate: (d) => _resizeColumn(col, d.delta.dx),
                onHorizontalDragEnd: (_) => _endResize(),
                onHorizontalDragCancel: _endResize,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cellField(int row, int col) {
    final header = row == 0;
    return Container(
      color: header ? context.surfaceSoft : null,
      child: TextField(
        controller: _cells[row][col],
        maxLines: null,
        style: TextStyle(
          fontSize: 14,
          fontWeight: header ? FontWeight.w600 : null,
        ),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        onChanged: (_) => _save(),
      ),
    );
  }

  /// 표 가장자리의 추가 버튼 (마우스를 올렸을 때만)
  Widget _addButton(String tooltip, VoidCallback onTap, {required bool wide}) {
    return ValueListenableBuilder<bool>(
      valueListenable: _hovered,
      builder: (context, hovered, child) => AnimatedOpacity(
        opacity: hovered ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        child: child,
      ),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: wide ? double.infinity : 20,
            height: wide ? 20 : null,
            decoration: BoxDecoration(
              color: context.surfaceSoft,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.add, size: 14, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  /// 고른 표는 테두리를 강조하고, 오른쪽 아래에 전체 크기 조절 손잡이
  Widget _frame(Widget table) {
    final active = _selected || _resizing;
    return Stack(
      children: [
        table,
        if (active)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: context.accent, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        Positioned(
          right: 0,
          bottom: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: _hovered,
            builder: (context, hovered, handle) =>
                active || hovered ? handle! : const SizedBox.shrink(),
            child: Tooltip(
              message: '끌어서 표 크기 조절',
              waitDuration: const Duration(milliseconds: 600),
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpLeftDownRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => _startResize(),
                  onPanUpdate: (d) => _resizeTable(d.delta.dx),
                  onPanEnd: (_) => _endResize(),
                  onPanCancel: _endResize,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: context.accent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                    child: const Icon(
                      Icons.open_in_full,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final border = BorderSide(color: context.line);
    return MouseRegion(
      onEnter: (_) => _hovered.value = true,
      onExit: (_) => _hovered.value = false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: _frame(
                      Table(
                        key: _tableKey,
                        columnWidths: _widths == null
                            ? null
                            : {
                                for (var c = 0; c < _columns; c++)
                                  c: FixedColumnWidth(_widths![c]),
                              },
                        border: TableBorder(
                          top: border,
                          bottom: border,
                          left: border,
                          right: border,
                          horizontalInside: border,
                          verticalInside: border,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.top,
                        children: [
                          for (var r = 0; r < _cells.length; r++)
                            TableRow(
                              children: [
                                for (var c = 0; c < _columns; c++) _cell(r, c),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _addButton(
                    '열 추가',
                    () => _insertColumn(_columns),
                    wide: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: _addButton(
                '행 추가',
                () => _insertRow(_cells.length),
                wide: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 저장된 표 칸 글자 (형식이 깨졌으면 빈 3×3)
List<List<String>> tableRowsOf(EditorBlock block) {
  final rows = block.rawData['rows'];
  if (rows is List && rows.isNotEmpty && rows.first is List) {
    final columns = (rows.first as List).length;
    if (columns > 0) {
      return [
        for (final row in rows)
          [
            for (var c = 0; c < columns; c++)
              row is List && c < row.length ? '${row[c] ?? ''}' : '',
          ],
      ];
    }
  }
  return List.generate(3, (_) => List.filled(3, ''));
}
