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
import 'package:pasteboard/pasteboard.dart';

class MemoEditorView extends ConsumerStatefulWidget {
  const MemoEditorView({super.key});

  @override
  ConsumerState<MemoEditorView> createState() => _MemoEditorViewState();
}

class _MemoEditorViewState extends ConsumerState<MemoEditorView> {
  Selection? _lastSelection;
  EditorState? _editorState;
  Note? _currentNote;
  final _titleController = TextEditingController();
  bool _isDragging = false;

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
    editorState.selectionNotifier.addListener(() {
      final sel = editorState.selection;
      if (sel != null) _lastSelection = sel;
    });
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

    final selection = editorState.selection ?? _lastSelection;
    if (selection == null) return;

    final nodes = editorState.getNodesInSelection(selection);
    if (nodes.isEmpty) return;

    final transaction = editorState.transaction;
    for (final node in nodes) {
      transaction.updateNode(node, {
        ...node.attributes,
        'align': align, // text_align → align
      });
    }
    transaction.afterSelection = selection;
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

    // 삽입한 노드 바로 이전 path로 selection 복원
    WidgetsBinding.instance.addPostFrameCallback((_) {
      editorState.selection = Selection.collapsed(
        Position(path: selection?.end.path ?? insertPath, offset: 0),
      );
    });
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

  void _handlePasteImage(EditorState editorState, Uint8List imageBytes) async {
    if (_currentNote == null) return;

    final appDir = await getApplicationSupportDirectory();
    final tempPath =
        '${appDir.path}\\temp_${DateTime.now().millisecondsSinceEpoch}.png';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(imageBytes);

    final destPath = await _copyToAppDir(tempPath);
    await tempFile.delete();

    final selection = editorState.selection;
    if (selection == null) return;

    final path = selection.end.path;
    final transaction = editorState.transaction;
    transaction.insertNode(path.next, localImageNode(src: destPath));
    editorState.apply(transaction);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      editorState.selection = Selection.collapsed(
        Position(path: path, offset: 0),
      );
    });
  }

  late final _pasteHandler = CommandShortcutEvent(
    key: 'paste local image',
    getDescription: () => 'Paste image or text',
    command: 'ctrl+v',
    handler: (editorState) {
      Pasteboard.image.then((imageBytes) {
        if (imageBytes != null) {
          _handlePasteImage(editorState, imageBytes);
        }
      });
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

  @override
  void initState() {
    super.initState();
    _blockBuilders = {
      ...standardBlockComponentBuilderMap,
      'image': LocalImageBlockComponentBuilder(),
      localImageType: LocalImageBlockComponentBuilder(),
      localFileType: LocalFileBlockComponentBuilder(),
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
        .where((e) => e.command != 'ctrl+v')
        .toList();

    final shortcutEvents = [
      _pasteHandler,
      _backspaceHandler,
      _deleteHandler,
      _moveUpHandler,
      _moveDownHandler,
      _alignLeftHandler,
      _alignCenterHandler,
      _alignRightHandler,
      ...standardPaste,
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
                    characterShortcutEvents: standardCharacterShortcutEvents,
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
