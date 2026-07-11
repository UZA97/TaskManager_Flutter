import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';
import '../widgets/local_image_block.dart';
import '../widgets/local_file_block.dart';
import '../widgets/local_location_block.dart';
import '../widgets/local_code_block.dart';
import '../../map/services/vworld_service.dart';
import '../../map/widgets/location_search_dialog.dart';
import 'package:pasteboard/pasteboard.dart';
import '../data/note_repository.dart';
import '../services/pdf_export_service.dart';
import 'memo_editor_widgets.dart';

const String _toggleListType = 'toggle_list';

class ToggleListBlockComponentBuilder extends BlockComponentBuilder {
  ToggleListBlockComponentBuilder({
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return ToggleListBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.delta != null;
}

class ToggleListBlockComponentWidget extends BlockComponentStatefulWidget {
  const ToggleListBlockComponentWidget({
    super.key,
    required super.node,
    required super.configuration,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
  });

  @override
  State<ToggleListBlockComponentWidget> createState() =>
      _ToggleListBlockComponentWidgetState();
}

class _ToggleListBlockComponentWidgetState
    extends State<ToggleListBlockComponentWidget>
    with
        SelectableMixin,
        DefaultSelectableMixin,
        BlockComponentConfigurable,
        BlockComponentBackgroundColorMixin,
        NestedBlockComponentStatefulWidgetMixin,
        BlockComponentTextDirectionMixin,
        BlockComponentAlignMixin {
  @override
  final forwardKey = GlobalKey<State<StatefulWidget>>();

  @override
  GlobalKey<State<StatefulWidget>> get containerKey => widget.node.key;

  @override
  GlobalKey<State<StatefulWidget>> blockComponentKey = GlobalKey(
    debugLabel: _toggleListType,
  );

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  void _toggleCollapsed() {
    final collapsed = widget.node.attributes['collapsed'] as bool? ?? false;
    final transaction = editorState.transaction;
    transaction.updateNode(widget.node, {
      ...widget.node.attributes,
      'collapsed': !collapsed,
    });
    editorState.apply(transaction);
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.node.attributes['collapsed'] as bool? ?? false;
    return collapsed
        ? buildComponent(context)
        : buildComponentWithChildren(context);
  }

  @override
  Widget buildComponent(
    BuildContext context, {
    bool withBackgroundColor = true,
  }) {
    final collapsed = widget.node.attributes['collapsed'] as bool? ?? false;
    final textDirection = calculateTextDirection(
      layoutDirection: Directionality.maybeOf(context),
    );

    Widget child = Container(
      width: double.infinity,
      alignment: alignment,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        textDirection: textDirection,
        children: [
          GestureDetector(
            onTap: _toggleCollapsed,
            child: Icon(
              collapsed ? Icons.expand_more : Icons.expand_less,
              size: 18,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppFlowyRichText(
              key: forwardKey,
              delegate: this,
              node: widget.node,
              editorState: editorState,
              textAlign: alignment?.toTextAlign ?? textAlign,
              placeholderText: placeholderText,
              textSpanDecorator: (textSpan) => textSpan.updateTextStyle(
                textStyleWithTextSpan(textSpan: textSpan),
              ),
              placeholderTextSpanDecorator: (textSpan) =>
                  textSpan.updateTextStyle(
                    placeholderTextStyleWithTextSpan(textSpan: textSpan),
                  ),
              textDirection: textDirection,
              cursorColor: editorState.editorStyle.cursorColor,
              selectionColor: editorState.editorStyle.selectionColor,
              cursorWidth: editorState.editorStyle.cursorWidth,
            ),
          ),
        ],
      ),
    );

    child = Container(
      decoration: withBackgroundColor ? decoration : null,
      key: blockComponentKey,
      padding: padding,
      child: child,
    );

    child = BlockSelectionContainer(
      node: node,
      delegate: this,
      listenable: editorState.selectionNotifier,
      remoteSelection: editorState.remoteSelections,
      blockColor: editorState.editorStyle.selectionColor,
      supportTypes: const [BlockSelectionType.block],
      child: child,
    );

    if (widget.showActions && widget.actionBuilder != null) {
      child = BlockComponentActionWrapper(
        node: node,
        actionBuilder: widget.actionBuilder!,
        actionTrailingBuilder: widget.actionTrailingBuilder,
        child: child,
      );
    }

    return child;
  }
}

class MemoEditorView extends ConsumerStatefulWidget {
  const MemoEditorView({super.key});

  @override
  ConsumerState<MemoEditorView> createState() => _MemoEditorViewState();
}

class _MemoEditorViewState extends ConsumerState<MemoEditorView> {
  EditorState? _editorState;
  Note? _currentNote;
  final _titleController = TextEditingController();
  bool _isDragging = false;
  bool _isToolbarExpanded = true;
  Selection? _lastSelection;
  Timer? _saveTimer;
  StreamSubscription<void>? _transactionSubscription;
  VoidCallback? _selectionListener;

  SelectionMenuItem get _locationMenuItem => SelectionMenuItem(
    getName: () => 'Location',
    icon: (editorState, onSelected, style) =>
        const Icon(Icons.location_pin, color: Color(0xFFE53935), size: 18),
    keywords: ['위치', 'location', 'map', '지도'],
    handler: (editorState, menuService, context) {
      menuService.dismiss();
      _showLocationSearchDialog(editorState);
    },
  );

  SelectionMenuItem get _codeMenuItem => SelectionMenuItem(
    getName: () => 'Code',
    icon: (editorState, isSelected, style) =>
        const Icon(Icons.code, size: 18, color: Colors.grey),
    keywords: ['코드', 'code', '코드블록'],
    handler: (editorState, menuService, context) {
      insertNodeAfterSelection(editorState, localCodeNode());
    },
  );

  SelectionMenuItem get _fileMenuItem => SelectionMenuItem(
    getName: () => 'file',
    icon: (editorState, isSelected, style) =>
        const Icon(Icons.attach_file, size: 18, color: Colors.grey),
    keywords: ['파일', 'file', '첨부'],
    handler: (editorState, menuService, context) {
      menuService.dismiss();
      _pickFile();
    },
  );

  /// 위치 검색 다이얼로그를 열고 결과를 에디터에 삽입합니다.
  Future<void> _showLocationSearchDialog(EditorState editorState) async {
    final result = await showDialog<VworldSearchResult>(
      context: context,
      builder: (context) => const LocationSearchDialog(),
    );

    if (result == null) return;

    _insertAtCursor(
      localLocationNode(name: result.name, lat: result.lat, lng: result.lng),
    );
  }

  static const _imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];

  /// 파일 경로의 확장자가 이미지인지 판단합니다.
  bool _isImage(String filePath) =>
      _imageExts.contains(path.extension(filePath).toLowerCase());

  /// 툴바에 표시할 단추 스타일을 생성합니다.
  Widget _buildFormatButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 18, color: Colors.grey[700]),
        ),
      ),
    );
  }

  /// Alt+0~9 / Alt+Shift+0~9 단축키로 텍스트 색상과 하이라이트를 적용합니다.
  List<CommandShortcutEvent> _buildColorShortcutEvents() {
    final textColors = [
      const Color(0xFFE53935),
      const Color(0xFFFF9800),
      const Color(0xFFFFEB3B),
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFF3F51B5),
      const Color(0xFF9C27B0),
      const Color(0xFF9E9E9E),
      const Color(0xFF009688),
      Colors.black,
    ];

    final highlightColors = [
      const Color(0xFFE53935),
      const Color(0xFFFF9800),
      const Color(0xFFFFEB3B),
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFF3F51B5),
      const Color(0xFF9C27B0),
      const Color(0xFF9E9E9E),
      const Color(0xFF009688),
      Colors.transparent,
    ];

    final textColorEvents = List.generate(10, (index) {
      final color = textColors[index];
      return CommandShortcutEvent(
        key: 'apply text color ${index.toString()}',
        getDescription: () => 'Apply text color ${index.toString()}',
        command: 'alt+${index.toString()}',
        handler: (editorState) {
          final selection = editorState.selection;
          if (selection == null || selection.isCollapsed) {
            return KeyEventResult.ignored;
          }
          _lastSelection = selection;
          _applyColor('color', color);
          return KeyEventResult.handled;
        },
      );
    });

    final highlightEvents = List.generate(10, (index) {
      final color = highlightColors[index];
      return CommandShortcutEvent(
        key: 'apply highlight ${index.toString()}',
        getDescription: () => 'Apply highlight ${index.toString()}',
        command: 'alt+shift+${index.toString()}',
        handler: (editorState) {
          final selection = editorState.selection;
          if (selection == null || selection.isCollapsed) {
            return KeyEventResult.ignored;
          }
          _lastSelection = selection;
          _applyColor('backgroundColor', color);
          return KeyEventResult.handled;
        },
      );
    });

    return [...textColorEvents, ...highlightEvents];
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _transactionSubscription?.cancel();
    if (_editorState != null && _selectionListener != null) {
      _editorState!.selectionNotifier.removeListener(_selectionListener!);
    }
    _titleController.dispose();
    super.dispose();
  }

  /// 선택된 메모 내용을 에디터 상태로 초기화합니다.
  void _initEditor(Note note) {
    _titleController.text = note.title;

    // 이전 에디터 상태의 리스너 해제
    _transactionSubscription?.cancel();
    if (_editorState != null && _selectionListener != null) {
      _editorState!.selectionNotifier.removeListener(_selectionListener!);
      _selectionListener = null;
    }

    EditorState editorState;
    if (note.content.isNotEmpty) {
      try {
        editorState = EditorState(
          document: Document.fromJson(jsonDecode(note.content)),
        );
      } catch (_) {
        try {
          editorState = EditorState(document: markdownToDocument(note.content));
        } catch (_) {
          editorState = EditorState.blank();
        }
      }
    } else {
      editorState = EditorState.blank();
    }

    editorState.selectionMenuItems = [
      ...standardSelectionMenuItems.where((e) => !e.keywords.contains('image')),
      _locationMenuItem,
      _codeMenuItem,
      _fileMenuItem,
    ];

    _transactionSubscription = editorState.transactionStream.listen((_) {
      _onContentChanged();
    });

    _selectionListener = () {
      final sel = editorState.selection;
      if (sel != null && !sel.isCollapsed) {
        _lastSelection = sel;
      }
    };
    editorState.selectionNotifier.addListener(_selectionListener!);

    setState(() => _editorState = editorState);
  }

  /// 에디터 변경 내용을 일정 시간 동안 모아서 저장합니다.
  ///
  /// 너무 자주 저장하지 않도록 디바운스를 적용합니다.
  void _onContentChanged() {
    if (_currentNote == null || _editorState == null) return;

    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      if (_currentNote == null || _editorState == null) return;
      final content = jsonEncode(_editorState!.document.toJson());
      final updated = _currentNote!.copyWith(
        title: _titleController.text,
        content: content,
      );
      ref.read(noteListProvider.notifier).saveNote(updated);
    });
  }

  /// 첨부 파일을 앱 지원 디렉토리로 복사합니다.
  ///
  /// 동일 파일명이 존재할 경우 충돌을 피하기 위해 이름을 변경합니다.
  Future<String> _copyToAppDir(String srcPath) async {
    final appDir = await getApplicationSupportDirectory();
    final attachDir = Directory(
      path.join(appDir.path, 'Attachments', _currentNote!.id.toString()),
    );
    await attachDir.create(recursive: true);

    final fileName = path.basename(srcPath);
    var destPath = path.join(attachDir.path, fileName);

    if (File(destPath).existsSync()) {
      final ext = path.extension(fileName);
      final name = path.basenameWithoutExtension(fileName);
      destPath = path.join(
        attachDir.path,
        '${name}_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
    }

    await File(srcPath).copy(destPath);
    return destPath;
  }

  /// 선택된 문단의 텍스트 정렬 속성을 변경합니다.
  void _setTextAlign(String align) {
    final editorState = _editorState;
    if (editorState == null) return;

    final selection = editorState.selection;
    if (selection == null) return;

    final node = editorState.getNodeAtPath(selection.end.path);
    if (node == null) return;

    final transaction = editorState.transaction;
    transaction.updateNode(node, {
      ...node.attributes,
      'align': align,
    }); // text_align → align
    editorState.apply(transaction);
  }

  /// 현재 커서 위치 바로 다음에 새 노드를 삽입합니다.
  void _insertAtCursor(Node node) {
    final editorState = _editorState;
    if (editorState == null) return;

    final selection = editorState.selection;
    final insertPath = selection != null
        ? selection.end.path.next
        : [editorState.document.root.children.length];

    final transaction = editorState.transaction;
    transaction.insertNode(insertPath, node);
    editorState.apply(transaction);
  }

  /// 파일을 앱 디렉토리로 복사하고 해당 파일 또는 이미지를 에디터에 삽입합니다.
  Future<void> _processFile(String srcPath) async {
    if (_currentNote == null) return;
    final destPath = await _copyToAppDir(srcPath);
    final fileName = path.basename(destPath);

    if (_isImage(destPath)) {
      _insertAtCursor(localImageNode(src: destPath));
    } else {
      _insertAtCursor(localFileNode(src: destPath, fileName: fileName));
    }
  }

  /// 사용자가 선택한 파일을 첨부하고 에디터에 삽입합니다.
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    for (final file in result.files) {
      if (file.path != null) await _processFile(file.path!);
    }
  }

  /// 현재 메모를 PDF로 내보냅니다.
  Future<void> _exportToPdf() async {
    if (_currentNote == null || _editorState == null) return;

    try {
      final tags = await ref
          .read(noteRepositoryProvider)
          .getNoteTags(_currentNote!.id!);
      final service = PdfExportService();
      await service.exportToPdf(
        editorState: _editorState!,
        title: _currentNote!.title,
        tags: tags,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF 내보내기 실패: $e')));
    }
  }

  /// 태그 편집 다이얼로그를 열고 메모 태그를 갱신합니다.
  Future<void> _showTagDialog() async {
    if (_currentNote == null) return;

    final repo = ref.read(noteRepositoryProvider);
    final currentTags = await repo.getNoteTags(_currentNote!.id!);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => MemoEditorTagDialog(
        noteId: _currentNote!.id!,
        initialTags: currentTags,
      ),
    );

    // 다이얼로그 닫힌 후 메모 갱신
    ref.read(noteListProvider.notifier).refresh();
  }

  /// 드래그 앤 드롭으로 들어온 파일을 처리합니다.
  Future<void> _handleDrop(DropDoneDetails details) async {
    for (final file in details.files) {
      await _processFile(file.path);
    }
  }

  late final _moveUpHandler = CommandShortcutEvent(
    key: 'move block up',
    getDescription: () => 'Move block up',
    command: 'alt+arrow up',
    handler: (editorState) {
      final selection = editorState.selection;
      if (selection == null) return KeyEventResult.ignored;

      final path = selection.end.path;
      if (path.isEmpty || path.last <= 0) return KeyEventResult.ignored;

      final node = editorState.getNodeAtPath(path);
      if (node == null) return KeyEventResult.ignored;

      final prevPath = [...path.sublist(0, path.length - 1), path.last - 1];
      final prevNode = editorState.getNodeAtPath(prevPath);
      if (prevNode == null) return KeyEventResult.ignored;

      final transaction = editorState.transaction;
      transaction.moveNode(prevPath, node);
      editorState.apply(transaction);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        editorState.selection = Selection.collapsed(
          Position(path: prevPath, offset: 0),
        );
      });

      return KeyEventResult.handled;
    },
  );

  late final _moveDownHandler = CommandShortcutEvent(
    key: 'move block down',
    getDescription: () => 'Move block down',
    command: 'alt+arrow down',
    handler: (editorState) {
      final selection = editorState.selection;
      if (selection == null) return KeyEventResult.ignored;

      final path = selection.end.path;
      final node = editorState.getNodeAtPath(path);
      if (node == null) return KeyEventResult.ignored;

      final childCount = editorState.document.root.children.length;
      if (path.last >= childCount - 1) return KeyEventResult.ignored;

      final nextNextPath = [...path.sublist(0, path.length - 1), path.last + 2];
      final newPath = [...path.sublist(0, path.length - 1), path.last + 1];

      final transaction = editorState.transaction;
      transaction.moveNode(nextNextPath, node);
      editorState.apply(transaction);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        editorState.selection = Selection.collapsed(
          Position(path: newPath, offset: 0),
        );
      });

      return KeyEventResult.handled;
    },
  );

  late final _deleteHandler = CommandShortcutEvent(
    key: 'delete local block forward',
    getDescription: () => 'Delete local block with confirmation (forward)',
    command: 'delete',
    handler: (editorState) {
      final selection = editorState.selection;
      if (selection == null) return KeyEventResult.ignored;

      // del키는 커서 오른쪽 블록을 삭제하므로 next path 확인
      final nextPath = selection.end.path.next;
      final node =
          editorState.getNodeAtPath(nextPath) ??
          editorState.getNodeAtPath(selection.end.path);
      if (node == null) return KeyEventResult.ignored;

      if (node.type != localImageType && node.type != localFileType) {
        return KeyEventResult.ignored;
      }

      _showDeleteDialog(editorState, node);
      return KeyEventResult.handled;
    },
  );
  // Backspace 핸들러 — local_image / local_file 블록일 때 삭제 다이얼로그
  void _handlePasteImage(EditorState editorState) async {
    // 1. 먼저 이미지 바이트 확인 (캡처 도구 등)
    final imageBytes = await Pasteboard.image;
    if (imageBytes != null) {
      // 임시 파일로 저장
      final appDir = await getApplicationSupportDirectory();
      final tempDir = Directory('${appDir.path}\\Temp');
      await tempDir.create(recursive: true);
      final tempFile = File(
        '${tempDir.path}\\paste_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(imageBytes);
      _insertAtCursor(localImageNode(src: tempFile.path));
      return;
    }

    // 2. 텍스트 경로 확인 (파일 경로 복사)
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text == null) return;

    final imagePath = clipboardData!.text!.trim();
    if (!_isImage(imagePath)) return;

    final file = File(imagePath);
    if (!file.existsSync()) return;

    final selection = editorState.selection;
    if (selection == null) return;

    final pathNode = editorState.getNodeAtPath(selection.end.path);
    if (pathNode != null && pathNode.type == 'paragraph') {
      final transaction = editorState.transaction;
      transaction.deleteNode(pathNode);
      transaction.insertNode(
        selection.end.path,
        localImageNode(src: imagePath),
      );
      transaction.insertNode([
        ...selection.end.path.sublist(0, selection.end.path.length - 1),
        selection.end.path.last + 1,
      ], Node(type: 'paragraph'));
      editorState.apply(transaction);
    }
  }

  late final _pasteHandler = CommandShortcutEvent(
    key: 'paste local image',
    getDescription: () => 'Paste local image from clipboard',
    command: 'ctrl+v',
    handler: (editorState) {
      // 코드 블록 편집 중이면 TextField가 처리하도록 통과
      final selection = editorState.selection;
      if (selection != null) {
        final node = editorState.getNodeAtPath(selection.end.path);
        if (node?.type == localCodeType) {
          return KeyEventResult.ignored;
        }
      }

      // 이미지/텍스트 처리
      _handlePasteImage(editorState);
      return KeyEventResult.ignored;
    },
  );

  late final _alignLeftHandler = CommandShortcutEvent(
    key: 'align left',
    getDescription: () => 'Align left',
    command: 'ctrl+shift+l',
    handler: (editorState) {
      _setTextAlign('left');
      return KeyEventResult.handled;
    },
  );

  late final _alignCenterHandler = CommandShortcutEvent(
    key: 'align center',
    getDescription: () => 'Align center',
    command: 'ctrl+shift+c',
    handler: (editorState) {
      _setTextAlign('center');
      return KeyEventResult.handled;
    },
  );

  late final _alignRightHandler = CommandShortcutEvent(
    key: 'align right',
    getDescription: () => 'Align right',
    command: 'ctrl+shift+r',
    handler: (editorState) {
      _setTextAlign('right');
      return KeyEventResult.handled;
    },
  );

  late final _backspaceHandler = CommandShortcutEvent(
    key: 'delete local block',
    getDescription: () => 'Delete local block with confirmation',
    command: 'backspace',
    handler: (editorState) {
      final selection = editorState.selection;
      if (selection == null) return KeyEventResult.ignored;

      final node = editorState.getNodeAtPath(selection.end.path);
      if (node == null) return KeyEventResult.ignored;

      if (node.type != localImageType && node.type != localFileType) {
        return KeyEventResult.ignored;
      }

      // 다이얼로그는 BuildContext 필요 — 위젯 내부에서 처리
      // 해당 블록 위젯의 GlobalKey를 통해 호출하는 대신
      // 여기서 직접 다이얼로그 띄움
      _showDeleteDialog(editorState, node);
      return KeyEventResult.handled;
    },
  );

  /// 이미지 또는 파일 블록 삭제 여부를 사용자에게 확인합니다.
  Future<void> _showDeleteDialog(EditorState editorState, Node node) async {
    final isImage = node.type == localImageType;
    final label = isImage
        ? '이미지'
        : (node.attributes['fileName'] as String? ?? '파일');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label 삭제'),
        content: Text('$label 를 삭제할까요?'),
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
      transaction.deleteNode(node);
      editorState.apply(transaction);
    }
  }

  late final Map<String, BlockComponentBuilder> _blockBuilders;

  /// 블록 액션 바에 보이는 추가 / 드래그 핸들 버튼을 만듭니다.
  Widget _buildBlockAction(
    BlockComponentContext blockComponentContext,
    BlockComponentActionState state,
  ) {
    final editorState = _editorState;
    if (editorState == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // + 버튼
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => insertNodeAfterSelection(editorState, paragraphNode()),
            child: const Icon(Icons.add, size: 18, color: Colors.grey),
          ),
        ),
        const SizedBox(width: 4),
        // 드래그 핸들
        MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Draggable<Node>(
            data: blockComponentContext.node,
            onDragUpdate: (details) {
              editorState.service.selectionService.renderDropTargetForOffset(
                details.globalPosition,
              );
            },
            onDragEnd: (details) {
              editorState.service.selectionService.removeDropTarget();
              final renderData = editorState.service.selectionService
                  .getDropTargetRenderData(details.offset);

              if (renderData == null) return;

              var dropPath = renderData.dropPath!;
              final node = blockComponentContext.node;

              if (dropPath == node.path || dropPath == node.path.next) return;

              if (dropPath.first > node.path.first) {
                dropPath = [dropPath.first + 1];
              }
              final transaction = editorState.transaction;
              transaction.moveNode(dropPath, node);
              editorState.apply(transaction);
            },
            feedback: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: Colors.white,
                child: const Icon(Icons.drag_indicator, size: 16),
              ),
            ),
            child: const Icon(
              Icons.drag_indicator,
              size: 18,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();

    T applyAction<T extends BlockComponentBuilder>(T builder) {
      builder.showActions = (_) => true;
      builder.actionBuilder = _buildBlockAction;
      return builder;
    }

    _blockBuilders = {
      ...standardBlockComponentBuilderMap.map(
        (key, value) => MapEntry(key, applyAction(value)),
      ),
      localImageType: applyAction(LocalImageBlockComponentBuilder()),
      localFileType: applyAction(LocalFileBlockComponentBuilder()),
      localLocationType: applyAction(LocalLocationBlockComponentBuilder()),
      localCodeType: applyAction(LocalCodeBlockComponentBuilder()),
      _toggleListType: applyAction(ToggleListBlockComponentBuilder()),
    };
  }

  @override
  Widget build(BuildContext context) {
    final selectedNote = ref.watch(selectedNoteProvider);
    final notes = ref.watch(noteListProvider).value ?? [];

    // 항상 최신 상태로 동기화
    if (selectedNote != null) {
      final freshNote = notes.firstWhere(
        (n) => n.id == selectedNote.id,
        orElse: () => selectedNote,
      );
      if (freshNote.id != _currentNote?.id) {
        _currentNote = freshNote;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initEditor(freshNote);
        });
      } else {
        _currentNote = freshNote;
      }
    }

    if (selectedNote == null) {
      return const Center(
        child: Text(
          '메모를 선택하세요',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    if (_editorState == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final standardPaste = standardCommandShortcutEvents
        .where(
          (e) =>
              e.key != 'paste the content' &&
              e.key != 'paste the content as plain text',
        )
        .toList();

    final shortcutEvents = [
      ..._buildColorShortcutEvents(),
      _pasteHandler,
      _backspaceHandler,
      _deleteHandler,
      _moveUpHandler,
      _moveDownHandler,
      ...standardPaste,
      pasteCommand, // 표준 붙여넣기 다시 추가
      pasteTextWithoutFormattingCommand,
      _alignLeftHandler,
      _alignCenterHandler,
      _alignRightHandler,
    ];

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        await _handleDrop(details);
      },
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleController,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: '제목 없음',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                        onChanged: (_) => _onContentChanged(),
                      ),
                    ),
                    // 토글 버튼들
                    if (_currentNote != null) ...[
                      _buildToggleButton(
                        icon: Icons.star,
                        activeColor: Colors.amber,
                        isActive: _currentNote!.isFavorite,
                        tooltip: _currentNote!.isFavorite ? '즐겨찾기 해제' : '즐겨찾기',
                        onTap: () => ref
                            .read(noteListProvider.notifier)
                            .toggleFavorite(
                              _currentNote!.id!,
                              !_currentNote!.isFavorite,
                            ),
                      ),
                      const SizedBox(width: 4),
                      _buildToggleButton(
                        icon: Icons.push_pin,
                        activeColor: const Color(0xFF4A90E2),
                        isActive: _currentNote!.isPinned,
                        tooltip: _currentNote!.isPinned ? '고정 해제' : '고정',
                        onTap: () => ref
                            .read(noteListProvider.notifier)
                            .togglePin(
                              _currentNote!.id!,
                              !_currentNote!.isPinned,
                            ),
                      ),
                      const SizedBox(width: 4),
                      _buildToggleButton(
                        icon: Icons.priority_high,
                        activeColor: Colors.orange,
                        isActive: _currentNote!.isImportant,
                        tooltip: _currentNote!.isImportant ? '중요 해제' : '중요',
                        onTap: () => ref
                            .read(noteListProvider.notifier)
                            .toggleImportant(
                              _currentNote!.id!,
                              !_currentNote!.isImportant,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_currentNote != null)
                FutureBuilder<List<String>>(
                  future: ref
                      .read(noteRepositoryProvider)
                      .getNoteTags(_currentNote!.id!),
                  builder: (context, snapshot) {
                    final tags = snapshot.data ?? [];
                    if (tags.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F0FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '#$tag',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF4A90E2),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              const Divider(height: 1, color: Color(0xFFDDDDDD)),
              const SizedBox(height: 24), // 제목 <-> 내용 간격
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AppFlowyEditor(
                    editorState: _editorState!,
                    editorStyle: const EditorStyle.desktop(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    blockComponentBuilders: _blockBuilders,
                    commandShortcutEvents: shortcutEvents,
                    characterShortcutEvents: [
                      customSlashCommand([
                        ...standardSelectionMenuItems.where(
                          (e) => !e.keywords.contains('image'),
                        ),
                        _locationMenuItem,
                        _codeMenuItem,
                        _fileMenuItem,
                      ]),
                      ...standardCharacterShortcutEvents.where(
                        (e) => e.key != 'show the slash menu',
                      ),
                    ],
                  ),
                ),
              ),
              // 하단 툴바
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFDDDDDD))),
                ),
                child: Row(
                  children: [
                    // 툴바 토글 버튼
                    IconButton(
                      icon: Icon(
                        _isToolbarExpanded
                            ? Icons.expand_more
                            : Icons.expand_less,
                        size: 18,
                      ),
                      tooltip: _isToolbarExpanded ? '툴바 접기' : '툴바 펼치기',
                      onPressed: () => setState(
                        () => _isToolbarExpanded = !_isToolbarExpanded,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    if (_isToolbarExpanded) ...[
                      const SizedBox(width: 8),
                      // 파일 첨부
                      IconButton(
                        icon: const Icon(Icons.attach_file, size: 18),
                        tooltip: '파일 첨부',
                        onPressed: _pickFile,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      // 정렬 드롭다운
                      MemoEditorAlignDropdown(onAlign: _setTextAlign),
                      const SizedBox(width: 8),
                      // Bold
                      _buildFormatButton(
                        icon: Icons.format_bold,
                        tooltip: '굵게',
                        onTap: () => _toggleFormat('bold'),
                      ),
                      const SizedBox(width: 4),
                      // Italic
                      _buildFormatButton(
                        icon: Icons.format_italic,
                        tooltip: '기울임',
                        onTap: () => _toggleFormat('italic'),
                      ),
                      const SizedBox(width: 4),
                      // Underline
                      _buildFormatButton(
                        icon: Icons.format_underline,
                        tooltip: '밑줄',
                        onTap: () => _toggleFormat('underline'),
                      ),
                      const SizedBox(width: 4),
                      // Strikethrough
                      _buildFormatButton(
                        icon: Icons.format_strikethrough,
                        tooltip: '취소선',
                        onTap: () => _toggleFormat('strikethrough'),
                      ),
                      const SizedBox(width: 8),
                      // 텍스트 색상
                      MemoEditorColorDropdown(
                        tooltip: '글자색',
                        icon: Icons.format_color_text,
                        onOpen: () => _lastSelection = _editorState?.selection,
                        onColorSelected: (color) => _applyColor('color', color),
                      ),
                      const SizedBox(width: 4),
                      // 하이라이트
                      MemoEditorColorDropdown(
                        tooltip: '하이라이트',
                        icon: Icons.highlight,
                        onOpen: () => _lastSelection = _editorState?.selection,
                        onColorSelected: (color) =>
                            _applyColor('backgroundColor', color),
                      ),
                      const SizedBox(width: 8),
                      // 위첨자
                      _buildFormatButton(
                        icon: Icons.superscript,
                        tooltip: '위첨자',
                        onTap: () => _toggleFormat('sup'),
                      ),
                      const SizedBox(width: 4),
                      // 아래첨자
                      _buildFormatButton(
                        icon: Icons.subscript,
                        tooltip: '아래첨자',
                        onTap: () => _toggleFormat('subScript'),
                      ),
                      const SizedBox(width: 8),
                      // 접을 수 있는 섹션
                      _buildFormatButton(
                        icon: Icons.unfold_less,
                        tooltip: '접기 섹션',
                        onTap: _insertCollapsibleSection,
                      ),
                      const SizedBox(width: 8),
                      // 태그
                      IconButton(
                        icon: const Icon(Icons.label_outline, size: 18),
                        tooltip: '태그',
                        onPressed: () => _showTagDialog(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      // PDF
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        tooltip: 'PDF 내보내기',
                        onPressed: _exportToPdf,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                    const Spacer(),
                    const Text(
                      '저장됨',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isDragging)
            Container(
              decoration: BoxDecoration(
                color: const Color.fromRGBO(74, 144, 226, 0.1),
                border: Border.all(color: const Color(0xFF4A90E2), width: 2),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_file, size: 48, color: Color(0xFF4A90E2)),
                    SizedBox(height: 8),
                    Text(
                      '파일을 여기에 놓으세요',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF4A90E2),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 접을 수 있는 섹션 토글 블록을 에디터에 삽입합니다.
  void _insertCollapsibleSection() {
    final editorState = _editorState;
    if (editorState == null) return;

    final selection = editorState.selection;
    final insertPath = selection != null
        ? selection.end.path.next
        : [editorState.document.root.children.length];

    final transaction = editorState.transaction;
    transaction.insertNode(
      insertPath,
      Node(
        type: 'toggle_list',
        attributes: {
          'collapsed': false,
          'delta': [
            {'insert': '섹션 제목'},
          ],
        },
        children: [
          Node(
            type: 'paragraph',
            attributes: {
              'delta': [
                {'insert': ''},
              ],
            },
          ),
        ],
      ),
    );
    editorState.apply(transaction);
  }

  /// 선택 영역 텍스트에 컬러 속성을 적용합니다.
  ///
  /// [attribute]는 'color' 또는 'backgroundColor'를 전달합니다.
  void _applyColor(String attribute, Color color) {
    final editorState = _editorState;
    if (editorState == null) return;

    // 저장된 selection 사용
    final selection = _lastSelection ?? editorState.selection;
    if (selection == null || selection.isCollapsed) return;

    final colorHex =
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

    final attributeKey = attribute == 'color'
        ? AppFlowyRichTextKeys.textColor
        : AppFlowyRichTextKeys.backgroundColor;

    // 메뉴 상호작용 중에 에디터의 현재 선택 영역이 풀릴 수 있으므로,
    // 저장한 선택 영역을 다시 설정합니다.
    if (editorState.selection != selection) {
      editorState.selection = selection;
    }

    final nodes = editorState.getNodesInSelection(selection);
    final transaction = editorState.transaction;

    for (final node in nodes) {
      final delta = node.delta;
      if (delta == null) continue;

      final startIndex = node.path == selection.start.path
          ? selection.start.offset
          : 0;
      final endIndex = node.path == selection.end.path
          ? selection.end.offset
          : delta.length;

      transaction.formatText(node, startIndex, endIndex - startIndex, {
        attributeKey: colorHex,
      });
    }
    editorState.apply(transaction);
  }

  /// 선택 영역의 텍스트 서식을 토글합니다.
  void _toggleFormat(String format) {
    final editorState = _editorState;
    if (editorState == null) return;

    final selection = editorState.selection;
    if (selection == null || selection.isCollapsed) return;

    final nodes = editorState.getNodesInSelection(selection);
    final isFormatted = nodes.every((node) {
      final delta = node.delta;
      if (delta == null) return false;
      return delta.everyAttributes((attrs) => attrs[format] == true);
    });

    final transaction = editorState.transaction;
    for (final node in nodes) {
      final delta = node.delta;
      if (delta == null) continue;

      final startIndex = node.path == selection.start.path
          ? selection.start.offset
          : 0;
      final endIndex = node.path == selection.end.path
          ? selection.end.offset
          : delta.length;

      transaction.formatText(node, startIndex, endIndex - startIndex, {
        format: !isFormatted,
      });
    }
    editorState.apply(transaction);
  }

  /// 텍스트 편집기 상단 상태 토글 버튼을 생성합니다.
  Widget _buildToggleButton({
    required IconData icon,
    required Color activeColor,
    required bool isActive,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isActive
                ? Color.fromRGBO(
                    (activeColor.r * 255).round(),
                    (activeColor.g * 255).round(),
                    (activeColor.b * 255).round(),
                    0.1,
                  )
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? activeColor : Colors.grey,
          ),
        ),
      ),
    );
  }
}
