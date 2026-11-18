import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/navigation_provider.dart';
import '../briefing/briefing_todos.dart';
import '../memo/data/note_repository.dart';
import '../memo/models/note.dart';
import '../memo/providers/note_provider.dart';

/// 할 일 탭 화면 번호 (navigationProvider 값)
const todoTabIndex = 5;

/// 메모 안의 체크되지 않은 체크박스 하나
class MemoTodo {
  final Note note;
  final String text;
  final List<int> path;
  final DateTime? due;

  const MemoTodo(this.note, this.text, this.path, this.due);
}

/// 마감일 기준 묶음
enum TodoBucket {
  overdue('기한 지남'),
  today('오늘'),
  week('이번 주'),
  later('나중에'),
  none('기한 없음');

  const TodoBucket(this.label);
  final String label;
}

/// [due]가 [now] 기준 어느 묶음인지 (이번 주 = 내일부터 6일 뒤까지)
TodoBucket todoBucketOf(DateTime? due, DateTime now) {
  if (due == null) return TodoBucket.none;
  final today = DateTime(now.year, now.month, now.day);
  final days = DateTime(due.year, due.month, due.day).difference(today).inDays;
  if (days < 0) return TodoBucket.overdue;
  if (days == 0) return TodoBucket.today;
  if (days <= 6) return TodoBucket.week;
  return TodoBucket.later;
}

/// 마감일 순 (마감일 없는 것은 뒤), 같으면 메모 제목 순
int compareTodos(MemoTodo a, MemoTodo b) {
  final ad = a.due, bd = b.due;
  if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
  if (ad != null && bd == null) return -1;
  if (ad == null && bd != null) return 1;
  return a.note.title.compareTo(b.note.title);
}

/// 모든 메모의 체크되지 않은 체크박스. 메모가 저장될 때마다 다시 계산
/// (검색어와 상관없이 전체 메모 기준).
final allMemoTodosProvider = FutureProvider.autoDispose<List<MemoTodo>>((
  ref,
) async {
  ref.watch(noteListProvider);
  final notes = await ref.read(noteRepositoryProvider).getAllNotes();
  return [
    for (final note in notes)
      for (final item in uncheckedTodos(note.content))
        MemoTodo(note, item.text, item.path, item.due),
  ]..sort(compareTodos);
});

/// 할 일 탭에서 보는 범위: 마감일 묶음 하나, 또는 메모 하나 (둘 다 null이면 전체)
typedef TodoFilter = ({TodoBucket? bucket, int? noteId});

class TodoFilterNotifier extends Notifier<TodoFilter> {
  @override
  TodoFilter build() => (bucket: null, noteId: null);

  void showAll() => state = (bucket: null, noteId: null);
  void showBucket(TodoBucket bucket) => state = (bucket: bucket, noteId: null);
  void showNote(int noteId) => state = (bucket: null, noteId: noteId);
}

final todoFilterProvider = NotifierProvider<TodoFilterNotifier, TodoFilter>(
  TodoFilterNotifier.new,
);

/// 메모 본문의 그 체크박스를 체크(또는 해제)해서 저장.
/// 그사이 메모가 바뀌어 그 자리를 찾지 못하면 false.
/// 화면(행)이 사라진 뒤에도 실행 취소할 수 있게 위젯 ref 대신 container를 받음.
Future<bool> setMemoTodoChecked(
  ProviderContainer container,
  MemoTodo todo,
  bool checked,
) async {
  final id = todo.note.id;
  if (id == null) return false;
  final note = await container.read(noteRepositoryProvider).getNoteById(id);
  if (note == null) return false;
  final content = setTodoCheckedAt(
    note.content,
    todo.path,
    checked,
    expectedText: todo.text,
  );
  if (content == null) return false;
  await container
      .read(noteListProvider.notifier)
      .saveNote(note.copyWith(content: content));
  container.invalidate(allMemoTodosProvider);
  return true;
}

/// 메모 탭으로 가서 그 체크박스 줄에 커서를 둠
void openTodoInMemo(WidgetRef ref, MemoTodo todo) {
  ref.read(memoFocusRequestProvider.notifier).request((
    noteId: todo.note.id!,
    path: todo.path,
    text: todo.text,
  ));
  ref.read(selectedNoteProvider.notifier).select(todo.note);
  ref.read(navigationProvider.notifier).navigateTo(0); // 메모 탭
}

/// 메모만 열기
void openNoteFromTodo(WidgetRef ref, Note note) {
  ref.read(selectedNoteProvider.notifier).select(note);
  ref.read(navigationProvider.notifier).navigateTo(0);
}
