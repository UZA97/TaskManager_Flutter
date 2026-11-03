import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/navigation_provider.dart';
import '../../briefing/briefing_todos.dart';
import '../data/note_repository.dart';
import '../models/note.dart';
import 'note_provider.dart';

/// 마감일을 정한 미완료 체크리스트 (캘린더에 표시)
class MemoDueTodo {
  final Note note;
  final String text;
  final List<int> path;
  final DateTime due;

  const MemoDueTodo(this.note, this.text, this.path, this.due);
}

/// 모든 메모의 마감일 있는 체크리스트. 메모가 저장될 때마다 다시 계산
/// (캘린더를 보고 있을 때만 살아 있음).
final memoDueTodosProvider = FutureProvider.autoDispose<List<MemoDueTodo>>((
  ref,
) async {
  ref.watch(noteListProvider);
  final notes = await ref.read(noteRepositoryProvider).getAllNotes();
  return [
    for (final note in notes)
      for (final item in uncheckedTodos(note.content))
        if (item.due != null)
          MemoDueTodo(note, item.text, item.path, item.due!),
  ];
});

/// 메모 탭으로 가서 그 체크리스트 줄에 커서를 둠
void openMemoTodo(WidgetRef ref, MemoDueTodo todo) {
  ref.read(memoFocusRequestProvider.notifier).request((
    noteId: todo.note.id!,
    path: todo.path,
    text: todo.text,
  ));
  ref.read(selectedNoteProvider.notifier).select(todo.note);
  ref.read(navigationProvider.notifier).navigateTo(0); // 메모 탭
}
