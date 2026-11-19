import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'todo_provider.dart';

const _overdueColor = Color(0xFFE5534B);
const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 기한 표시: 오늘 / 내일 / 11/25 (금) / 2027/1/3
String dueLabel(DateTime due, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final days = DateTime(due.year, due.month, due.day).difference(today).inDays;
  if (days == 0) return '오늘';
  if (days == 1) return '내일';
  if (days == -1) return '어제';
  final weekday = _weekdays[due.weekday - 1];
  return due.year == today.year
      ? '${due.month}/${due.day} ($weekday)'
      : '${due.year}/${due.month}/${due.day}';
}

/// 기한 고르기 메뉴. 취소하면 null, 고르면 (날짜) — 날짜가 null이면 기한 지우기.
Future<({DateTime? due})?> showTodoDueMenu(
  BuildContext context,
  Offset position, {
  DateTime? current,
}) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final nextMonday = today.add(Duration(days: 8 - today.weekday));
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final muted = Theme.of(context).colorScheme.onSurfaceVariant;

  PopupMenuItem<String> item(
    String value,
    IconData icon,
    String label, [
    DateTime? date,
  ]) => PopupMenuItem(
    value: value,
    height: 36,
    child: Row(
      children: [
        Icon(icon, size: 16, color: muted),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13)),
        if (date != null) ...[
          const SizedBox(width: 24),
          const Spacer(),
          Text(
            '${date.month}/${date.day} (${_weekdays[date.weekday - 1]})',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ],
    ),
  );

  final choice = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      overlay.globalToLocal(position) & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    constraints: const BoxConstraints(minWidth: 200),
    items: [
      item('today', Icons.today_outlined, '오늘', today),
      item('tomorrow', Icons.wb_sunny_outlined, '내일', tomorrow),
      item('monday', Icons.next_week_outlined, '다음 주 월요일', nextMonday),
      item('pick', Icons.calendar_month_outlined, '날짜 선택…'),
      if (current != null) ...[
        const PopupMenuDivider(height: 8),
        item('clear', Icons.event_busy_outlined, '기한 지우기'),
      ],
    ],
  );
  switch (choice) {
    case 'today':
      return (due: today);
    case 'tomorrow':
      return (due: tomorrow);
    case 'monday':
      return (due: nextMonday);
    case 'clear':
      return (due: null);
    case 'pick':
      if (!context.mounted) return null;
      final picked = await showDatePicker(
        context: context,
        initialDate: current ?? today,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 10),
        helpText: '기한',
      );
      return picked == null ? null : (due: picked);
  }
  return null;
}

// ───────────── 사이드 패널: 묶음별 개수

