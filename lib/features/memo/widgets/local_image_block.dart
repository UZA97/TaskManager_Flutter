import 'dart:io';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

const localImageType = 'local_image';

Node localImageNode({required String src, double width = 300}) {
  return Node(type: localImageType, attributes: {'src': src, 'width': width});
}

class LocalImageBlockComponentBuilder extends BlockComponentBuilder {
  LocalImageBlockComponentBuilder()
    : super(
        configuration: BlockComponentConfiguration(
          padding: (_) => EdgeInsets.zero,
        ),
      ) {
    validate = (node) => node.type == localImageType;
  }

  @override
  Position end(Node node) => Position(path: node.path, offset: 1); // ← 추가

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return LocalImageBlockWidget(
      key: blockComponentContext.node.key,
      node: blockComponentContext.node,
      configuration: configuration,
      showActions: showActions(blockComponentContext.node), // ← 추가
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state), // ← 추가
    );
  }
}

class _ImageMenuButton extends StatefulWidget {
  const _ImageMenuButton({
    required this.onCopy,
    required this.onCut,
    required this.onDelete,
  });

  final VoidCallback onCopy;
  final VoidCallback onCut;
  final VoidCallback onDelete;

  @override
  State<_ImageMenuButton> createState() => _ImageMenuButtonState();
}

class _ImageMenuButtonState extends State<_ImageMenuButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMenu(context),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.menu, color: Colors.white, size: 16),
      ),
    );
  }

  void _showMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + box.size.height,
        offset.dx + box.size.width,
        offset.dy,
      ),
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem(
          onTap: widget.onCopy,
          child: const Row(
            children: [
              Icon(Icons.copy, size: 16),
              SizedBox(width: 8),
              Text('복사'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: widget.onCut,
          child: const Row(
            children: [
              Icon(Icons.content_cut, size: 16),
              SizedBox(width: 8),
              Text('잘라내기'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: widget.onDelete,
          child: const Row(
            children: [
              Icon(Icons.delete, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('삭제', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }
}

class LocalImageBlockWidget extends BlockComponentStatefulWidget {
  const LocalImageBlockWidget({
    super.key,
    required super.node,
    required super.configuration,
    super.showActions,
    super.actionBuilder,
  });

  @override
  State<LocalImageBlockWidget> createState() => _LocalImageBlockWidgetState();
}

class _LocalImageBlockWidgetState extends State<LocalImageBlockWidget>
    with SelectableMixin, BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  final _blockKey = GlobalKey();
  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  @override
  Position start() => Position(path: widget.node.path, offset: 0);

  @override
  Position end() => Position(path: widget.node.path, offset: 1);

  @override
  Position getPositionInOffset(Offset start) => end();

  @override
  bool get shouldCursorBlink => false;

  @override
  CursorStyle get cursorStyle => CursorStyle.cover;

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) {
    return getRectsInSelection(Selection.invalid()).first;
  }

  @override
  Rect? getCursorRectInPosition(
    Position position, {
    bool shiftWithBaseOffset = false,
  }) {
    if (_renderBox == null) return null;
    return getRectsInSelection(
      Selection.collapsed(position),
      shiftWithBaseOffset: shiftWithBaseOffset,
    ).firstOrNull;
  }

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    if (_renderBox == null) return [];
    final parentBox = context.findRenderObject();
    final blockBox = _blockKey.currentContext?.findRenderObject();
    if (parentBox is RenderBox && blockBox is RenderBox) {
      return [
        (shiftWithBaseOffset
                ? blockBox.localToGlobal(Offset.zero, ancestor: parentBox)
                : Offset.zero) &
            blockBox.size,
      ];
    }
    return [Offset.zero & _renderBox!.size];
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) =>
      Selection.single(path: widget.node.path, startOffset: 0, endOffset: 1);

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) =>
      _renderBox!.localToGlobal(offset);

  @override
  TextDirection textDirection() => TextDirection.ltr;

  late double _width;
  double? _aspectRatio;
  bool _isSelected = false;
  bool _isDragging = false;

  double _dragStartX = 0;
  double _dragStartY = 0;
  double _dragStartWidth = 0;

  @override
  void initState() {
    super.initState();
    _width = ((widget.node.attributes['width'] as num?)?.toDouble() ?? 300)
        .clamp(100.0, 800.0);
    _loadImageSize();
  }

  String get _imageSrc =>
      (widget.node.attributes['src'] ?? widget.node.attributes['url'])
          as String;

  void _loadImageSize() {
    final src = _imageSrc;
    final file = File(src);
    if (!file.existsSync()) return;

    final image = Image.file(file);
    image.image
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener((info, _) {
            if (!mounted) return;
            final w = info.image.width.toDouble();
            final h = info.image.height.toDouble();
            if (h > 0) setState(() => _aspectRatio = w / h);
          }),
        );
  }

  void _saveWidth(double newWidth) {
    final editorState = Provider.of<EditorState>(context, listen: false);
    final transaction = editorState.transaction;
    transaction.updateNode(widget.node, {
      ...widget.node.attributes,
      'width': newWidth,
    });
    editorState.apply(transaction);
  }

  Future<void> _showDeleteDialog() async {
    final editorState = Provider.of<EditorState>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이미지 삭제'),
        content: const Text('이미지를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final transaction = editorState.transaction;
      transaction.deleteNode(widget.node);
      editorState.apply(transaction);
    }
  }

  void _copyImage() async {
    await Clipboard.setData(ClipboardData(text: _imageSrc));
  }

  void _cutImage() async {
    await Clipboard.setData(ClipboardData(text: _imageSrc));
    final editorState = Provider.of<EditorState>(context, listen: false);
    final transaction = editorState.transaction;
    transaction.deleteNode(widget.node);
    editorState.apply(transaction);
  }

  @override
  Widget build(BuildContext context) {
    final src = _imageSrc;
    final editorState = context.read<EditorState>();

    Widget child = TapRegion(
      onTapOutside: (_) {
        if (!_isDragging && _isSelected) {
          setState(() => _isSelected = false);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: _width,
            height: _aspectRatio != null ? _width / _aspectRatio! : 200,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _isSelected = true),
                    onSecondaryTap: _showDeleteDialog,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(
                        File(src),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isSelected)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF4A90E2),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                if (_isSelected)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _ImageMenuButton(
                      onCopy: _copyImage,
                      onCut: _cutImage,
                      onDelete: _showDeleteDialog,
                    ),
                  ),
                if (_isSelected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpLeftDownRight,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) {
                          _isDragging = true;
                          _dragStartX = e.position.dx;
                          _dragStartY = e.position.dy;
                          _dragStartWidth = _width;
                        },
                        onPointerMove: (e) {
                          final deltaX = e.position.dx - _dragStartX;
                          final deltaY = e.position.dy - _dragStartY;
                          final delta = (deltaX + deltaY) / 2;
                          setState(() {
                            _width = (_dragStartWidth + delta).clamp(
                              100.0,
                              800.0,
                            );
                          });
                        },
                        onPointerUp: (_) {
                          _isDragging = false;
                          _saveWidth(_width);
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90E2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Icon(
                            Icons.open_in_full,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      cursorColor: editorState.editorStyle.cursorColor,
      selectionColor: editorState.editorStyle.selectionColor,
      supportTypes: const [
        BlockSelectionType.block,
        BlockSelectionType.cursor,
        BlockSelectionType.selection,
      ],
      child: child,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        child: child,
      );
    }

    return child;
  }
}
