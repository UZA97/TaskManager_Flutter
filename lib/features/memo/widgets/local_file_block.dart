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

class _LocalFileBlockWidgetState extends State<LocalFileBlockWidget> {
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

    return GestureDetector(
      onTap: _openFile,
      onSecondaryTap: _showDeleteDialog,
      behavior: HitTestBehavior.opaque,
      child: Padding(
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
              const Icon(Icons.insert_drive_file,
                  size: 16, color: Color(0xFF4A90E2)),
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
  }
}
