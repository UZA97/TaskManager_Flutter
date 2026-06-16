import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';

class MemoListView extends ConsumerWidget {
  const MemoListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(noteListProvider);
    final selectedNote = ref.watch(selectedNoteProvider);

    return Column(
      children: [
        // 새 메모 버튼
        Padding(
          padding: const EdgeInsets.all(10),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ref.read(noteListProvider.notifier).createNote();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('+ 새 메모', style: TextStyle(fontSize: 14)),
            ),
          ),
        ),

        // 검색창
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: TextField(
            decoration: InputDecoration(
              hintText: '검색',
              prefixIcon: const Icon(Icons.search, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              isDense: true,
            ),
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).update(value);
              ref.read(noteListProvider.notifier).refresh();
            },
          ),
        ),

        const SizedBox(height: 8),

        // 메모 목록
        Expanded(
          child: notesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
            data: (notes) => notes.isEmpty
                ? const Center(
                    child: Text(
                      '메모가 없어요',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      final isSelected = selectedNote?.id == note.id;
                      return _NoteListItem(note: note, isSelected: isSelected);
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _NoteListItem extends ConsumerWidget {
  final Note note;
  final bool isSelected;

  const _NoteListItem({required this.note, required this.isSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onSecondaryTapUp: (details) {
        _showContextMenu(context, ref, details.globalPosition);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F0FE) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          onTap: () {
            ref.read(selectedNoteProvider.notifier).select(note);
          },
          title: Text(
            note.title.isEmpty ? '제목 없음' : note.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: note.tags.isNotEmpty
              ? Text(
                  note.tags.map((t) => '#$t').join(' '),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4A90E2),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  void _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
  ) async {
    final result = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [
        PopupMenuItem(value: 'delete', child: Text('삭제')),
        PopupMenuItem(value: 'duplicate', child: Text('복제')),
        PopupMenuItem(value: 'tag', child: Text('태그 추가')),
      ],
    );

    if (result == 'delete') {
      ref.read(noteListProvider.notifier).deleteNote(note.id!);
    } else if (result == 'duplicate') {
      // 나중에 구현
    } else if (result == 'tag') {
      // 나중에 구현
    }
  }
}
