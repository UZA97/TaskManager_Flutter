import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../memo/models/note.dart';
import 'todo_provider.dart';

const _overdueColor = Color(0xFFE5534B);

/// 묶음별 아이콘
IconData _bucketIcon(TodoBucket? bucket) => switch (bucket) {
  null => Icons.inbox_outlined,
  TodoBucket.overdue => Icons.error_outline,
  TodoBucket.today => Icons.today_outlined,
  TodoBucket.week => Icons.date_range_outlined,
  TodoBucket.later => Icons.event_outlined,
  TodoBucket.none => Icons.remove_circle_outline,
};

String _noteTitle(Note note) => note.title.isEmpty ? '제목 없음' : note.title;

// ───────────── 사이드 패널: 묶음과 메모별 개수

class TodoSidebarView extends ConsumerWidget {
  const TodoSidebarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todos = ref.watch(allMemoTodosProvider).value ?? const <MemoTodo>[];
    final filter = ref.watch(todoFilterProvider);
    final notifier = ref.read(todoFilterProvider.notifier);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    final now = DateTime.now();
    final counts = <TodoBucket, int>{};
    final byNote = <int, (Note, int)>{};
    for (final todo in todos) {
      final bucket = todoBucketOf(todo.due, now);
      counts[bucket] = (counts[bucket] ?? 0) + 1;
      final id = todo.note.id!;
      byNote[id] = (todo.note, (byNote[id]?.$2 ?? 0) + 1);
    }
    final notes = byNote.values.toList()
      ..sort((a, b) {
        final byCount = b.$2.compareTo(a.$2);
        return byCount != 0
            ? byCount
            : _noteTitle(a.$1).compareTo(_noteTitle(b.$1));
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '할 일',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${todos.length}개 남음',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
        _FilterTile(
          icon: _bucketIcon(null),
          label: '전체',
          count: todos.length,
          selected: filter.bucket == null && filter.noteId == null,
          onTap: notifier.showAll,
        ),
        for (final bucket in TodoBucket.values)
          _FilterTile(
            icon: _bucketIcon(bucket),
            label: bucket.label,
            count: counts[bucket] ?? 0,
            warn: bucket == TodoBucket.overdue,
            selected: filter.bucket == bucket,
            onTap: () => notifier.showBucket(bucket),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text('메모별', style: TextStyle(fontSize: 11, color: muted)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              for (final (note, count) in notes)
                _FilterTile(
                  icon: Icons.description_outlined,
                  label: _noteTitle(note),
                  count: count,
                  selected: filter.noteId == note.id,
                  onTap: () => notifier.showNote(note.id!),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final bool warn;
  final VoidCallback onTap;
  const _FilterTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.warn = false,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final iconColor = selected
        ? context.accent
        : warn && count > 0
        ? _overdueColor
        : muted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Material(
        color: selected ? context.selectedTint : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (count > 0)
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 12,
                        color: warn ? _overdueColor : muted,
                        fontWeight: warn ? FontWeight.w600 : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────── 본문: 묶음별 목록

class TodoView extends ConsumerWidget {
  const TodoView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allMemoTodosProvider);
    final filter = ref.watch(todoFilterProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    final todos = async.value;
    if (todos == null) {
      return async.hasError
          ? Center(child: Text('할 일을 불러오지 못했습니다: ${async.error}'))
          : const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final shown = [
      for (final todo in todos)
        if ((filter.noteId == null || todo.note.id == filter.noteId) &&
            (filter.bucket == null ||
                todoBucketOf(todo.due, now) == filter.bucket))
          todo,
    ];

    final String title;
    if (filter.noteId != null) {
      final note = todos
          .map((t) => t.note)
          .where((n) => n.id == filter.noteId)
          .firstOrNull;
      title = note == null ? '메모' : _noteTitle(note);
    } else {
      title = filter.bucket?.label ?? '모든 할 일';
    }

    // 묶음 하나만 볼 때는 묶음 제목 없이
    final groups = <TodoBucket, List<MemoTodo>>{};
    for (final todo in shown) {
      groups.putIfAbsent(todoBucketOf(todo.due, now), () => []).add(todo);
    }
    final showGroupHeaders = filter.bucket == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 24, 24, 4),
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 0, 24, 12),
          child: Text(
            shown.isEmpty
                ? '남은 할 일이 없습니다'
                : '${shown.length}개 남음 · 체크하면 메모에도 바로 반영됩니다',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.task_alt, size: 48, color: muted),
                      const SizedBox(height: 12),
                      Text('남은 할 일이 없습니다', style: TextStyle(color: muted)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  children: [
                    for (final bucket in TodoBucket.values)
                      if (groups[bucket] case final items?) ...[
                        if (showGroupHeaders)
                          _GroupHeader(bucket: bucket, count: items.length),
                        for (final todo in items)
                          _TodoRow(
                            // 같은 메모의 같은 자리여도 글이 바뀌면 다른 줄
                            key: ValueKey(
                              '${todo.note.id}/${todo.path.join('.')}/${todo.text}',
                            ),
                            todo: todo,
                            bucket: bucket,
                            showNote: filter.noteId == null,
                          ),
                      ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final TodoBucket bucket;
  final int count;
  const _GroupHeader({required this.bucket, required this.count});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final warn = bucket == TodoBucket.overdue;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
      child: Row(
        children: [
          Text(
            bucket.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: warn ? _overdueColor : null,
            ),
          ),
          const SizedBox(width: 8),
          Text('$count', style: TextStyle(fontSize: 12, color: muted)),
          const SizedBox(width: 12),
          Expanded(child: Divider(height: 1, color: context.lineSubtle)),
        ],
      ),
    );
  }
}

/// 할 일 한 줄. 체크하면 메모에 저장하고 잠시 취소선으로 보인 뒤 목록에서 빠짐.
class _TodoRow extends ConsumerStatefulWidget {
  final MemoTodo todo;
  final TodoBucket bucket;
  final bool showNote;
  const _TodoRow({
    super.key,
    required this.todo,
    required this.bucket,
    required this.showNote,
  });

  @override
  ConsumerState<_TodoRow> createState() => _TodoRowState();
}

class _TodoRowState extends ConsumerState<_TodoRow> {
  bool _done = false;
  bool _hovering = false;

  Future<void> _complete() async {
    if (_done) return;
    setState(() => _done = true);
    final todo = widget.todo;
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final ok = await setMemoTodoChecked(container, todo, true);
    if (!ok) {
      if (mounted) setState(() => _done = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('메모 내용이 바뀌어 체크하지 못했습니다. 다시 시도해 주세요.')),
      );
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${todo.text}" 완료'),
          action: SnackBarAction(
            label: '실행 취소',
            // 행은 이미 목록에서 빠졌을 수 있으므로 container로 되돌림
            onPressed: () => setMemoTodoChecked(container, todo, false),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final todo = widget.todo;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final due = todo.due;
    final overdue = widget.bucket == TodoBucket.overdue;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _done ? 0.5 : 1,
        child: Material(
          color: _hovering ? scheme.surfaceContainerHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => openTodoInMemo(ref, todo),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Tooltip(
                    message: '완료',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: _complete,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: _CheckBox(checked: _done),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: Text(
                      todo.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        decoration: _done ? TextDecoration.lineThrough : null,
                        color: _done ? muted : null,
                      ),
                    ),
                  ),
                  if (due != null) ...[
                    const SizedBox(width: 8),
                    _Chip(
                      icon: Icons.event_outlined,
                      label: '${due.month}/${due.day}',
                      color: overdue ? _overdueColor : null,
                    ),
                  ],
                  if (widget.showNote) ...[
                    const SizedBox(width: 6),
                    // 좁은 창에서는 메모 제목 칩이 줄어듦
                    Flexible(
                      flex: 2,
                      child: Tooltip(
                        message: '메모 열기',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => openNoteFromTodo(ref, todo.note),
                          child: _Chip(
                            icon: Icons.description_outlined,
                            label: _noteTitle(todo.note),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 메모 체크리스트와 같은 둥근 체크박스
class _CheckBox extends StatelessWidget {
  final bool checked;
  const _CheckBox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 17,
      height: 17,
      decoration: BoxDecoration(
        color: checked ? context.accent : null,
        borderRadius: BorderRadius.circular(5),
        border: checked
            ? null
            : Border.all(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                width: 1.6,
              ),
      ),
      child: checked
          ? Icon(
              Icons.check,
              size: 13,
              color: Theme.of(context).colorScheme.onPrimary,
            )
          : null,
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _Chip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = color ?? scheme.onSurfaceVariant;
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.12) ?? scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
