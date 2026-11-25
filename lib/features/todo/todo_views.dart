import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'todo_memo.dart';
import 'todo_provider.dart';

const _overdueColor = Color(0xFFE5534B);

/// 기한 묶음별 색 (테마색과 상관없이 고정. 다크 모드는 조금 밝게)
/// 기한 지남 빨강 · 오늘 주황 · 이번 주 초록 · 나중에 보라 · 기한 없음 회색
Color todoBucketColor(BuildContext context, TodoBucket bucket) {
  final dark = context.isDark;
  return switch (bucket) {
    TodoBucket.overdue => dark ? const Color(0xFFFF6B6B) : _overdueColor,
    TodoBucket.today =>
      dark ? const Color(0xFFFFA94D) : const Color(0xFFE8590C),
    TodoBucket.week => dark ? const Color(0xFF51CF66) : const Color(0xFF2B8A3E),
    TodoBucket.later =>
      dark ? const Color(0xFFCC5DE8) : const Color(0xFF9C36B5),
    TodoBucket.none => Theme.of(context).colorScheme.onSurfaceVariant,
  };
}

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

/// 작은 메뉴 (값, 아이콘, 글자). 위험한 항목은 [danger]에 값.
Future<String?> _showActionMenu(
  BuildContext context,
  Offset position,
  List<(String, IconData, String)?> items, {
  String? danger,
}) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final muted = Theme.of(context).colorScheme.onSurfaceVariant;
  return showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      overlay.globalToLocal(position) & const Size(1, 1),
      Offset.zero & overlay.size,
    ),
    items: [
      for (final item in items)
        if (item == null)
          const PopupMenuDivider(height: 8)
        else
          PopupMenuItem(
            value: item.$1,
            height: 36,
            child: Row(
              children: [
                Icon(
                  item.$2,
                  size: 16,
                  color: item.$1 == danger ? _overdueColor : muted,
                ),
                const SizedBox(width: 10),
                Text(
                  item.$3,
                  style: TextStyle(
                    fontSize: 13,
                    color: item.$1 == danger ? _overdueColor : null,
                  ),
                ),
              ],
            ),
          ),
    ],
  );
}

/// 할 일 삭제 (열려 있던 상세 패널도 닫음)
Future<void> _deleteTodo(WidgetRef ref, TodoItem todo) async {
  if (ref.read(todoSelectedProvider) == todo.id) {
    ref.read(todoSelectedProvider.notifier).select(null);
  }
  await ref.read(todoListProvider.notifier).delete(todo.id);
}

/// 오늘 진행: 오늘까지 해야 하는 남은 할 일 + 오늘 끝낸 할 일
({int done, int total}) todayProgress(Iterable<TodoItem> tops, DateTime now) {
  final todayKey = formatTodoDue(now);
  var done = 0, total = 0;
  for (final t in tops) {
    if (t.done) {
      if (t.doneAt?.startsWith(todayKey) ?? false) {
        done++;
        total++;
      }
    } else {
      final bucket = todoBucketOf(t.dueDate, now);
      if (bucket == TodoBucket.overdue || bucket == TodoBucket.today) total++;
    }
  }
  return (done: done, total: total);
}

// ───────────── 사이드 패널: 목록 고르기, 오늘 진행, 단축키

class TodoSidebarView extends ConsumerWidget {
  const TodoSidebarView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(todoListProvider).value ?? const <TodoItem>[];
    final showDone = ref.watch(todoShowDoneProvider);
    final notifier = ref.read(todoShowDoneProvider.notifier);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    final now = DateTime.now();
    final tops = all.where((t) => !t.isSubtask).toList();
    final open = tops.where((t) => !t.done).toList();
    final doneCount = tops.length - open.length;
    final overdue = open
        .where((t) => todoBucketOf(t.dueDate, now) == TodoBucket.overdue)
        .length;
    final progress = todayProgress(tops, now);

    return _NoPressEffect(
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '할 일',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
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
                  warn: overdue > 0,
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
                const SizedBox(height: 16),
                _TodayCard(done: progress.done, total: progress.total),
                if (overdue > 0)
                  _OverdueLink(
                    count: overdue,
                    onTap: () {
                      notifier.show(false);
                      ref
                          .read(todoCollapsedGroupsProvider.notifier)
                          .expand(TodoBucket.overdue);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
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

/// 오늘 진행 카드: 2/5 와 진행 막대
class _TodayCard extends StatelessWidget {
  final int done;
  final int total;
  const _TodayCard({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final message = total == 0
        ? '오늘까지 할 일이 없어요'
        : done == total
        ? '오늘 할 일을 모두 끝냈어요'
        : '${total - done}개 남았어요';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '오늘 진행',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '$done/$total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ProgressBar(value: total == 0 ? 0 : done / total, height: 6),
          const SizedBox(height: 6),
          Text(message, style: TextStyle(fontSize: 11, color: muted)),
        ],
      ),
    );
  }
}

class _OverdueLink extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _OverdueLink({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: InkWell(
        key: const ValueKey('todo-overdue-link'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              const Icon(Icons.error_outline, size: 15, color: _overdueColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '기한 지난 할 일 $count개',
                  style: const TextStyle(fontSize: 12, color: _overdueColor),
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: _overdueColor),
            ],
          ),
        ),
      ),
    );
  }
}

