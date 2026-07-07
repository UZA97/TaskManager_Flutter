import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart' as provider;
import '../../../core/providers/navigation_provider.dart';
import '../../map/providers/map_provider.dart';
import '../../map/services/vworld_service.dart';

const localLocationType = 'local_location';

Node localLocationNode({
  required String name,
  required double lat,
  required double lng,
}) {
  return Node(
    type: localLocationType,
    attributes: {'name': name, 'lat': lat, 'lng': lng},
  );
}

class LocalLocationBlockComponentBuilder extends BlockComponentBuilder {
  LocalLocationBlockComponentBuilder()
    : super(
        configuration: BlockComponentConfiguration(
          padding: (_) => EdgeInsets.zero,
        ),
      ) {
    validate = (node) => node.type == localLocationType;
  }

  @override
  Position end(Node node) => Position(path: node.path, offset: 1); // ← 추가

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    return LocalLocationBlockWidget(
      key: blockComponentContext.node.key,
      node: blockComponentContext.node,
      configuration: configuration,
      showActions: showActions(blockComponentContext.node), // ← 추가
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state), // ← 추가
    );
  }
}

class LocalLocationBlockWidget extends BlockComponentStatefulWidget {
  const LocalLocationBlockWidget({
    super.key,
    required super.node,
    required super.configuration,
    required super.showActions,
    required super.actionBuilder,
  });

  @override
  State<LocalLocationBlockWidget> createState() =>
      _LocalLocationBlockWidgetState();
}

class _LocalLocationBlockWidgetState extends State<LocalLocationBlockWidget>
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

  String get _name => widget.node.attributes['name'] as String;
  double get _lat => (widget.node.attributes['lat'] as num).toDouble();
  double get _lng => (widget.node.attributes['lng'] as num).toDouble();

  void _onTap() {
    // ProviderScope 접근
    final container = ProviderScope.containerOf(context);

    // 위치 세팅
    container
        .read(selectedLocationProvider.notifier)
        .select(SelectedLocation(name: _name, position: LatLng(_lat, _lng)));

    // 지도 탭으로 이동 (index 3)
    container.read(navigationProvider.notifier).navigateTo(3);
  }

  Future<void> _showDeleteDialog() async {
    final editorState = provider.Provider.of<EditorState>(
      context,
      listen: false,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('위치 삭제'),
        content: Text('"$_name" 위치를 삭제할까요?'),
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
    final imageUrl = VworldService.staticImageUrl(
      lat: _lat,
      lng: _lng,
      width: 300,
      height: 150,
    );

    Widget child = GestureDetector(
      onTap: _onTap,
      onSecondaryTap: _showDeleteDialog,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 정적 지도 이미지
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 300,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 300,
                  height: 150,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.map, color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // 장소명 칩
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_pin,
                  color: Color(0xFFE53935),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  _name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4A90E2),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ],
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
