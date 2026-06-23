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

  void _loadImageSize() {
    final src = widget.node.attributes['src'] as String;
    final file = File(src);
    if (!file.existsSync()) return;

    final image = Image.file(file);
    image.image.resolve(const ImageConfiguration()).addListener(
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

  @override
  Widget build(BuildContext context) {
    final src = widget.node.attributes['src'] as String;

    return TapRegion(
      onTapOutside: (_) {
        if (!_isDragging) setState(() => _isSelected = false);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () => setState(() => _isSelected = true),
            child: SizedBox(
              width: _width,
              height: _aspectRatio != null ? _width / _aspectRatio! : null,
              child: Stack(
                clipBehavior: Clip.none,
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

                  // 선택 테두리
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

                  // 우측 상단 삭제 버튼
                  if (_isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: _showDeleteDialog,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                  // 우측 하단 리사이즈 핸들
                  if (_isSelected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onPanStart: (d) {
                          _isDragging = true;
                          _dragStartX = d.globalPosition.dx;
                          _dragStartY = d.globalPosition.dy;
                          _dragStartWidth = _width;
                        },
                        onPanUpdate: (d) {
                          final deltaX = d.globalPosition.dx - _dragStartX;
                          final deltaY = d.globalPosition.dy - _dragStartY;
                          final delta = (deltaX + deltaY) / 2;
                          setState(() {
                            _width =
                                (_dragStartWidth + delta).clamp(100.0, 800.0);
                          });
                        },
                        onPanEnd: (_) {
                          _isDragging = false;
                          _saveWidth(_width);
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.resizeUpLeftDownRight,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A90E2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const Icon(
                              Icons.open_in_full,
                              color: Colors.white,
                              size: 12,
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
      ),
    );
  }
}