/// 할 일 화면에서는 누를 때 물결·눌림 효과를 끔 (마우스를 올렸을 때 색만)
class _NoPressEffect extends StatelessWidget {
  final Widget child;
  const _NoPressEffect({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: child,
    );
  }
}

// ───────────── 본문: 추가 카드, 묶음 카드, 상세 패널

/// 넓을 때 상세 패널을 옆에 두는 최소 폭 (좁으면 목록 위에 겹쳐 띄움)
const _sidePanelMinWidth = 760.0;
const _detailWidth = 340.0;

class TodoView extends ConsumerStatefulWidget {
  const TodoView({super.key});

  @override
  ConsumerState<TodoView> createState() => _TodoViewState();
}

class _TodoViewState extends ConsumerState<TodoView> {
  final _viewFocus = FocusNode(debugLabel: 'todo-view');
  final _addFocus = FocusNode(debugLabel: 'todo-add');
  final _search = TextEditingController();
  bool _searching = false;
  bool _byCreated = false; // 정렬: 기한순(false) / 최근 추가순(true)

  @override
  void dispose() {
    _viewFocus.dispose();
    _addFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  /// 할 일을 골라 상세 패널을 열고, 단축키를 받도록 목록에 포커스
  void _select(int id) {
    ref.read(todoSelectedProvider.notifier).select(id);
    _viewFocus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // 입력창에 있을 때는 글자 그대로
    if (event is! KeyDownEvent ||
        FocusManager.instance.primaryFocus != _viewFocus) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyN) {
      _addFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      ref.read(todoSelectedProvider.notifier).select(null);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      final id = ref.read(todoSelectedProvider);
      final all = ref.read(todoListProvider).value ?? const <TodoItem>[];
      final todo = all.where((t) => t.id == id).firstOrNull;
      if (todo != null) {
        ref.read(todoListProvider.notifier).setDone(todo.id, !todo.done);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _pickSort(Offset position) async {
    final choice = await _showActionMenu(context, position, [
      ('due', _byCreated ? Icons.event_outlined : Icons.check, '기한순'),
      ('created', _byCreated ? Icons.check : Icons.schedule, '최근 추가순'),
    ]);
    if (choice != null && mounted) {
      setState(() => _byCreated = choice == 'created');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(todoListProvider);
    final showDone = ref.watch(todoShowDoneProvider);
    final selectedId = ref.watch(todoSelectedProvider);
    final collapsed = ref.watch(todoCollapsedGroupsProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    final all = async.value;
    if (all == null) {
      return async.hasError
          ? Center(child: Text('할 일을 불러오지 못했습니다: ${async.error}'))
          : const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();
    final query = _searching ? _search.text.trim().toLowerCase() : '';
    bool matches(TodoItem t) =>
        query.isEmpty ||
        t.title.toLowerCase().contains(query) ||
        subtasksOf(all, t.id).any((s) => s.title.toLowerCase().contains(query));

    // 하위 할 일은 상위 할 일 아래에 함께 보여 줌
    final tops = all.where((t) => !t.isSubtask);
    final openCount = tops.where((t) => !t.done).length;
    final List<TodoItem> shown;
    if (showDone) {
      // 최근에 끝낸 것부터
      shown = tops.where((t) => t.done && matches(t)).toList()
        ..sort((a, b) => (b.doneAt ?? '').compareTo(a.doneAt ?? ''));
    } else {
      shown = tops.where((t) => !t.done && matches(t)).toList()
        ..sort(_byCreated ? (a, b) => b.id.compareTo(a.id) : compareTodos);
    }

    Widget entry(TodoItem todo, {bool overdue = false}) => _TodoEntry(
      key: ValueKey(todo.id),
      todo: todo,
      subtasks: subtasksOf(all, todo.id),
      overdue: overdue,
      selected: todo.id == selectedId,
      onSelect: () => _select(todo.id),
    );

    final title = showDone ? '완료' : '할 일';
    final emptyText = query.isNotEmpty
        ? '"${_search.text.trim()}"에 맞는 할 일이 없습니다'
        : showDone
        ? '완료한 할 일이 없습니다'
        : '남은 할 일이 없습니다';

    // 남은 할 일은 기한별로 묶어 보여 줌 (기한 지남 → 오늘 → 이번 주 → 나중에 → 기한 없음)
    final groups = <TodoBucket, List<TodoItem>>{};
    if (!showDone && !_byCreated) {
      for (final todo in shown) {
        groups.putIfAbsent(todoBucketOf(todo.dueDate, now), () => []).add(todo);
      }
    }

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 22, 20, 2),
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
              _ToolButton(
                key: const ValueKey('todo-search'),
                icon: Icons.search,
                active: _searching,
                onTap: (_) => setState(() {
                  _searching = !_searching;
                  if (!_searching) _search.clear();
                }),
              ),
              if (!showDone)
                _ToolButton(
                  key: const ValueKey('todo-sort'),
                  icon: Icons.sort,
                  label: _byCreated ? '최근 추가순' : '기한순',
                  onTap: _pickSort,
                ),
              if (showDone && shown.isNotEmpty)
                _ToolButton(
                  icon: Icons.delete_sweep_outlined,
                  label: '모두 지우기',
                  onTap: (_) => _confirmClearDone(
                    context,
                    tops.where((t) => t.done).length,
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 0, 24, 12),
          child: Row(
            children: [
              Text(
                '${now.month}월 ${now.day}일 ${_weekdays[now.weekday - 1]}요일',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              Text('  ·  ', style: TextStyle(fontSize: 12, color: muted)),
              Text(
                showDone ? '${tops.length - openCount}개 완료' : '$openCount개 남음',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape): () =>
                    setState(() {
                      _searching = false;
                      _search.clear();
                    }),
              },
              child: TextField(
                key: const ValueKey('todo-search-field'),
                controller: _search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '할 일 검색 (하위 할 일 포함)',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        if (!showDone)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
            child: _AddTodoField(focusNode: _addFocus),
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
                    if (showDone || _byCreated)
                      _GroupCard(
                        count: shown.length,
                        children: [for (final todo in shown) entry(todo)],
                      )
                    else
                      for (final bucket in TodoBucket.values)
                        if (groups[bucket] case final items?)
                          _GroupCard(
                            bucket: bucket,
                            count: items.length,
                            collapsed: collapsed.contains(bucket),
                            children: [
                              for (final todo in items)
                                entry(
                                  todo,
                                  overdue: bucket == TodoBucket.overdue,
                                ),
                            ],
                          ),
                  ],
                ),
        ),
      ],
    );

    final selected = selectedId == null
        ? null
        : all.where((t) => t.id == selectedId && !t.isSubtask).firstOrNull;

    return _NoPressEffect(
      child: Focus(
        focusNode: _viewFocus,
        onKeyEvent: _onKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final panel = selected == null
                ? null
                : _TodoDetailPanel(
                    key: ValueKey('todo-detail-${selected.id}'),
                    todo: selected,
                    subtasks: subtasksOf(all, selected.id),
                  );
            final wide = constraints.maxWidth >= _sidePanelMinWidth;
            // 패널을 열고 닫아도 목록의 위치(트리 구조)는 그대로 둠.
            // 구조가 바뀌면 목록 전체를 새로 만들어 클릭할 때 끊김이 생김.
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: list),
                      // 좁은 창: 목록 위에 겹쳐 띄움
                      if (panel != null && !wide)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          width: constraints.maxWidth < _detailWidth
                              ? constraints.maxWidth
                              : _detailWidth,
                          child: Material(elevation: 8, child: panel),
                        ),
                    ],
                  ),
                ),
                if (panel != null && wide) ...[
                  VerticalDivider(width: 1, color: context.lineSubtle),
                  SizedBox(width: _detailWidth, child: panel),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmClearDone(BuildContext context, int count) async {
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

/// 제목 줄 오른쪽 도구 버튼 (툴팁 없음)
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool active;
  final void Function(Offset position) onTap;
  const _ToolButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.label,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final color = active ? context.accent : muted;
    Offset? down;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Material(
        color: active ? context.selectedTint : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTapDown: (d) => down = d.globalPosition,
          onTap: () {
            final box = context.findRenderObject() as RenderBox?;
            onTap(
              down ??
                  (box == null
                      ? Offset.zero
                      : box.localToGlobal(box.size.bottomLeft(Offset.zero))),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                if (label != null) ...[
                  const SizedBox(width: 4),
                  Text(label!, style: TextStyle(fontSize: 12, color: color)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 새 할 일 카드. Enter로 추가, Tab(또는 "하위 할 일" 칩)으로 하위 할 일 줄,
/// 아래 칩으로 기한·메모 연결.
class _AddTodoField extends ConsumerStatefulWidget {
  final FocusNode focusNode;
  const _AddTodoField({required this.focusNode});

  @override
  ConsumerState<_AddTodoField> createState() => _AddTodoFieldState();
}

class _SubLine {
  final controller = TextEditingController();
  final focusNode = FocusNode();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class _AddTodoFieldState extends ConsumerState<_AddTodoField> {
  final _controller = TextEditingController();
  FocusNode get _focusNode => widget.focusNode;
  final _subs = <_SubLine>[];
  DateTime? _due;
  ({int id, String title})? _note; // 연결할 메모
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = _onTitleKey;
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final line in _subs) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    final subtasks = [for (final line in _subs) line.controller.text];
    final noteId = _note?.id;
    final old = [..._subs];
    setState(() {
      _subs.clear();
      _note = null;
    });
    _controller.clear();
    _focusNode.requestFocus(); // 이어서 입력
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final line in old) {
        line.dispose();
      }
    });
    await ref
        .read(todoListProvider.notifier)
        .add(text, due: _due, subtasks: subtasks, noteId: noteId);
  }

  /// [after] 다음에 하위 할 일 줄을 넣고 그 줄로 커서
  void _addSubLine({int? after}) {
    final line = _SubLine();
    line.focusNode.onKeyEvent = (node, event) => _onSubKey(line, event);
    setState(
      () => _subs.insert(after == null ? _subs.length : after + 1, line),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => line.focusNode.requestFocus(),
    );
  }

  void _removeSubLine(_SubLine line) {
    final index = _subs.indexOf(line);
    if (index < 0) return;
    setState(() => _subs.removeAt(index));
    (index > 0 ? _subs[index - 1].focusNode : _focusNode).requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
  }

  KeyEventResult _onTitleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.tab &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _subs.isEmpty ? _addSubLine() : _subs.first.focusNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onSubKey(_SubLine line, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final empty = line.controller.text.isEmpty;
    // 빈 줄에서 Backspace·Esc: 그 줄을 지움
    if (empty &&
        (event.logicalKey == LogicalKeyboardKey.backspace ||
            event.logicalKey == LogicalKeyboardKey.escape)) {
      _removeSubLine(line);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// 하위 할 일 줄에서 Enter: 글이 있으면 다음 줄, 빈 줄이면 모두 추가
  void _onSubSubmitted(_SubLine line) {
    if (line.controller.text.trim().isEmpty) {
      _submit();
    } else {
      _addSubLine(after: _subs.indexOf(line));
    }
  }

  Future<void> _pickDue(Offset position) async {
    final result = await showTodoDueMenu(context, position, current: _due);
    if (result != null && mounted) setState(() => _due = result.due);
    _focusNode.requestFocus();
  }

  Future<void> _pickNote() async {
    final note = await pickMemo(context);
    if (!mounted) return;
    if (note != null) {
      setState(
        () => _note = (
          id: note.id!,
          title: note.title.trim().isEmpty ? '제목 없음' : note.title,
        ),
      );
    }
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final due = _due;
    final note = _note;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _submit,
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (focused) => setState(() => _focused = focused),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(14, 2, 10, 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _focused
                  ? context.accent.withValues(alpha: 0.6)
                  : context.lineSubtle,
              width: _focused ? 1.4 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
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
                          hintText: '할 일 추가 (Enter) · 하위 할 일 (Tab)',
                          hintStyle: TextStyle(color: muted),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final line in _subs)
                SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      Container(
                        width: 2,
                        height: 34,
                        color: context.lineSubtle,
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.check_box_outline_blank,
                        size: 15,
                        color: muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: line.controller,
                          focusNode: line.focusNode,
                          // Enter 뒤에도 포커스를 잃지 않게 (다음 줄로 옮김)
                          onEditingComplete: () {},
                          onSubmitted: (_) => _onSubSubmitted(line),
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: '하위 할 일',
                            hintStyle: TextStyle(color: muted),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 14,
                        color: muted,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        onPressed: () => _removeSubLine(line),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _TapChip(
                          key: const ValueKey('todo-add-due'),
                          onTapDown: _pickDue,
                          chip: _Chip(
                            icon: due == null
                                ? Icons.event_outlined
                                : Icons.event,
                            label: due == null
                                ? '기한'
                                : dueLabel(due, DateTime.now()),
                            color: due == null ? null : context.accent,
                          ),
                        ),
                        _TapChip(
                          key: const ValueKey('todo-add-sub'),
                          onTapDown: (_) => _addSubLine(),
                          chip: _Chip(
                            icon: Icons.subdirectory_arrow_right,
                            label: _subs.isEmpty
                                ? '하위 할 일'
                                : '하위 할 일 ${_subs.length}',
                          ),
                        ),
                        _TapChip(
                          key: const ValueKey('todo-add-memo'),
                          onTapDown: (_) => _pickNote(),
                          chip: _Chip(
                            icon: Icons.description_outlined,
                            label: note == null ? '메모 연결' : note.title,
                            color: note == null ? null : context.accent,
                            onClear: note == null
                                ? null
                                : () => setState(() => _note = null),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_subs.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '빈 줄 Enter · Ctrl+Enter',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ),
                  Material(
                    color: context.accent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      key: const ValueKey('todo-add-submit'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        child: Text(
                          '추가',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 눌러지는 칩 (누른 위치를 넘김: 메뉴 위치용)
class _TapChip extends StatelessWidget {
  final Widget chip;
  final void Function(Offset position) onTapDown;
  const _TapChip({super.key, required this.chip, required this.onTapDown});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (d) => onTapDown(d.globalPosition),
    child: MouseRegion(cursor: SystemMouseCursors.click, child: chip),
  );
}

/// 기한 묶음 카드. 제목 줄을 눌러 접고 펼침. [bucket]이 없으면 제목 없이 한 덩어리.
class _GroupCard extends ConsumerWidget {
  final TodoBucket? bucket;
  final int count;
  final bool collapsed;
  final List<Widget> children;
  const _GroupCard({
    this.bucket,
    required this.count,
    required this.children,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final bucket = this.bucket;
    final labelColor = bucket == null ? null : todoBucketColor(context, bucket);
    final colored = bucket != null && bucket != TodoBucket.none;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colored
              ? labelColor!.withValues(alpha: 0.35)
              : context.lineSubtle,
        ),
      ),
      // 카드 왼쪽 색 띠 (둥근 모서리 안쪽으로 잘리게 자식으로 둠)
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: colored
              ? Border(left: BorderSide(color: labelColor!, width: 3))
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (bucket != null)
                InkWell(
                  key: ValueKey('todo-group-${bucket.name}'),
                  onTap: () => ref
                      .read(todoCollapsedGroupsProvider.notifier)
                      .toggle(bucket),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                    child: Row(
                      children: [
                        Icon(
                          collapsed ? Icons.chevron_right : Icons.expand_more,
                          size: 18,
                          color: labelColor ?? muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          bucket.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: (labelColor ?? muted).withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: labelColor ?? muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!collapsed) ...[
                if (bucket != null)
                  Divider(height: 1, thickness: 1, color: context.lineSubtle),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 할 일 하나와 그 하위 할 일 트리 (진행 막대, 하위 할 일, 추가 줄)
class _TodoEntry extends ConsumerStatefulWidget {
  final TodoItem todo;
  final List<TodoItem> subtasks;
  final bool overdue;
  final bool selected;
  final VoidCallback onSelect;
  const _TodoEntry({
    super.key,
    required this.todo,
    required this.subtasks,
    required this.onSelect,
    this.overdue = false,
    this.selected = false,
  });

  @override
  ConsumerState<_TodoEntry> createState() => _TodoEntryState();
}

class _TodoEntryState extends ConsumerState<_TodoEntry> {
  bool _addingSub = false;

  void _startAddSub() {
    ref.read(todoCollapsedTreesProvider.notifier).expand(widget.todo.id);
    setState(() => _addingSub = true);
  }

  @override
  Widget build(BuildContext context) {
    final todo = widget.todo;
    final subs = widget.subtasks;
    final collapsed = ref.watch(todoCollapsedTreesProvider).contains(todo.id);
    final showTree = (subs.isNotEmpty && !collapsed) || _addingSub;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final doneSubs = subs.where((s) => s.done).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TodoRow(
          todo: todo,
          subtasks: subs,
          overdue: widget.overdue,
          selected: widget.selected,
          expanded: subs.isEmpty ? null : !collapsed,
          onToggleTree: () =>
              ref.read(todoCollapsedTreesProvider.notifier).toggle(todo.id),
          onAddSubtask: todo.done ? null : _startAddSub,
          onSelect: widget.onSelect,
        ),
        if (showTree)
          Container(
            margin: const EdgeInsets.only(left: 41, bottom: 4),
            padding: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: context.lineSubtle, width: 2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (subs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                    child: Row(
                      children: [
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: _ProgressBar(
                              value: doneSubs / subs.length,
                              height: 4,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$doneSubs/${subs.length} 완료',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                for (final sub in subs)
                  _TodoRow(
                    key: ValueKey(sub.id),
                    todo: sub,
                    onSelect: widget.onSelect,
                  ),
                if (!todo.done)
                  _addingSub
                      ? _SubtaskField(
                          parentId: todo.id,
                          onClose: () => setState(() => _addingSub = false),
                        )
                      : _AddSubButton(onTap: _startAddSub),
              ],
            ),
          ),
      ],
    );
  }
}

class _AddSubButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddSubButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      key: const ValueKey('todo-tree-add'),
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.add, size: 16, color: muted),
            const SizedBox(width: 10),
            Text('하위 할 일 추가', style: TextStyle(fontSize: 13, color: muted)),
          ],
        ),
      ),
    );
  }
}

/// 기존 할 일 아래에 하위 할 일 추가. Enter로 추가하고 이어서 입력, 빈 채로 Enter·Esc면 닫음.
class _SubtaskField extends ConsumerStatefulWidget {
  final int parentId;
  final VoidCallback onClose;
  const _SubtaskField({required this.parentId, required this.onClose});

  @override
  ConsumerState<_SubtaskField> createState() => _SubtaskFieldState();
}

class _SubtaskFieldState extends ConsumerState<_SubtaskField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _controller.text.trim().isEmpty) {
        widget.onClose();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return widget.onClose();
    _controller.clear();
    ref.read(todoListProvider.notifier).addSubtask(widget.parentId, text);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.add, size: 16, color: context.accent),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const ValueKey('todo-sub-field'),
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                onEditingComplete: () {}, // Enter 뒤에도 이어서 입력
                onSubmitted: (_) => _submit(),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '하위 할 일 추가 (Enter)',
                  hintStyle: TextStyle(color: muted),
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 할 일 한 줄. 누르면 상세 패널, 마우스를 올리면 기한·하위·메모·⋯ 버튼.
/// 하위 할 일이면 체크·제목과 ⋯(이름 바꾸기·삭제)만.
class _TodoRow extends ConsumerStatefulWidget {
  final TodoItem todo;
  final List<TodoItem> subtasks;
  final bool overdue;
  final bool selected;

  /// 하위 할 일 펼침 상태 (null이면 펼칠 것이 없음)
  final bool? expanded;
  final VoidCallback? onToggleTree;
  final VoidCallback? onAddSubtask;
  final VoidCallback onSelect;
  const _TodoRow({
    super.key,
    required this.todo,
    required this.onSelect,
    this.subtasks = const [],
    this.overdue = false,
    this.selected = false,
    this.expanded,
    this.onToggleTree,
    this.onAddSubtask,
  });

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
  bool get _isSub => widget.todo.isSubtask;

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
    // 하위 할 일은 그 자리에서 체크만 (목록에서 빠지지 않음)
    if (todo.done || _isSub) {
      await todos.setDone(todo.id, !todo.done);
      return;
    }
    setState(() => _completing = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await todos.setDone(todo.id, true);
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

  /// 더보기 메뉴: 이름 바꾸기, 하위 할 일 추가, 메모에 추가, 삭제
  /// (하위 할 일은 이름 바꾸기·삭제만)
  Future<void> _showMore(Offset position) async {
    if (_editing) _finishEdit(save: true);
    final todo = widget.todo;
    final choice = await _showActionMenu(context, position, [
      if (!todo.done) ('rename', Icons.edit_outlined, '이름 바꾸기'),
      if (!_isSub) ('open', Icons.open_in_new, '상세 열기'),
      if (!todo.done && widget.onAddSubtask != null)
        ('sub', Icons.subdirectory_arrow_right, '하위 할 일 추가'),
      if (!_isSub) ('memo', Icons.note_add_outlined, '메모에 추가…'),
      null,
      ('delete', Icons.delete_outline, '삭제'),
    ], danger: 'delete');
    if (!mounted) return;
    switch (choice) {
      case 'rename':
        _startEdit();
      case 'open':
        widget.onSelect();
      case 'sub':
        widget.onAddSubtask?.call();
      case 'memo':
        await addTodoToMemo(context, ref, todo, widget.subtasks);
      case 'delete':
        await _deleteTodo(ref, todo);
    }
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
    final now = DateTime.now();
    final checked = todo.done || _completing;
    final fontSize = _isSub ? 14.0 : 15.0;
    final selected = widget.selected && !_isSub;

    final Widget title = _editing
        ? CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () =>
                  _finishEdit(save: false),
            },
            child: TextField(
              key: const ValueKey('todo-rename-field'),
              controller: _editController,
              focusNode: _editFocus,
              onSubmitted: (_) => _finishEdit(save: true),
              style: TextStyle(fontSize: fontSize),
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
              fontSize: fontSize,
              fontWeight: selected ? FontWeight.w600 : null,
              decoration: checked ? TextDecoration.lineThrough : null,
              color: checked ? muted : null,
            ),
          );

    // 제목 아래 작은 정보: 연결된 메모, 하위 할 일 진행
    final subs = widget.subtasks;
    final meta = <Widget>[
      if (todo.noteId != null && !_isSub) _MemoLink(noteId: todo.noteId!),
      if (subs.isNotEmpty)
        _Meta(
          icon: Icons.checklist,
          label: '${subs.where((s) => s.done).length}/${subs.length}',
        ),
    ];

    // 오른쪽: 평소에는 기한 글자, 마우스를 올리면 동작 버튼
    final showActions = _hovering || _editing;
    final Widget? dueText = due == null || _isSub
        ? null
        : Text(
            dueLabel(due, now),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: todo.done
                  ? muted
                  : todoBucketColor(context, todoBucketOf(due, now)),
            ),
          );

    // 더보기 버튼은 이름을 고치는 중에도 눌리도록 입력창 영역으로 묶음
    // (입력창 밖을 누르면 포커스가 풀리며 버튼이 사라져 클릭이 먹히지 않던 문제)
    final more = TextFieldTapRegion(
      child: _RowAction(
        key: ValueKey(_isSub ? 'todo-sub-more' : 'todo-more'),
        icon: Icons.more_horiz,
        onTapDown: _showMore,
      ),
    );
    final actions = <Widget>[
      if (!_isSub && !todo.done) ...[
        _RowAction(
          key: const ValueKey('todo-act-due'),
          icon: Icons.event_outlined,
          label: due == null ? '기한' : dueLabel(due, now),
          onTapDown: _pickDue,
        ),
        if (widget.onAddSubtask != null)
          _RowAction(
            key: const ValueKey('todo-act-sub'),
            icon: Icons.subdirectory_arrow_right,
            label: '하위',
            onTapDown: (_) => widget.onAddSubtask!(),
          ),
        _RowAction(
          key: const ValueKey('todo-act-memo'),
          icon: Icons.note_add_outlined,
          label: '메모',
          onTapDown: (_) => addTodoToMemo(context, ref, todo, subs),
        ),
      ],
      more,
    ];

    final row = Padding(
      padding: EdgeInsets.fromLTRB(_isSub ? 12 : 4, 6, 8, 6),
      child: Row(
        children: [
          if (!_isSub)
            SizedBox(
              width: 24,
              child: widget.expanded == null
                  ? null
                  : GestureDetector(
                      key: const ValueKey('todo-tree'),
                      onTap: widget.onToggleTree,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Icon(
                          widget.expanded!
                              ? Icons.expand_more
                              : Icons.chevron_right,
                          size: 18,
                          color: muted,
                        ),
                      ),
                    ),
            ),
          // 툴팁은 넣지 않음: Flutter 3.38에서 목록 순서가 바뀔 때 툴팁이
          // 레이아웃 전에 다시 그려지며 Null check 오류가 남 (할 일 추가 시)
          InkWell(
            key: ValueKey(_isSub ? 'todo-sub-check' : 'todo-check'),
            borderRadius: BorderRadius.circular(6),
            onTap: _toggleDone,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: _CheckBox(checked: checked),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: _isSub ? 0 : 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Wrap(spacing: 12, children: meta),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (showActions)
            for (final (i, action) in actions.indexed) ...[
              if (i > 0) const SizedBox(width: 4),
              action,
            ]
          else ...[
            ?dueText,
            // 버튼 자리를 잡아 둬서 마우스를 올려도 제목 폭이 덜 흔들림
            const SizedBox(width: 32),
          ],
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _completing ? 0.5 : 1,
        child: Stack(
          children: [
            Material(
              color: selected
                  ? context.selectedTint
                  : _hovering || _editing
                  ? scheme.surfaceContainerHigh
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              // 줄을 누르면 상세 패널 (하위 할 일은 상위 할 일의 상세).
              // 물결 효과 없이 선택 배경색으로만 표시 (가볍게)
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onSelect,
                child: row,
              ),
            ),
            if (selected)
              Positioned(
                left: 0,
                top: 8,
                bottom: 8,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: context.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 줄 위에 마우스를 올렸을 때 보이는 버튼 (글자가 있으면 글자 버튼)
class _RowAction extends StatelessWidget {
  final IconData icon;
  final String? label;
  final void Function(Offset position) onTapDown;
  const _RowAction({
    super.key,
    required this.icon,
    required this.onTapDown,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    return GestureDetector(
      onTapDown: (d) => onTapDown(d.globalPosition),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 26,
          constraints: BoxConstraints(minWidth: label == null ? 28 : 0),
          padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 7),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: context.lineSubtle),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: muted),
              if (label != null) ...[
                const SizedBox(width: 4),
                Text(label!, style: TextStyle(fontSize: 12, color: muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 제목 아래 작은 정보 한 개
class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _Meta({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final fg = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: fg),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: fg),
          ),
        ),
      ],
    );
  }
}

/// 연결된 메모: 누르면 메모 화면으로
class _MemoLink extends ConsumerWidget {
  final int noteId;
  const _MemoLink({required this.noteId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titles = ref.watch(todoNoteTitlesProvider).value;
    final title = titles?[noteId];
    if (titles != null && title == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => openTodoMemo(ref, noteId),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: _Meta(
          icon: Icons.description_outlined,
          label: title ?? '메모',
          color: context.accent,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final double height;
  const _ProgressBar({required this.value, required this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: height,
        color: context.accent,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

// ───────────── 상세 패널

class _TodoDetailPanel extends ConsumerStatefulWidget {
  final TodoItem todo;
  final List<TodoItem> subtasks;
  const _TodoDetailPanel({
    super.key,
    required this.todo,
    required this.subtasks,
  });

  @override
  ConsumerState<_TodoDetailPanel> createState() => _TodoDetailPanelState();
}

class _TodoDetailPanelState extends ConsumerState<_TodoDetailPanel> {
  late final _title = TextEditingController(text: widget.todo.title);
  final _titleFocus = FocusNode();
  final _sub = TextEditingController();
  final _subFocus = FocusNode();

  TodoListNotifier get _todos => ref.read(todoListProvider.notifier);

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) _saveTitle();
    });
  }

  @override
  void didUpdateWidget(covariant _TodoDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 다른 곳(줄의 이름 바꾸기)에서 고친 제목을 따라감
    if (oldWidget.todo.title != widget.todo.title && !_titleFocus.hasFocus) {
      _title.text = widget.todo.title;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _titleFocus.dispose();
    _sub.dispose();
    _subFocus.dispose();
    super.dispose();
  }

  void _saveTitle() {
    final text = _title.text.trim();
    if (text.isEmpty) {
      _title.text = widget.todo.title;
    } else if (text != widget.todo.title) {
      _todos.rename(widget.todo.id, text);
    }
  }

  void _close() => ref.read(todoSelectedProvider.notifier).select(null);

  void _addSub() {
    final text = _sub.text.trim();
    if (text.isEmpty) return;
    _sub.clear();
    _todos.addSubtask(widget.todo.id, text);
    _subFocus.requestFocus();
  }

  Future<void> _pickDue(Offset position) async {
    final result = await showTodoDueMenu(
      context,
      position,
      current: widget.todo.dueDate,
    );
    if (result != null) await _todos.setDue(widget.todo.id, result.due);
  }

  Future<void> _linkMemo() async {
    final note = await pickMemo(context);
    if (note != null) await _todos.setNote(widget.todo.id, note.id);
  }

  @override
  Widget build(BuildContext context) {
    final todo = widget.todo;
    final subs = widget.subtasks;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final now = DateTime.now();
    final due = todo.dueDate;
    final doneSubs = subs.where((s) => s.done).length;
    final noteId = todo.noteId;
    final noteTitle = noteId == null
        ? null
        : ref.watch(todoNoteTitlesProvider).value?[noteId];
    final created = DateTime.tryParse(todo.createdAt);

    final dueColor = due == null || todo.done
        ? null
        : todoBucketColor(context, todoBucketOf(due, now));

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Container(
        key: const ValueKey('todo-detail'),
        color: scheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 10, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '할 일 상세',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                  ),
                  _RowAction(
                    key: const ValueKey('todo-detail-close'),
                    icon: Icons.close,
                    onTapDown: (_) => _close(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: InkWell(
                          key: const ValueKey('todo-detail-check'),
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => _todos.setDone(todo.id, !todo.done),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: _CheckBox(checked: todo.done),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('todo-detail-title'),
                          controller: _title,
                          focusNode: _titleFocus,
                          maxLines: null,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _titleFocus.unfocus(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            decoration: todo.done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DetailField(
                    key: const ValueKey('todo-detail-due'),
                    icon: Icons.event_outlined,
                    label: '기한',
                    value: due == null ? '없음' : dueLabel(due, now),
                    valueColor: dueColor,
                    onTapDown: _pickDue,
                  ),
                  _DetailField(
                    key: const ValueKey('todo-detail-memo'),
                    icon: Icons.description_outlined,
                    label: '메모',
                    value: noteId == null ? '연결 안 함' : noteTitle ?? '메모',
                    valueColor: noteId == null ? null : context.accent,
                    onTapDown: (_) => noteId == null
                        ? _linkMemo()
                        : openTodoMemo(ref, noteId),
                    onClear: noteId == null
                        ? null
                        : () => _todos.setNote(todo.id, null),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        '하위 할 일',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: muted,
                        ),
                      ),
                      const Spacer(),
                      if (subs.isNotEmpty)
                        Text(
                          '$doneSubs/${subs.length}',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                    ],
                  ),
                  if (subs.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _ProgressBar(value: doneSubs / subs.length, height: 4),
                  ],
                  const SizedBox(height: 4),
                  for (final sub in subs) _DetailSubRow(sub: sub),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            Icons.add,
                            size: 17,
                            color: context.accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('todo-detail-sub-field'),
                            controller: _sub,
                            focusNode: _subFocus,
                            onEditingComplete: () {}, // 이어서 입력
                            onSubmitted: (_) => _addSub(),
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '하위 할 일 추가 (Enter)',
                              hintStyle: TextStyle(color: muted),
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 6,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.lineSubtle),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    key: const ValueKey('todo-detail-to-memo'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.accent,
                      foregroundColor: scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => addTodoToMemo(context, ref, todo, subs),
                    icon: const Icon(Icons.playlist_add_check, size: 18),
                    label: const Text('메모에 체크리스트로 추가'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          created == null
                              ? ''
                              : '만든 날 ${created.year}/${created.month}/${created.day}',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ),
                      TextButton.icon(
                        key: const ValueKey('todo-detail-delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: _overdueColor,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _deleteTodo(ref, todo),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('삭제', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 상세 패널의 한 칸: 아이콘 · 이름 · 값 (눌러서 바꾸기)
class _DetailField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final void Function(Offset position) onTapDown;
  final VoidCallback? onClear;
  const _DetailField({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTapDown,
    this.valueColor,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    Offset? down;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTapDown: (d) => down = d.globalPosition,
        onTap: () => onTapDown(down ?? Offset.zero),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 16, color: muted),
              const SizedBox(width: 10),
              SizedBox(
                width: 44,
                child: Text(
                  label,
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Icon(Icons.close, size: 14, color: muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 상세 패널의 하위 할 일 한 줄 (체크, 제목, 마우스를 올리면 지우기)
class _DetailSubRow extends ConsumerStatefulWidget {
  final TodoItem sub;
  const _DetailSubRow({required this.sub});

  @override
  ConsumerState<_DetailSubRow> createState() => _DetailSubRowState();
}

class _DetailSubRowState extends ConsumerState<_DetailSubRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final sub = widget.sub;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => ref
                  .read(todoListProvider.notifier)
                  .setDone(sub.id, !sub.done),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: _CheckBox(checked: sub.done),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                sub.title,
                style: TextStyle(
                  fontSize: 14,
                  decoration: sub.done ? TextDecoration.lineThrough : null,
                  color: sub.done ? muted : null,
                ),
              ),
            ),
            SizedBox(
              width: 24,
              child: _hovering
                  ? GestureDetector(
                      onTap: () => _deleteTodo(ref, sub),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Icon(Icons.close, size: 14, color: muted),
                      ),
                    )
                  : null,
            ),
          ],
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

  /// 있으면 오른쪽에 작은 x (지우기)
  final VoidCallback? onClear;
  const _Chip({
    required this.icon,
    required this.label,
    this.color,
    this.onClear,
  });

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
          if (onClear != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, size: 12, color: fg),
            ),
          ],
        ],
      ),
    );
  }
}
