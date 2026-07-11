import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
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
      showActions: showActions(blockComponentContext.node), // ← 추가
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state), // ← 추가
    );
  }
}

class LocalCodeBlockWidget extends BlockComponentStatefulWidget {
  const LocalCodeBlockWidget({
    super.key,
    required super.node,
    required super.configuration,
    super.showActions,
    super.actionBuilder,
  });

  @override
  State<LocalCodeBlockWidget> createState() => _LocalCodeBlockWidgetState();
}

class _LocalCodeBlockWidgetState extends State<LocalCodeBlockWidget>
    with SelectableMixin, BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;
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

  final _blockKey = GlobalKey();
  RenderBox? get _renderBox => context.findRenderObject() as RenderBox?;

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
    final editorState = context.read<EditorState>();

    Widget child = Padding(
      key: _blockKey,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: () => setState(() => _isEditing = true),
        onSecondaryTap: _showDeleteDialog,
        behavior: HitTestBehavior.translucent,
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
