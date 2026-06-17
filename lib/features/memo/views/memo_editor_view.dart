import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';
import '../providers/attachment_provider.dart';
import '../data/attachment_repository.dart';

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
          document: markdownToDocument(note.content),
        );
      } catch (_) {
        editorState = EditorState.blank();
      }
    } else {
      editorState = EditorState.blank();
    }

    editorState.transactionStream.listen((_) {
      _onContentChanged();
    });

    setState(() {
      _editorState = editorState;
    });
  }

  void _onContentChanged() {
    if (_currentNote == null || _editorState == null) return;
    final content = documentToMarkdown(_editorState!.document);
    final updated = _currentNote!.copyWith(
      title: _titleController.text,
      content: content,
    );
    ref.read(noteListProvider.notifier).saveNote(updated);
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    final filePaths = details.files.map((f) => f.path).toList();
    await ref
        .read(attachmentProvider.notifier)
        .addAttachmentFromDrop(filePaths);
  }

  @override
  Widget build(BuildContext context) {
    final selectedNote = ref.watch(selectedNoteProvider);
    final attachmentsAsync = ref.watch(attachmentProvider);

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
              // 제목 입력
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

              // 에디터
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

              // 첨부파일 목록
              if (attachmentsAsync.value?.isNotEmpty ?? false) ...[
                const Divider(height: 1, color: Color(0xFFDDDDDD)),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '첨부파일',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: attachmentsAsync.value!
                            .map((att) => _AttachmentChip(attachment: att))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],

              // 하단 툴바
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFDDDDDD)),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file, size: 18),
                      tooltip: '파일 첨부',
                      onPressed: () {
                        ref.read(attachmentProvider.notifier).addAttachment();
                      },
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

          // 드래그 오버레이
          if (_isDragging)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.1),
                border: Border.all(
                  color: const Color(0xFF4A90E2),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 48,
                      color: Color(0xFF4A90E2),
                    ),
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

class _AttachmentChip extends ConsumerWidget {
  final Attachment attachment;

  const _AttachmentChip({required this.attachment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isImage =
        ref.read(attachmentProvider.notifier).isImage(attachment.fileName);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFD0E0FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 8),
          Icon(
            isImage ? Icons.image : Icons.attach_file,
            size: 12,
            color: const Color(0xFF4A90E2),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              ref
                  .read(attachmentProvider.notifier)
                  .openAttachment(attachment.filePath);
            },
            child: Text(
              attachment.fileName,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF4A90E2),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 12),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              ref.read(attachmentProvider.notifier).deleteAttachment(
                    attachment.id!,
                    attachment.filePath,
                  );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
