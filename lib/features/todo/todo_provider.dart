import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/database_provider.dart';

export '../../core/database/database.dart' show TodoItem;

/// 할 일 탭 화면 번호 (navigationProvider 값)
const todoTabIndex = 5;

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

DateTime? parseTodoDue(String? value) =>
    value == null ? null : DateTime.tryParse(value);

String formatTodoDue(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

extension TodoItemDue on TodoItem {
  DateTime? get dueDate => parseTodoDue(due);
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

/// 마감일 순 (마감일 없는 것은 뒤), 같으면 먼저 만든 것부터
int compareTodos(TodoItem a, TodoItem b) {
  final ad = a.due, bd = b.due;
  if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
  if (ad != null && bd == null) return -1;
  if (ad == null && bd != null) return 1;
  return a.id.compareTo(b.id);
}

/// 할 일 전체 (완료 포함). 바꾸면 DB에 저장하고 목록을 다시 읽음.
class TodoListNotifier extends AsyncNotifier<List<TodoItem>> {
  AppDatabase get _db => ref.read(databaseProvider);

  @override
  Future<List<TodoItem>> build() async {
    final db = ref.watch(databaseProvider);
    return db.select(db.todoTable).get();
  }

  Future<void> _reload() async {
    state = AsyncData(await _db.select(_db.todoTable).get());
  }

  Future<void> add(String title, {DateTime? due}) async {
    final text = title.trim();
    if (text.isEmpty) return;
    await _db
        .into(_db.todoTable)
        .insert(
          TodoTableCompanion.insert(
            title: text,
            due: Value(due == null ? null : formatTodoDue(due)),
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
    await _reload();
  }

  Future<void> _update(int id, TodoTableCompanion values) async {
    await (_db.update(
      _db.todoTable,
    )..where((t) => t.id.equals(id))).write(values);
    await _reload();
  }

  Future<void> setDone(int id, bool done) => _update(
    id,
    TodoTableCompanion(
      done: Value(done),
      doneAt: Value(done ? DateTime.now().toIso8601String() : null),
    ),
  );

  Future<void> setDue(int id, DateTime? due) => _update(
    id,
    TodoTableCompanion(due: Value(due == null ? null : formatTodoDue(due))),
  );

  Future<void> rename(int id, String title) async {
    final text = title.trim();
    if (text.isEmpty) return;
    await _update(id, TodoTableCompanion(title: Value(text)));
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.todoTable)..where((t) => t.id.equals(id))).go();
    await _reload();
  }

  /// 지운 할 일 되살리기 (실행 취소)
  Future<void> restore(TodoItem item) async {
    await _db.into(_db.todoTable).insertOnConflictUpdate(item);
    await _reload();
  }

  Future<void> clearDone() async {
    await (_db.delete(_db.todoTable)..where((t) => t.done.equals(true))).go();
    await _reload();
  }
}

final todoListProvider =
    AsyncNotifierProvider<TodoListNotifier, List<TodoItem>>(
      TodoListNotifier.new,
    );

/// 할 일 탭에서 보는 목록: 남은 할 일(false) / 완료(true)
class TodoShowDoneNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void show(bool done) => state = done;
}

final todoShowDoneProvider = NotifierProvider<TodoShowDoneNotifier, bool>(
  TodoShowDoneNotifier.new,
);
