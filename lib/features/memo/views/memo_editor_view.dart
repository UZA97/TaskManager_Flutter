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
import '../../map/model/search_type.dart';
import '../../map/widgets/location_search_dialog.dart';
import 'package:pasteboard/pasteboard.dart';

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
  Selection? _lastSelection;

  SelectionMenuItem get _locationMenuItem => SelectionMenuItem(
    getName: () => '위치',
    icon: (editorState, onSelected, style) =>
        const Icon(Icons.location_pin, color: Color(0xFFE53935), size: 18),
    keywords: ['위치', 'location', 'map', '지도'],
    handler: (editorState, menuService, context) {
      menuService.dismiss();
      _showLocationSearchDialog(editorState);
    },
  );

  SelectionMenuItem get _codeMenuItem => SelectionMenuItem(
    getName: () => '코드',
    icon: (editorState, isSelected, style) =>
        const Icon(Icons.code, size: 18, color: Colors.grey),
    keywords: ['코드', 'code', '코드블록'],
    handler: (editorState, _, __) {
      insertNodeAfterSelection(editorState, localCodeNode());
    },
  );

  SelectionMenuItem get _fileMenuItem => SelectionMenuItem(
    getName: () => '파일',
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
    _titleController.dispose();
    super.dispose();
  }

  void _initEditor(Note note) {
    _titleController.text = note.title;

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
    editorState.transactionStream.listen((_) => _onContentChanged());
    setState(() => _editorState = editorState);
  }

  void _onContentChanged() {
    if (_currentNote == null || _editorState == null) return;

    final content = jsonEncode(_editorState!.document.toJson());
    final updated = _currentNote!.copyWith(
      title: _titleController.text,
      content: content,
    );
    ref.read(noteListProvider.notifier).saveNote(updated);
  }

  Future<String> _copyToAppDir(String srcPath) async {
    final appDir = await getApplicationSupportDirectory();
    final attachDir = Directory(
      '${appDir.path}\\Attachments\\${_currentNote!.id}',
    );
    await attachDir.create(recursive: true);

    final fileName = path.basename(srcPath);
    String destPath = '${attachDir.path}\\$fileName';

    if (File(destPath).existsSync()) {
      final ext = path.extension(fileName);
      final name = path.basenameWithoutExtension(fileName);
      destPath =
          '${attachDir.path}\\${name}_${DateTime.now().millisecondsSinceEpoch}$ext';
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
      print('align left 실행됨'); // ← 추가
      _setTextAlign('left');
      return KeyEventResult.handled;
    },
  );

  late final _alignCenterHandler = CommandShortcutEvent(
    key: 'align center',
    getDescription: () => 'Align center',
    command: 'ctrl+shift+c',
    handler: (editorState) {
      print('align center 실행됨'); // ← 추가
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

    final imageBuilder = LocalImageBlockComponentBuilder();
    imageBuilder.showActions = (_) => true;
    imageBuilder.actionBuilder = _buildBlockAction;

    final fileBuilder = LocalFileBlockComponentBuilder();
    fileBuilder.showActions = (_) => true;
    fileBuilder.actionBuilder = _buildBlockAction;

    final locationBuilder = LocalLocationBlockComponentBuilder();
    locationBuilder.showActions = (_) => true;
    locationBuilder.actionBuilder = _buildBlockAction;

    final codeBuilder = LocalCodeBlockComponentBuilder();
    codeBuilder.showActions = (_) => true;
    codeBuilder.actionBuilder = _buildBlockAction;

    _blockBuilders = {
      ...standardBlockComponentBuilderMap.map((key, value) {
        value.showActions = (_) => true;
        value.actionBuilder = _buildBlockAction;
        return MapEntry(key, value);
      }),
      localImageType: imageBuilder,
      localFileType: fileBuilder,
      localLocationType: locationBuilder,
      localCodeType: codeBuilder,
    };
  }

  @override
  Widget build(BuildContext context) {
    final selectedNote = ref.watch(selectedNoteProvider);

    if (selectedNote != null && selectedNote.id != _currentNote?.id) {
      _currentNote = selectedNote;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initEditor(selectedNote);
      });
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
              const Divider(height: 1, color: Color(0xFFDDDDDD)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AppFlowyEditor(
                    editorState: _editorState!,
                    editorStyle: const EditorStyle.desktop(),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFDDDDDD))),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file, size: 18),
                      tooltip: '파일 첨부',
                      onPressed: _pickFile,
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.format_align_left, size: 18),
                      tooltip: '왼쪽 정렬',
                      onPressed: () => _setTextAlign('left'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_align_center, size: 18),
                      tooltip: '가운데 정렬',
                      onPressed: () => _setTextAlign('center'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.format_align_right, size: 18),
                      tooltip: '우측 정렬',
                      onPressed: () => _setTextAlign('right'),
                    ),
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
                color: const Color(0xFF4A90E2).withOpacity(0.1),
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
}

class _LocationSearchDialogState extends State<LocationSearchDialog> {
  final _searchController = TextEditingController();
  List<VworldSearchResult> _results = [];
  bool _isLoading = false;
  String? _error;
  SearchType _searchType = SearchType.place;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _results = [];
    });

    try {
      final service = VworldService();
      final results = _searchType == SearchType.place
          ? await service.search(query)
          : await service.searchAddress(query);
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '검색 실패: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            // 헤더
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '위치 검색',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            // 검색창
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '장소 또는 주소 검색',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    onPressed: _search,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  isDense: true,
                ),
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(height: 8),

            // 토글
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<SearchType>(
                segments: const [
                  ButtonSegment(
                    value: SearchType.place,
                    label: Text('장소', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.place, size: 14),
                  ),
                  ButtonSegment(
                    value: SearchType.address,
                    label: Text('주소', style: TextStyle(fontSize: 12)),
                    icon: Icon(Icons.home, size: 14),
                  ),
                ],
                selected: {_searchType},
                onSelectionChanged: (value) {
                  setState(() {
                    _searchType = value.first;
                    _results = [];
                  });
                },
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ),
            const SizedBox(height: 8),

            // 결과 목록
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : _results.isEmpty
                  ? const Center(
                      child: Text(
                        '장소를 검색하세요',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.place,
                            size: 16,
                            color: Colors.grey,
                          ),
                          title: Text(
                            result.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            result.address,
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.pop(context, result),
                        );
                      },
                    ),
            ),

            // 취소 버튼
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
