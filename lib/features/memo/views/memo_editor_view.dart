import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';

class MemoEditorView extends ConsumerStatefulWidget {
  const MemoEditorView({super.key});

  @override
  ConsumerState<MemoEditorView> createState() => _MemoEditorViewState();
}

class _MemoEditorViewState extends ConsumerState<MemoEditorView> {
  EditorState? _editorState;
  Note? _currentNote;
  final _titleController = TextEditingController();

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

    return Column(
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
      ],
    );
  }
}