class TodoSidebarView extends ConsumerWidget {
  const TodoSidebarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(todoListProvider).value ?? const <TodoItem>[];
    final showDone = ref.watch(todoShowDoneProvider);
    final notifier = ref.read(todoShowDoneProvider.notifier);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    final now = DateTime.now();
    final open = all.where((t) => !t.done).toList();
    final doneCount = all.length - open.length;
    // 기한 지난 것이 있으면 개수를 빨갛게
    final hasOverdue = open.any(
      (t) => todoBucketOf(t.dueDate, now) == TodoBucket.overdue,
    );

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
                '${open.length}개 남음',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
        _FilterTile(
          icon: Icons.inbox_outlined,
          label: '할 일',
          count: open.length,
          warn: hasOverdue,
          selected: !showDone,
          onTap: () => notifier.show(false),
        ),
        _FilterTile(
          icon: Icons.task_alt,
          label: '완료',
          count: doneCount,
          selected: showDone,
          onTap: () => notifier.show(true),
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

// ───────────── 본문: 추가 입력창과 묶음별 목록

class TodoView extends ConsumerWidget {
  const TodoView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todoListProvider);
    final showDone = ref.watch(todoShowDoneProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    final all = async.value;
    if (all == null) {
      return async.hasError
          ? Center(child: Text('할 일을 불러오지 못했습니다: ${async.error}'))
          : const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final List<TodoItem> shown;
    if (showDone) {
      // 최근에 끝낸 것부터
      shown = all.where((t) => t.done).toList()
        ..sort((a, b) => (b.doneAt ?? '').compareTo(a.doneAt ?? ''));
    } else {
      shown = all.where((t) => !t.done).toList()..sort(compareTodos);
    }

    final title = showDone ? '완료' : '할 일';
    final emptyText = showDone ? '완료한 할 일이 없습니다' : '남은 할 일이 없습니다';

    // 남은 할 일은 기한별로 묶어 보여 줌 (기한 지남 → 오늘 → 이번 주 → 나중에 → 기한 없음)
    final groups = <TodoBucket, List<TodoItem>>{};
    if (!showDone) {
      for (final todo in shown) {
        groups.putIfAbsent(todoBucketOf(todo.dueDate, now), () => []).add(todo);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 24, 24, 4),
          child: Row(
            children: [
              Expanded(
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
              if (showDone && shown.isNotEmpty)
                TextButton.icon(
                  onPressed: () =>
                      _confirmClearDone(context, ref, shown.length),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                  label: const Text('모두 지우기', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: muted),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 0, 24, 12),
          child: Text(
            shown.isEmpty
                ? emptyText
                : showDone
                ? '${shown.length}개 완료'
                : '${shown.length}개 남음',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ),
        if (!showDone)
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: _AddTodoField(),
          ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.task_alt, size: 48, color: muted),
                      const SizedBox(height: 12),
                      Text(emptyText, style: TextStyle(color: muted)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  children: [
                    if (showDone)
                      for (final todo in shown)
                        _TodoRow(key: ValueKey(todo.id), todo: todo)
                    else
                      for (final bucket in TodoBucket.values)
                        if (groups[bucket] case final items?) ...[
                          _GroupHeader(bucket: bucket, count: items.length),
                          for (final todo in items)
                            _TodoRow(
                              key: ValueKey(todo.id),
                              todo: todo,
                              overdue: bucket == TodoBucket.overdue,
                            ),
                        ],
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _confirmClearDone(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('완료한 할 일 지우기'),
        content: Text('완료한 할 일 $count개를 모두 지울까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('지우기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(todoListProvider.notifier).clearDone();
  }
}

/// 새 할 일 입력창. Enter로 추가하고, 오른쪽 칩으로 기한을 정함.
class _AddTodoField extends ConsumerStatefulWidget {
  const _AddTodoField();

  @override
  ConsumerState<_AddTodoField> createState() => _AddTodoFieldState();
}

class _AddTodoFieldState extends ConsumerState<_AddTodoField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  DateTime? _due;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _focusNode.requestFocus(); // 이어서 입력
    await ref.read(todoListProvider.notifier).add(text, due: _due);
  }

  Future<void> _pickDue(Offset position) async {
    final result = await showTodoDueMenu(context, position, current: _due);
    if (result != null && mounted) setState(() => _due = result.due);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final due = _due;
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.add, size: 20, color: context.accent),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onSubmitted: (_) => _submit(),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: '할 일 추가 (Enter)',
                hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          GestureDetector(
            key: const ValueKey('todo-add-due'),
            onTapDown: (d) => _pickDue(d.globalPosition),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: _Chip(
                icon: due == null ? Icons.event_outlined : Icons.event,
                label: due == null ? '기한 없음' : dueLabel(due, DateTime.now()),
                color: due == null ? null : context.accent,
              ),
            ),
          ),
        ],
      ),
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

/// 할 일 한 줄: 체크, 제목(눌러서 고치기), 기한 칩(눌러서 바꾸기), 지우기
class _TodoRow extends ConsumerStatefulWidget {
  final TodoItem todo;
  final bool overdue;
  const _TodoRow({super.key, required this.todo, this.overdue = false});

  @override
  ConsumerState<_TodoRow> createState() => _TodoRowState();
}

class _TodoRowState extends ConsumerState<_TodoRow> {
  bool _hovering = false;
  bool _editing = false;
  bool _completing = false; // 체크 직후 잠시 취소선으로 보여 줌
  late final _editController = TextEditingController();
  final _editFocus = FocusNode();

  TodoListNotifier get _todos => ref.read(todoListProvider.notifier);

  @override
  void initState() {
    super.initState();
    _editFocus.addListener(() {
      if (!_editFocus.hasFocus && _editing) _finishEdit(save: true);
    });
  }

  @override
  void dispose() {
    _editController.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  Future<void> _toggleDone() async {
    final todo = widget.todo;
    final todos = _todos;
    final messenger = ScaffoldMessenger.of(context);
    if (todo.done) {
      await todos.setDone(todo.id, false);
      return;
    }
    setState(() => _completing = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await todos.setDone(todo.id, true);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${todo.title}" 완료'),
          action: SnackBarAction(
            label: '실행 취소',
            // 행은 이미 목록에서 빠졌으므로 notifier로 되돌림
            onPressed: () => todos.setDone(todo.id, false),
          ),
        ),
      );
  }

  Future<void> _delete() async {
    final todo = widget.todo;
    final todos = _todos;
    final messenger = ScaffoldMessenger.of(context);
    await todos.delete(todo.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${todo.title}" 삭제'),
          action: SnackBarAction(
            label: '실행 취소',
            onPressed: () => todos.restore(todo),
          ),
        ),
      );
  }

  Future<void> _pickDue(Offset position) async {
    final result = await showTodoDueMenu(
      context,
      position,
      current: widget.todo.dueDate,
    );
    if (result == null) return;
    await _todos.setDue(widget.todo.id, result.due);
  }

  void _startEdit() {
    if (widget.todo.done) return;
    _editController.text = widget.todo.title;
    _editController.selection = TextSelection.collapsed(
      offset: widget.todo.title.length,
    );
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _editFocus.requestFocus(),
    );
  }

  void _finishEdit({required bool save}) {
    if (!_editing) return;
    setState(() => _editing = false);
    final text = _editController.text.trim();
    if (save && text.isNotEmpty && text != widget.todo.title) {
      _todos.rename(widget.todo.id, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todo = widget.todo;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final due = todo.dueDate;
    final checked = todo.done || _completing;

    final Widget title = _editing
        ? CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  _finishEdit(save: false),
            },
            child: TextField(
              controller: _editController,
              focusNode: _editFocus,
              onSubmitted: (_) => _finishEdit(save: true),
              style: const TextStyle(fontSize: 15),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          )
        : Text(
            todo.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              decoration: checked ? TextDecoration.lineThrough : null,
              color: checked ? muted : null,
            ),
          );

    // 기한 칩: 있으면 늘 보이고, 없으면 마우스를 올렸을 때만 "기한"
    Widget? dueChip;
    if (!todo.done && (due != null || _hovering)) {
      dueChip = GestureDetector(
        onTapDown: (d) => _pickDue(d.globalPosition),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: _Chip(
            icon: due == null ? Icons.event_outlined : Icons.event,
            label: due == null ? '기한' : dueLabel(due, DateTime.now()),
            color: due == null
                ? null
                : widget.overdue
                ? _overdueColor
                : todoBucketOf(due, DateTime.now()) == TodoBucket.today
                ? context.accent
                : null,
          ),
        ),
      );
    } else if (todo.done && due != null) {
      dueChip = _Chip(icon: Icons.event, label: dueLabel(due, DateTime.now()));
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _completing ? 0.5 : 1,
        child: Material(
          color: _hovering || _editing
              ? scheme.surfaceContainerHigh
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _editing ? null : _startEdit,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // 툴팁은 넣지 않음: Flutter 3.38에서 목록 순서가 바뀔 때 툴팁이
                  // 레이아웃 전에 다시 그려지며 Null check 오류가 남 (할 일 추가 시)
                  InkWell(
                    key: const ValueKey('todo-check'),
                    borderRadius: BorderRadius.circular(6),
                    onTap: _toggleDone,
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: _CheckBox(checked: checked),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: title),
                  if (dueChip != null) ...[const SizedBox(width: 8), dueChip],
                  // 지우기 버튼 자리는 늘 잡아 둬서 마우스를 올려도 줄이 흔들리지 않음
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: _hovering && !_editing
                        ? IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                            color: muted,
                            onPressed: _delete,
                            icon: const Icon(Icons.close),
                          )
                        : null,
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
        color: color?.withValues(alpha: 0.12) ?? scheme.surfaceContainerHighest,
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
