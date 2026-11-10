import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/note_repository.dart';
import '../models/note.dart';

/// 이 메모를 `[[` 링크로 참조하는 메모들 (메모를 열 때, 목록을 펼칠 때 다시 읽음)
final backlinksProvider = FutureProvider.autoDispose.family<List<Note>, int>(
  (ref, noteId) => ref.read(noteRepositoryProvider).getBacklinks(noteId),
);

/// 하단 바의 "참조 N" 버튼. 누르면 참조하는 메모 목록이 열리고, 고르면 그 메모로 이동.
/// 참조하는 메모가 없으면 보이지 않음.
class BacklinksButton extends ConsumerWidget {
  const BacklinksButton({
    super.key,
    required this.noteId,
    required this.onOpen,
  });

  final int noteId;
  final void Function(Note note) onOpen;

  Future<void> _showList(BuildContext context, WidgetRef ref) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    // 그사이 바뀐 링크까지 반영
    final notes = await ref.refresh(backlinksProvider(noteId).future);
    if (!context.mounted || notes.isEmpty) return;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final note = await showMenu<Note>(
      context: context,
      // 버튼 위쪽으로 펼침
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        topLeft.dy - 8,
        overlay.size.width - topLeft.dx - box.size.width,
        overlay.size.height - topLeft.dy + 8,
      ),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
      items: [
        const PopupMenuItem<Note>(
          enabled: false,
          height: 28,
          child: Text(
            '이 메모를 참조하는 메모',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
        for (final n in notes)
          PopupMenuItem<Note>(
            value: n,
            height: 36,
            child: Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    n.title.trim().isEmpty ? '제목 없음' : n.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (note != null) onOpen(note);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(backlinksProvider(noteId)).value?.length ?? 0;
    if (count == 0) return const SizedBox.shrink();
    return Tooltip(
      message: '이 메모를 참조하는 메모',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showList(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link, size: 14, color: context.accent),
              const SizedBox(width: 3),
              Text(
                '참조 $count',
                style: TextStyle(fontSize: 11, color: context.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
