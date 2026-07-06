import 'dart:io';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const localFileType = 'local_file';

Node localFileNode({required String src, required String fileName}) {
  return Node(
    type: localFileType,
    attributes: {'src': src, 'fileName': fileName},
  );
}

class LocalFileBlockComponentBuilder extends BlockComponentBuilder {
  LocalFileBlockComponentBuilder()
    : super(
        configuration: BlockComponentConfiguration(
          padding: (_) => EdgeInsets.zero,
        ),
      ) {
    validate = (node) => node.type == localFileType;
  }

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return LocalFileBlockWidget(
      key: blockComponentContext.node.key,
      node: blockComponentContext.node,
      configuration: configuration,
    );
  }
}

class LocalFileBlockWidget extends BlockComponentStatefulWidget {
  const LocalFileBlockWidget({
    super.key,
    required super.node,
    required super.configuration,
  });

  @override
  State<LocalFileBlockWidget> createState() => _LocalFileBlockWidgetState();
}

class _LocalFileBlockWidgetState extends State<LocalFileBlockWidget>
    with SelectableMixin, BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  final _blockKey = GlobalKey();
  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

  Future<void> _openFile() async {
    final src = widget.node.attributes['src'] as String;
    await Process.run('explorer', [src]);
  }

  Future<void> _showDeleteDialog() async {
    final editorState = Provider.of<EditorState>(context, listen: false);
    final fileName = widget.node.attributes['fileName'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('파일 삭제'),
        content: Text('"$fileName" 을 삭제할까요?'),
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

  @override
  Widget build(BuildContext context) {
    final fileName = widget.node.attributes['fileName'] as String;
    final editorState = context.read<EditorState>();

    Widget child = GestureDetector(
      onTap: _openFile,
      onSecondaryTap: _showDeleteDialog,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        key: _blockKey,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F5FF),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFD0E0FF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.insert_drive_file,
                size: 16,
                color: Color(0xFF4A90E2),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4A90E2),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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

    return child;
  }

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
}
