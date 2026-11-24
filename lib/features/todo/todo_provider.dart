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

extension TodoItemTree on TodoItem {
  bool get isSubtask => parentId != null;
}

/// [parentId]의 하위 할 일 (추가한 순서)
List<TodoItem> subtasksOf(Iterable<TodoItem> all, int parentId) =>
    all.where((t) => t.parentId == parentId).toList()
      ..sort((a, b) => a.id.compareTo(b.id));

/// 할 일 전체 (완료·하위 할 일 포함). 바꾸면 DB에 저장하고 목록을 다시 읽음.
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

  /// 할 일 추가. [subtasks]는 하위 할 일 제목 (빈 것은 건너뜀).
  Future<void> add(
    String title, {
    DateTime? due,
    List<String> subtasks = const [],
    int? noteId,
  }) async {
    final text = title.trim();
    if (text.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    await _db.transaction(() async {
      final id = await _db
          .into(_db.todoTable)
          .insert(
            TodoTableCompanion.insert(
              title: text,
              due: Value(due == null ? null : formatTodoDue(due)),
              createdAt: now,
              noteId: Value(noteId),
            ),
          );
      for (final sub in subtasks) {
        await _insertSub(id, sub, now);
      }
    });
    await _reload();
  }

  Future<void> _insertSub(int parentId, String title, String now) async {
    final text = title.trim();
    if (text.isEmpty) return;
    await _db
        .into(_db.todoTable)
        .insert(
          TodoTableCompanion.insert(
            title: text,
            createdAt: now,
            parentId: Value(parentId),
          ),
        );
  }

  /// 하위 할 일 추가
  Future<void> addSubtask(int parentId, String title) async {
    await _insertSub(parentId, title, DateTime.now().toIso8601String());
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

  /// 메모 연결 (null이면 연결 끊기)
  Future<void> setNote(int id, int? noteId) =>
      _update(id, TodoTableCompanion(noteId: Value(noteId)));

  Future<void> rename(int id, String title) async {
    final text = title.trim();
    if (text.isEmpty) return;
    await _update(id, TodoTableCompanion(title: Value(text)));
  }

  /// 할 일 지우기 (하위 할 일도 함께). 되살릴 수 있게 지운 것들을 돌려줌.
  Future<List<TodoItem>> delete(int id) async {
    final removed = await (_db.select(
      _db.todoTable,
    )..where((t) => t.id.equals(id) | t.parentId.equals(id))).get();
    await (_db.delete(
      _db.todoTable,
    )..where((t) => t.id.equals(id) | t.parentId.equals(id))).go();
    await _reload();
    return removed;
  }

  /// 지운 할 일 되살리기 (실행 취소)
  Future<void> restore(Iterable<TodoItem> items) async {
    await _db.batch((b) {
      for (final item in items) {
        b.insert(_db.todoTable, item, mode: InsertMode.insertOrReplace);
      }
    });
    await _reload();
  }

  /// 완료한 할 일 모두 지우기 (그 하위 할 일 포함. 남은 할 일의 하위 할 일은 둠)
  Future<void> clearDone() async {
    await _db.transaction(() async {
      final done = await (_db.select(
        _db.todoTable,
      )..where((t) => t.done.equals(true) & t.parentId.isNull())).get();
      final ids = [for (final t in done) t.id];
      await (_db.delete(
        _db.todoTable,
      )..where((t) => t.id.isIn(ids) | t.parentId.isIn(ids))).go();
    });
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

/// 상세 패널에 연 할 일 id (null이면 패널 닫힘)
class TodoSelectionNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) => state = id;
}

final todoSelectedProvider = NotifierProvider<TodoSelectionNotifier, int?>(
  TodoSelectionNotifier.new,
);

/// 접어 둔 것들 (묶음, 하위 할 일 목록)
class TodoCollapseNotifier<T> extends Notifier<Set<T>> {
  @override
  Set<T> build() => {};

  void toggle(T key) =>
      state = state.contains(key) ? ({...state}..remove(key)) : {...state, key};

  void expand(T key) {
    if (state.contains(key)) state = {...state}..remove(key);
  }
}

/// 접어 둔 기한 묶음
final todoCollapsedGroupsProvider =
    NotifierProvider<TodoCollapseNotifier<TodoBucket>, Set<TodoBucket>>(
      TodoCollapseNotifier<TodoBucket>.new,
    );

/// 하위 할 일을 접어 둔 할 일 id
final todoCollapsedTreesProvider =
    NotifierProvider<TodoCollapseNotifier<int>, Set<int>>(
      TodoCollapseNotifier<int>.new,
    );
