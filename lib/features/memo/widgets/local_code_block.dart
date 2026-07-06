import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter/services.dart';
import 'package:highlight/highlight.dart' hide Node;
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';

const localCodeType = 'local_code';

Node localCodeNode({String code = '', String language = 'dart'}) {
  return Node(
    type: localCodeType,
    attributes: {'code': code, 'language': language},
  );
}

class LocalCodeBlockComponentBuilder extends BlockComponentBuilder {
  LocalCodeBlockComponentBuilder()
    : super(
        configuration: BlockComponentConfiguration(
          padding: (_) => EdgeInsets.zero,
        ),
      ) {
    validate = (node) => node.type == localCodeType;
  }

  @override
  Position end(Node node) => Position(path: node.path, offset: 1); // ← 추가

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return LocalCodeBlockWidget(
      key: blockComponentContext.node.key,
      node: blockComponentContext.node,
      configuration: configuration,
    );
  }
}

class LocalCodeBlockWidget extends BlockComponentStatefulWidget {
  const LocalCodeBlockWidget({
    super.key,
    required super.node,
    required super.configuration,
  });

  @override
  State<LocalCodeBlockWidget> createState() => _LocalCodeBlockWidgetState();
}

class _LocalCodeBlockWidgetState extends State<LocalCodeBlockWidget> {
  late TextEditingController _controller;
  String get _code => widget.node.attributes['code'] as String? ?? '';
  String get _language =>
      widget.node.attributes['language'] as String? ?? 'dart';
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _code);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveCode(String value) {
    final editorState = provider.Provider.of<EditorState>(
      context,
      listen: false,
    );
    final transaction = editorState.transaction;
    transaction.updateNode(widget.node, {
      ...widget.node.attributes,
      'code': value,
    });
    editorState.apply(transaction);
  }

  void _detectAndSave() {
    final code = _controller.text;
    String detectedLang = 'text';

    if (code.isNotEmpty) {
      final result = highlight.parse(code, autoDetection: true);
      print(result.relevance);
      detectedLang = result.language ?? 'text';
    }

    final editorState = provider.Provider.of<EditorState>(
      context,
      listen: false,
    );
    final transaction = editorState.transaction;
    transaction.updateNode(widget.node, {
      ...widget.node.attributes,
      'code': code,
      'language': detectedLang,
    });
    editorState.apply(transaction);
    setState(() => _isEditing = false);
  }

  Future<void> _showDeleteDialog() async {
    final editorState = provider.Provider.of<EditorState>(
      context,
      listen: false,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('코드 블록 삭제'),
        content: const Text('코드 블록을 삭제할까요?'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: () => setState(() => _isEditing = true),
        onSecondaryTap: _showDeleteDialog,
        behavior: HitTestBehavior.translucent, // ← 추가
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isEditing
                  ? const Color(0xFF4A90E2)
                  : const Color(0xFFDDDDDD),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      _language,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Spacer(),
                    if (_isEditing)
                      GestureDetector(
                        onTap: _detectAndSave,
                        child: const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),

              // 편집 모드
              if (_isEditing)
                TextField(
                  controller: _controller,
                  maxLines: null,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(12),
                    border: InputBorder.none,
                  ),
                  onChanged: _saveCode,
                )
              // 뷰 모드
              else
                _code.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          '코드를 입력하세요',
                          style: TextStyle(
                            color: Colors.grey,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      )
                    : HighlightView(
                        _code,
                        language: _language,
                        theme: githubTheme,
                        padding: const EdgeInsets.all(12),
                        textStyle: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
            ], // ← Column children 닫기
          ),
        ),
      ),
    );
  }
}
