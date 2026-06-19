import 'dart:convert';
import 'dart:io';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';
import 'dart:async';

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
  StreamSubscription? _transactionSubscription;

  static const _imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];

// 클래스 레벨에 선언
  late final Map<String, BlockComponentBuilder> _blockBuilders;

  @override
  void initState() {
    super.initState();
    _blockBuilders = {
      ...standardBlockComponentBuilderMap,
    };
  }

  bool _isImage(String filePath) =>
      _imageExts.contains(path.extension(filePath).toLowerCase());

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    _editorState?.dispose(); // 추가
    _titleController.dispose();
    super.dispose();
  }

  void _initEditor(Note note) {
    _titleController.text = note.title;
    _transactionSubscription?.cancel();
    _editorState?.dispose(); // 추가 — 이전 editorState 정리

    final editorState = _createEditorState(note.content);
    _transactionSubscription = editorState.transactionStream.listen((_) {
      _onContentChanged();
    });

    setState(() => _editorState = editorState);
  }

  EditorState _createEditorState(String content) {
    if (content.trim().isNotEmpty) {
      // JSON 먼저 시도
      try {
        final json = jsonDecode(content);
        return EditorState(document: Document.fromJson(json));
      } catch (_) {}
      // 구버전 마크다운 호환
      try {
        return EditorState(document: markdownToDocument(content));
      } catch (_) {}
    }
    return EditorState.blank(withInitialText: true);
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

  void _insertAtCursor(Node node) {
    final editorState = _editorState;
    if (editorState == null) return;

    final selection = editorState.selection;
    final insertIndex = selection != null
        ? selection.end.path.last
        : editorState.document.root.children.length;

    final insertPath = [insertIndex + 1];
    final nextPath = [insertIndex + 2];

    final transaction = editorState.transaction;
    transaction.insertNode(insertPath, node);
    transaction.insertNode(nextPath, paragraphNode());
    editorState.apply(transaction);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        editorState.updateSelectionWithReason(
          Selection.collapsed(Position(path: nextPath, offset: 0)),
          reason: SelectionUpdateReason.uiEvent,
        );
      });
    });
  }

  Future<void> _processFile(String srcPath) async {
    if (_currentNote == null) return;
    final destPath = await _copyToAppDir(srcPath);
    final fileName = path.basename(destPath);

    if (_isImage(destPath)) {
      _insertAtCursor(imageNode(url: destPath));
    } else {
      // file:/// 프로토콜 붙이면 url_launcher가 파일 탐색기로 열어줌
      final fileUri = Uri.file(destPath).toString(); // file:///C:/Users/...
      _insertAtCursor(
        paragraphNode(
          delta: Delta()
            ..insert(
              '📎 $fileName',
              attributes: {'href': fileUri},
            ),
        ),
      );
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
        child: Text('메모를 선택하세요',
            style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    if (_editorState == null) {
      return const Center(child: CircularProgressIndicator());
    }

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
                      fontSize: 24, fontWeight: FontWeight.bold),
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
                    blockComponentBuilders: standardBlockComponentBuilderMap,
                    commandShortcutEvents: standardCommandShortcutEvents,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
                    const Spacer(),
                    const Text('저장됨',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                    Text('파일을 여기에 놓으세요',
                        style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF4A90E2),
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
