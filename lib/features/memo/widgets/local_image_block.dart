import 'dart:io';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const localImageType = 'local_image';

Node localImageNode({required String src, double width = 300}) {
  return Node(
    type: localImageType,
    attributes: {'src': src, 'width': width},
  );
}

class LocalImageBlockComponentBuilder extends BlockComponentBuilder {
  LocalImageBlockComponentBuilder()
      : super(configuration: const BlockComponentConfiguration()) {
    validate = (node) => node.attributes['src'] is String;
  }

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return LocalImageBlockWidget(
      key: blockComponentContext.node.key,
      node: blockComponentContext.node,
      configuration: configuration,
    );
  }
}

class LocalImageBlockWidget extends BlockComponentStatefulWidget {
  const LocalImageBlockWidget({
    super.key,
    required super.node,
    required super.configuration,
  });

  @override
  State<LocalImageBlockWidget> createState() => _LocalImageBlockWidgetState();
}

class _LocalImageBlockWidgetState extends State<LocalImageBlockWidget> {
  late double _width;
  double _dragStartX = 0;
  double _dragStartWidth = 0;

  @override
  void initState() {
    super.initState();
    _width = (widget.node.attributes['width'] as num?)?.toDouble() ?? 300;
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

  @override
  Widget build(BuildContext context) {
    final src = widget.node.attributes['src'] as String;

    return GestureDetector(
      onSecondaryTap: _showDeleteDialog,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: _width,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(
                    File(src),
                    width: _width,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: _width,
                      height: 100,
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
                // 리사이즈 핸들
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onHorizontalDragStart: (d) {
                      _dragStartX = d.globalPosition.dx;
                      _dragStartWidth = _width;
                    },
                    onHorizontalDragUpdate: (d) {
                      final delta = d.globalPosition.dx - _dragStartX;
                      setState(() {
                        _width = (_dragStartWidth + delta).clamp(100.0, 800.0);
                      });
                    },
                    onHorizontalDragEnd: (_) => _saveWidth(_width),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: Container(
                        width: 12,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.6),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
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
  }
}
