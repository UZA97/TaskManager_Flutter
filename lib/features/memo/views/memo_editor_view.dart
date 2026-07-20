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
import '../widgets/collapsible_section_block.dart';
import '../../map/services/vworld_service.dart';
import '../../map/widgets/location_search_dialog.dart';
import 'package:pasteboard/pasteboard.dart';
import '../data/note_repository.dart';
import '../services/pdf_export_service.dart';
import 'memo_editor_widgets.dart';
import '../../../core/providers/navigation_provider.dart';
import 'package:appflowy_editor/src/editor/find_replace_menu/find_menu_service.dart';

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

  bool _isImage(String filePath) =>
      _imageExts.contains(path.extension(filePath).toLowerCase());

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

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    for (final file in result.files) {
      if (file.path != null) await _processFile(file.path!);
    }
  }

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

  Future<void> _handleDrop(DropDoneDetails details) async {
    for (final file in details.files) {
      await _processFile(file.path);
    }
  }

  FindReplaceService? _findReplaceService;
  late final _h1Handler = CommandShortcutEvent(
    key: 'heading 1',
    getDescription: () => 'Heading 1',
    command: 'ctrl+digit 1',
    handler: (editorState) {
      _toggleBlockType('heading', () => headingNode(level: 1));
      return KeyEventResult.handled;
    },
  );

  late final _h2Handler = CommandShortcutEvent(
    key: 'heading 2',
    getDescription: () => 'Heading 2',
    command: 'ctrl+digit 2',
    handler: (editorState) {
      _toggleBlockType('heading', () => headingNode(level: 2));
      return KeyEventResult.handled;
    },
  );

  late final _h3Handler = CommandShortcutEvent(
    key: 'heading 3',
    getDescription: () => 'Heading 3',
    command: 'ctrl+digit 3',
    handler: (editorState) {
      _toggleBlockType('heading', () => headingNode(level: 3));
      return KeyEventResult.handled;
    },
  );
  late final _findHandler = CommandShortcutEvent(
    key: 'show the find dialog',
    getDescription: () => 'Find',
    command: 'ctrl+f',
    handler: (editorState) {
      _findReplaceService = FindReplaceMenu(
        context: context,
        editorState: editorState,
        showReplaceMenu: false,
        localizations: FindReplaceLocalizations(
          find: '찾기',
          previousMatch: '이전',
          nextMatch: '다음',
          close: '닫기',
          replace: '바꾸기',
          replaceAll: '모두 바꾸기',
          noResult: '결과 없음',
        ),
        style: FindReplaceStyle(),
      );
      _findReplaceService?.show();
      return KeyEventResult.handled;
    },
  );

  late final _replaceHandler = CommandShortcutEvent(
    key: 'show the find and replace dialog',
    getDescription: () => 'Find and Replace',
    command: 'ctrl+h',
    handler: (editorState) {
      _findReplaceService = FindReplaceMenu(
        context: context,
        editorState: editorState,
        showReplaceMenu: true,
        style: FindReplaceStyle(),
      );
      _findReplaceService?.show();
      return KeyEventResult.handled;
    },
  );
  late final _bulletedListHandler = CommandShortcutEvent(
    key: 'bulleted list',
    getDescription: () => 'Bulleted List',
    command: 'ctrl+digit 4',
    handler: (editorState) {
      _toggleBlockType(BulletedListBlockKeys.type, () => bulletedListNode());
      return KeyEventResult.handled;
    },
  );
  late final _strikethroughHandler = CommandShortcutEvent(
    key: 'strikethrough',
    getDescription: () => 'Strikethrough',
    command: 'ctrl+shift+x',
    handler: (editorState) {
      _toggleFormat('strikethrough');
      return KeyEventResult.handled;
    },
  );
  late final _codeBlockHandler = CommandShortcutEvent(
    key: 'code block',
    getDescription: () => 'Code Block',
    command: 'ctrl+shift+c',
    handler: (editorState) {
      insertNodeAfterSelection(editorState, localCodeNode());
      return KeyEventResult.handled;
    },
  );
  late final _numberedListHandler = CommandShortcutEvent(
    key: 'numbered list',
    getDescription: () => 'Numbered List',
    command: 'ctrl+digit 5',
    handler: (editorState) {
      _toggleBlockType(NumberedListBlockKeys.type, () => numberedListNode());
      return KeyEventResult.handled;
    },
  );

  late final _checkboxHandler = CommandShortcutEvent(
    key: 'checkbox',
    getDescription: () => 'Checkbox',
    command: 'ctrl+digit 6',
    handler: (editorState) {
      _toggleBlockType(
        TodoListBlockKeys.type,
        () => todoListNode(checked: false),
      );
      return KeyEventResult.handled;
    },
  );

  late final _dividerHandler = CommandShortcutEvent(
    key: 'divider',
    getDescription: () => 'Divider',
    command: 'ctrl+shift+h',
    handler: (editorState) {
      insertNodeAfterSelection(editorState, dividerNode());
      return KeyEventResult.handled;
    },
  );
  void _toggleBlockType(
    String blockType,
    Node Function() nodeBuilder, {
    int? headingLevel,
  }) {
    final editorState = _editorState;
    if (editorState == null) return;

    final selection = editorState.selection;
    if (selection == null) return;

    final nodes = editorState.getNodesInSelection(selection);
    if (nodes.isEmpty) return;

    final allSameType = nodes.every(
      (n) =>
          n.type == blockType &&
          (headingLevel == null || n.attributes['level'] == headingLevel),
    );

    final transaction = editorState.transaction;
    for (final node in nodes) {
      if (allSameType) {
        transaction.insertNode(
          node.path,
          paragraphNode(delta: node.delta ?? Delta()),
        );
        transaction.deleteNode(node);
      } else {
        final newNode = nodeBuilder();
        transaction.insertNode(
          node.path,
          Node(
            type: newNode.type,
            attributes: {
              ...newNode.attributes,
              'delta': node.delta?.toJson() ?? [],
            },
          ),
        );
        transaction.deleteNode(node);
      }
    }
    editorState.apply(transaction);

    // selection 복원
    WidgetsBinding.instance.addPostFrameCallback((_) {
      editorState.selection = selection;
    });
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

  late final List<CommandShortcutEvent> _textColorHandlers = List.generate(
    8,
    (index) => CommandShortcutEvent(
      key: 'text color ${index + 1}',
      getDescription: () => 'Text color ${index + 1}',
      command: 'alt+digit ${index + 1}',
      handler: (editorState) {
        final selection = editorState.selection;
        if (selection == null || selection.isCollapsed) {
          return KeyEventResult.ignored;
        }
        _lastSelection = selection;
        _applyColorToSelection(
          editorState,
          selection,
          AppFlowyRichTextKeys.textColor,
          _colorForIndex(index + 1),
        );
        return KeyEventResult.handled;
      },
    ),
  );

  late final List<CommandShortcutEvent> _highlightHandlers = List.generate(
    8,
    (index) => CommandShortcutEvent(
      key: 'highlight ${index + 1}',
      getDescription: () => 'Highlight ${index + 1}',
      command: 'alt+shift+digit ${index + 1}',
      handler: (editorState) {
        final selection = editorState.selection;
        if (selection == null || selection.isCollapsed) {
          return KeyEventResult.ignored;
        }
        _lastSelection = selection;
        _applyColorToSelection(
          editorState,
          selection,
          AppFlowyRichTextKeys.backgroundColor,
          _highlightColorForIndex(index + 1),
        );
        return KeyEventResult.handled;
      },
    ),
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
      collapsibleSectionType: applyAction(
        CollapsibleSectionBlockComponentBuilder(),
      ),
      localImageType: applyAction(LocalImageBlockComponentBuilder()),
      localFileType: applyAction(LocalFileBlockComponentBuilder()),
      localLocationType: applyAction(LocalLocationBlockComponentBuilder()),
      localCodeType: applyAction(LocalCodeBlockComponentBuilder()),
    };
  }

  @override
  Widget build(BuildContext context) {
    final selectedNote = ref.watch(selectedNoteProvider);
    final notes = ref.watch(noteListProvider).value ?? [];

    ref.listen(navigationProvider, (prev, next) {
      if (prev == 0 && next != 0) {
        _findReplaceService?.dismiss();
        _findReplaceService = null;
      }
    });

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
              e.key != 'paste the content as plain text' &&
              e.key != 'format the text to h1' &&
              e.key != 'format the text to h2' &&
              e.key != 'format the text to h3',
        )
        .toList();

    final shortcutEvents = [
      _findHandler,
      _replaceHandler,
      _strikethroughHandler,
      _h1Handler,
      _h2Handler,
      _h3Handler,
      _codeBlockHandler,
      _pasteHandler,
      _backspaceHandler,
      _deleteHandler,
      _moveUpHandler,
      _moveDownHandler,
      _numberedListHandler,
      _bulletedListHandler,
      _dividerHandler,
      _checkboxHandler,
      ...standardPaste,
      pasteCommand, // 표준 붙여넣기 다시 추가
      pasteTextWithoutFormattingCommand,
      ..._textColorHandlers,
      ..._highlightHandlers,
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
                      _buildToggleButton(
                        icon: Icons.search,
                        activeColor: const Color(0xFF4A90E2),
                        isActive: false,
                        tooltip: '찾기/바꾸기 [Ctrl+F]',
                        onTap: () {
                          openFindDialog(
                            context: context,
                            style: FindReplaceStyle(),
                          ).handler.call(_editorState!);
                        },
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
                      selectionColor: Color(0x6600B0FF),
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
                      const SizedBox(width: 4),
                      // 파일 첨부
                      IconButton(
                        icon: const Icon(Icons.attach_file, size: 18),
                        tooltip: '파일 첨부',
                        onPressed: _pickFile,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      // 정렬 드롭다운
                      MemoEditorAlignDropdown(onAlign: _setTextAlign),
                      // Bold
                      IconButton(
                        icon: const Icon(Icons.format_bold),
                        tooltip: '굵게 [Ctrl+B]',
                        onPressed: () => _toggleFormat('bold'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      // Italic
                      IconButton(
                        icon: const Icon(Icons.format_italic),
                        tooltip: '기울임 [Ctrl+I]',
                        onPressed: () => _toggleFormat('italic'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      // Underline
                      IconButton(
                        icon: const Icon(Icons.format_underline),
                        tooltip: '밑줄 [Ctrl+U]',
                        onPressed: () => _toggleFormat('underline'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      // Strikethrough
                      IconButton(
                        icon: const Icon(Icons.format_strikethrough),
                        tooltip: '취소선',
                        onPressed: () => _toggleFormat('strikethrough'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      // 텍스트 색상
                      MemoEditorColorDropdown(
                        tooltip: '글자색 [Alt+1~8]',
                        icon: Icons.format_color_text,
                        onOpen: () => _lastSelection = _editorState?.selection,
                        isHighlight: false,
                        onColorSelected: (color) {
                          final editorState = _editorState;
                          if (editorState == null) return;
                          final selection =
                              _lastSelection ?? editorState.selection;
                          if (selection == null || selection.isCollapsed)
                            return;
                          _applyColorToSelection(
                            editorState,
                            selection,
                            AppFlowyRichTextKeys.textColor,
                            color,
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      // 하이라이트
                      MemoEditorColorDropdown(
                        tooltip: '하이라이트 [Alt+↑+1~8]',
                        icon: Icons.highlight,
                        isHighlight: true,
                        onOpen: () => _lastSelection = _editorState?.selection,
                        onColorSelected: (color) {
                          final editorState = _editorState;
                          if (editorState == null) return;
                          final selection =
                              _lastSelection ?? editorState.selection;
                          if (selection == null || selection.isCollapsed)
                            return;
                          _applyColorToSelection(
                            editorState,
                            selection,
                            AppFlowyRichTextKeys.backgroundColor,
                            color,
                          );
                        },
                      ),
                      const SizedBox(width: 4),

                      IconButton(
                        icon: const Icon(Icons.format_list_bulleted),
                        tooltip: '불릿 목록 [Ctrl+4]',
                        padding: EdgeInsets.zero,
                        onPressed: () => _toggleBlockType(
                          BulletedListBlockKeys.type,
                          () => bulletedListNode(),
                        ),
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),

                      IconButton(
                        icon: const Icon(Icons.format_list_numbered),
                        tooltip: '번호 목록 [Ctrl+5]',
                        padding: EdgeInsets.zero,
                        onPressed: () => _toggleBlockType(
                          NumberedListBlockKeys.type,
                          () => numberedListNode(),
                        ),
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),

                      IconButton(
                        icon: const Icon(Icons.check_box_outline_blank),
                        tooltip: '체크박스 [Ctrl+6]',
                        padding: EdgeInsets.zero,
                        onPressed: () => _toggleBlockType(
                          TodoListBlockKeys.type,
                          () => todoListNode(checked: false),
                        ),
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),

                      IconButton(
                        icon: const Icon(Icons.horizontal_rule),
                        tooltip: '구분선 [Ctrl+Shift+H]',
                        padding: EdgeInsets.zero,
                        onPressed: () => _toggleBlockType(
                          DividerBlockKeys.type,
                          () => dividerNode(),
                        ),
                        constraints: const BoxConstraints(),
                      ),
                      // 위첨자
                      // IconButton(
                      //   icon: const Icon(Icons.superscript),
                      //   tooltip: '위첨자',
                      //   padding: EdgeInsets.zero,
                      //   onPressed: () => _toggleFormat('sup'),
                      //   constraints: const BoxConstraints(),
                      // ),
                      // const SizedBox(width: 4),
                      // // 아래첨자
                      // IconButton(
                      //   icon: const Icon(Icons.subscript),
                      //   tooltip: '위첨자',
                      //   padding: EdgeInsets.zero,
                      //   onPressed: () => _toggleFormat('subScript'),
                      //   constraints: const BoxConstraints(),
                      // ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.code),
                        tooltip: '코드 블록 [Ctrl+Shift+C]',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => {
                          if (_editorState != null)
                            insertNodeAfterSelection(
                              _editorState!,
                              localCodeNode(),
                            ),
                        },
                      ),
                      const SizedBox(width: 4),

                      // 접을 수 있는 섹션
                      IconButton(
                        icon: const Icon(Icons.unfold_less),
                        tooltip: '접기 섹션',
                        padding: EdgeInsets.zero,
                        onPressed: _insertCollapsibleSection,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      // 태그
                      IconButton(
                        icon: const Icon(Icons.label_outline),
                        tooltip: '태그',
                        padding: EdgeInsets.zero,
                        onPressed: () => _showTagDialog(),
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      // PDF
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf),
                        tooltip: 'PDF 내보내기',
                        padding: EdgeInsets.zero,
                        onPressed: _exportToPdf,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
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

  void _insertCollapsibleSection() {
    final editorState = _editorState;
    if (editorState == null) return;

    final selection = editorState.selection;
    final insertPath = selection != null
        ? selection.end.path.next
        : [editorState.document.root.children.length];

    final transaction = editorState.transaction;
    transaction.insertNode(insertPath, collapsibleSectionNode());
    editorState.apply(transaction);
  }

  Color _colorForIndex(int index) {
    const colors = [
      Color(0xFFE53935), // 1: 빨강
      Color(0xFFFF9800), // 2: 주황
      Color(0xFFFFEB3B), // 3: 노랑
      Color(0xFF4CAF50), // 4: 초록
      Color(0xFF2196F3), // 5: 파랑
      Color(0xFF3F51B5), // 6: 남색
      Color(0xFF9C27B0), // 7: 보라
      Color(0xFF9E9E9E), // 8: 회색
    ];
    if (index < 1 || index > 8) return const Color(0xFF000000);
    return colors[index - 1];
  }

  Color _highlightColorForIndex(int index) {
    const colors = [
      Color(0xFFFFCDD2), // 0: 빨강
      Color(0xFFFFE0B2), // 1: 주황
      Color(0xFFFFF9C4), // 2: 노랑
      Color(0xFFC8E6C9), // 3: 초록
      Color(0xFFBBDEFB), // 4: 파랑
      Color(0xFFC5CAE9), // 5: 남색
      Color(0xFFE1BEE7), // 6: 보라
      Color(0xFFF5F5F5), // 7: 회색
    ];
    if (index < 1 || index > 8) return const Color(0xFFFFFFFF);
    return colors[index - 1];
  }

  String _toColorHex(Color color) {
    return '0x${color.toARGB32().toRadixString(16).padLeft(8, '0').toLowerCase()}';
  }

  void _applyColorToSelection(
    EditorState editorState,
    Selection selection,
    String attributeKey,
    Color color,
  ) {
    // 현재 선택 영역의 색상 확인
    final nodes = editorState.getNodesInSelection(selection);
    final currentColorHex =
        nodes.firstOrNull?.delta
                ?.slice(selection.start.offset, selection.end.offset)
                .firstOrNull
                ?.attributes?[attributeKey]
            as String?;

    final newColorHex = _toColorHex(color);

    // 같은 색이면 해제, 다르면 적용
    final applyValue = currentColorHex == newColorHex ? null : newColorHex;

    editorState.formatDelta(selection, {attributeKey: applyValue});
  }

  void _toggleFormat(String format) {
    final editorState = _editorState;
    if (editorState == null) return;

    final selection = _lastSelection ?? editorState.selection;
    if (selection == null || selection.isCollapsed) return;

    editorState.selection = selection;

    final nodes = editorState.getNodesInSelection(selection);
    final isFormatted = nodes.every((node) {
      final delta = node.delta;
      if (delta == null) return false;
      final startIndex = node.path.equals(selection.start.path)
          ? selection.start.offset
          : 0;
      final endIndex = node.path.equals(selection.end.path)
          ? selection.end.offset
          : delta.length;
      final sliced = delta.slice(startIndex, endIndex);
      return sliced.everyAttributes((attrs) => attrs[format] == true);
    });

    editorState.formatDelta(selection, {format: !isFormatted});
  }

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

  //  탭 변경 감지
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }
}
