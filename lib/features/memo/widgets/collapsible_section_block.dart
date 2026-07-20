import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const collapsibleSectionType = 'collapsible_section';

Node collapsibleSectionNode({
  String title = '',
  bool collapsed = false,
  String? backgroundColor,
}) {
  return Node(
    type: collapsibleSectionType,
    attributes: {
      'collapsed': collapsed,
      if (backgroundColor != null) 'backgroundColor': backgroundColor,
      'delta': (Delta()..insert(title.isEmpty ? ' ' : title))
          .toJson(), // 빈 문자열 방지
    },
    children: [
      Node(
        type: 'paragraph',
        attributes: {'delta': (Delta()..insert('')).toJson()},
      ),
    ],
  );
}

class CollapsibleSectionBlockComponentBuilder extends BlockComponentBuilder {
  CollapsibleSectionBlockComponentBuilder()
    : super(
        configuration: BlockComponentConfiguration(
          padding: (_) => const EdgeInsets.symmetric(vertical: 4),
        ),
      ) {
    validate = (node) => node.type == collapsibleSectionType;
  }

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return CollapsibleSectionBlockWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
    );
  }
}

class CollapsibleSectionBlockWidget extends BlockComponentStatefulWidget {
  const CollapsibleSectionBlockWidget({
    super.key,
    required super.node,
    required super.configuration,
    super.showActions,
    super.actionBuilder,
  });

  @override
  State<CollapsibleSectionBlockWidget> createState() =>
      _CollapsibleSectionBlockWidgetState();
}

class _CollapsibleSectionBlockWidgetState
    extends State<CollapsibleSectionBlockWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        NestedBlockComponentStatefulWidgetMixin {
  @override
  final forwardKey = GlobalKey(debugLabel: 'collapsible_section_text');

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: collapsibleSectionType,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  late final editorState = Provider.of<EditorState>(context, listen: false);

  bool get _collapsed => widget.node.attributes['collapsed'] as bool? ?? false;

  String? get _backgroundColor =>
      widget.node.attributes['backgroundColor'] as String?;

  void _toggleCollapsed() {
    final transaction = editorState.transaction;
    transaction.updateNode(widget.node, {
      ...widget.node.attributes,
      'collapsed': !_collapsed,
    });
    editorState.apply(transaction);
  }

  void _setBackgroundColor(String? color) {
    final transaction = editorState.transaction;
    final attrs = Map<String, dynamic>.from(widget.node.attributes);
    attrs['backgroundColor'] = color ?? 'transparent';
    transaction.updateNode(widget.node, attrs);
    editorState.apply(transaction);
    setState(() {});
  }

  void _showColorMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    // 1단계: 햄버거 메뉴
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + box.size.height,
        offset.dx + box.size.width,
        offset.dy,
      ),
      items: const [
        PopupMenuItem(
          value: 'color',
          child: Row(
            children: [
              Icon(Icons.palette, size: 16),
              SizedBox(width: 8),
              Text('색상 변경'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('삭제', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );

    if (action == 'delete') {
      final transaction = editorState.transaction;
      transaction.deleteNode(widget.node);
      editorState.apply(transaction);
      return;
    }

    if (action != 'color') return;

    // 2단계: 색상 선택
    final colors = [
      (const Color(0xFFFFCDD2), '빨강', '#FFCDD2'),
      (const Color(0xFFFFE0B2), '주황', '#FFE0B2'),
      (const Color(0xFFFFF9C4), '노랑', '#FFF9C4'),
      (const Color(0xFFC8E6C9), '초록', '#C8E6C9'),
      (const Color(0xFFBBDEFB), '파랑', '#BBDEFB'),
      (const Color(0xFFE1BEE7), '보라', '#E1BEE7'),
    ];

    final colorResult = await showMenu<String?>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + box.size.height,
        offset.dx + box.size.width,
        offset.dy,
      ),
      items: [
        ...colors.map((item) {
          final (color, label, hex) = item;
          return PopupMenuItem<String?>(
            value: hex,
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
                const SizedBox(width: 8),
                Text(label),
              ],
            ),
          );
        }),
        const PopupMenuDivider(),
        const PopupMenuItem<String?>(
          value: 'clear',
          child: Row(
            children: [
              Icon(Icons.format_color_reset, size: 16),
              SizedBox(width: 8),
              Text('배경색 해제'),
            ],
          ),
        ),
      ],
    );

    if (colorResult == 'clear') {
      _setBackgroundColor(null);
    } else if (colorResult != null) {
      _setBackgroundColor(colorResult);
    }
  }

  Color get _bgColor {
    final hex = _backgroundColor;
    if (hex == null || hex == 'transparent') return Colors.transparent;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.transparent;
    }
  }

  @override
  Widget buildComponentWithChildren(BuildContext context) {
    return buildComponent(context, withBackgroundColor: true);
  }

  @override
  Widget buildComponent(
    BuildContext context, {
    bool withBackgroundColor = true,
  }) {
    final bgColor = _bgColor;

    final children = editorState.renderer.buildList(
      context,
      widget.node.children,
    );

    Widget child = Container(
      key: blockComponentKey,
      decoration: BoxDecoration(
        color: bgColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _toggleCollapsed,
                  child: Icon(
                    _collapsed ? Icons.arrow_right : Icons.arrow_drop_down,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: AppFlowyRichText(
                    key: forwardKey,
                    delegate: this,
                    node: widget.node,
                    editorState: editorState,
                    placeholderText: '섹션 제목',
                    textSpanDecorator: (textSpan) => textSpan.updateTextStyle(
                      const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    placeholderTextSpanDecorator: (textSpan) => textSpan
                        .updateTextStyle(TextStyle(color: Colors.grey[400])),
                    cursorColor: editorState.editorStyle.cursorColor,
                    selectionColor: editorState.editorStyle.selectionColor,
                    cursorWidth: editorState.editorStyle.cursorWidth,
                  ),
                ),
                Builder(
                  builder: (ctx) => GestureDetector(
                    onTap: () => _showColorMenu(ctx),
                    child: Icon(
                      Icons.more_vert,
                      size: 18,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 내용
          if (!_collapsed) ...[
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ],
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
        // BlockSelectionType.cursor,
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
