import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/database/database.dart';
import '../../core/database/database_provider.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/theme/app_colors.dart';
import 'todo_provider.dart';
import 'todo_views.dart';

/// 스티커 모드: 앱 창을 작게 줄여 다른 창 위에 띄워 두는 할 일 메모.
/// 끄면 원래 창 크기·위치로 돌아감.

/// 스티커 창 크기·위치 (이 PC에서만 쓰는 값, 드라이브 동기화에서 제외)
const stickerBoundsKey = 'sticker_bounds';

/// 창 조작 (테스트에서는 바꿔 끼움)
class StickerWindow {
  StickerWindow(this._db);

  final AppDatabase _db;

  static const defaultSize = Size(300, 420);
  static const minimumSize = Size(220, 160);
  static const normalMinimumSize = Size(650, 400);

  Rect? _normal;
  bool _wasMaximized = false;

  Future<void> enter() async {
    _wasMaximized = await windowManager.isMaximized();
    if (_wasMaximized) await windowManager.unmaximize();
    final normal = _normal = await windowManager.getBounds();
    final saved = await _loadBounds();
    final bounds = saved != null && await _isOnScreen(saved)
        ? saved
        : Rect.fromLTWH(
            normal.right - defaultSize.width - 24,
            normal.top + 48,
            defaultSize.width,
            defaultSize.height,
          );
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setMinimumSize(minimumSize);
    await windowManager.setBounds(bounds);
    await windowManager.setAlwaysOnTop(true);
  }

  Future<void> exit() async {
    await _saveBounds(await windowManager.getBounds());
    await windowManager.setAlwaysOnTop(false);
    await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    await windowManager.setMinimumSize(normalMinimumSize);
    final normal = _normal;
    if (normal != null) await windowManager.setBounds(normal);
    if (_wasMaximized) await windowManager.maximize();
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> setAlwaysOnTop(bool value) =>
      windowManager.setAlwaysOnTop(value);

  Future<void> startDragging() => windowManager.startDragging();

  Future<Rect?> _loadBounds() async {
    final row = await (_db.select(
      _db.settingTable,
    )..where((t) => t.key.equals(stickerBoundsKey))).getSingleOrNull();
    return parseStickerBounds(row?.value);
  }

  Future<void> _saveBounds(Rect bounds) async {
    await _db
        .into(_db.settingTable)
        .insertOnConflictUpdate(
          SettingTableCompanion(
            key: const Value(stickerBoundsKey),
            value: Value(formatStickerBounds(bounds)),
          ),
        );
  }

  /// 모니터 구성이 바뀌어 화면 밖이 되면 기본 위치로
  Future<bool> _isOnScreen(Rect bounds) async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      return displays.any((d) {
        final origin = d.visiblePosition ?? Offset.zero;
        final size = d.visibleSize ?? d.size;
        return (origin & size).contains(bounds.topCenter + const Offset(0, 8));
      });
    } catch (_) {
      return true;
    }
  }
}

String formatStickerBounds(Rect r) =>
    [r.left, r.top, r.width, r.height].map((v) => v.round()).join(',');

Rect? parseStickerBounds(String? value) {
  final parts = value?.split(',').map(double.tryParse).toList();
  if (parts == null || parts.length != 4 || parts.contains(null)) return null;
  final [left, top, width, height] = parts.cast<double>();
  if (width < StickerWindow.minimumSize.width ||
      height < StickerWindow.minimumSize.height) {
    return null;
  }
  return Rect.fromLTWH(left, top, width, height);
}

final stickerWindowProvider = Provider<StickerWindow>(
  (ref) => StickerWindow(ref.read(databaseProvider)),
);

/// 스티커 모드 상태 (켜짐 여부, 항상 위)
typedef StickerState = ({bool on, bool pinned});

class StickerModeNotifier extends Notifier<StickerState> {
  bool _busy = false;

  @override
  StickerState build() => (on: false, pinned: true);

  Future<void> enter() async {
    if (state.on || _busy) return;
    final window = ref.read(stickerWindowProvider);
    _busy = true;
    try {
      // 창을 줄이기 전에 화면을 먼저 바꿔 큰 화면이 작게 찌그러져 보이지 않게
      state = (on: true, pinned: true);
      await window.enter();
    } finally {
      _busy = false;
    }
  }

  /// 원래 창으로. [openTodo]가 있으면 할 일 탭에서 그 할 일을 엶
  Future<void> exit({int? openTodo}) async {
    if (!state.on || _busy) return;
    final window = ref.read(stickerWindowProvider);
    final navigation = ref.read(navigationProvider.notifier);
    final selection = ref.read(todoSelectedProvider.notifier);
    _busy = true;
    try {
      await window.exit();
      state = (on: false, pinned: state.pinned);
      if (openTodo != null) {
        navigation.navigateTo(todoTabIndex);
        selection.select(openTodo);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> togglePinned() async {
    final pinned = !state.pinned;
    state = (on: state.on, pinned: pinned);
    await ref.read(stickerWindowProvider).setAlwaysOnTop(pinned);
  }
}

final stickerModeProvider = NotifierProvider<StickerModeNotifier, StickerState>(
  StickerModeNotifier.new,
);

/// 스티커 모드 화면: 남은 할 일 목록과 빠른 추가
class StickerTodoView extends ConsumerStatefulWidget {
  const StickerTodoView({super.key});

  @override
  ConsumerState<StickerTodoView> createState() => _StickerTodoViewState();
}

class _StickerTodoViewState extends ConsumerState<StickerTodoView> {
  final _add = TextEditingController();
  final _addFocus = FocusNode(debugLabel: 'sticker-add');

  /// 스티커에서 방금 끝낸 할 일 (실수로 눌렀을 때 되돌릴 수 있게 줄을 그어 남겨 둠)
  final _justDone = <int>{};

  /// 펼쳐서 하위 할 일을 보여 주는 할 일 (한 번에 하나)
  int? _expanded;

  @override
  void dispose() {
    _add.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  /// 새로 추가할 할 일의 기한
  DateTime? _newDue;

  Future<void> _submit() async {
    final text = _add.text.trim();
    if (text.isEmpty) return;
    final due = _newDue;
    _add.clear();
    setState(() => _newDue = null);
    _addFocus.requestFocus();
    await ref.read(todoListProvider.notifier).add(text, due: due);
  }

  Future<void> _pickNewDue(Offset position) async {
    final picked = await showTodoDueMenu(context, position, current: _newDue);
    if (picked == null || !mounted) return;
    setState(() => _newDue = picked.due);
    _addFocus.requestFocus();
  }

  Future<void> _pickDue(TodoItem todo, Offset position) async {
    final picked = await showTodoDueMenu(
      context,
      position,
      current: todo.dueDate,
    );
    if (picked == null || !mounted) return;
    await ref.read(todoListProvider.notifier).setDue(todo.id, picked.due);
  }

  void _toggle(TodoItem todo) {
    final done = !todo.done;
    setState(() => done ? _justDone.add(todo.id) : _justDone.remove(todo.id));
    ref.read(todoListProvider.notifier).setDone(todo.id, done);
  }

  @override
  Widget build(BuildContext context) {
    final sticker = ref.watch(stickerModeProvider);
    final all = ref.watch(todoListProvider).value ?? const <TodoItem>[];
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final now = DateTime.now();

    final tops = all.where((t) => !t.isSubtask);
    final open = tops.where((t) => !t.done).toList()..sort(compareTodos);
    final done = tops.where((t) => t.done && _justDone.contains(t.id)).toList();
    final shown = [...open, ...done];

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 제목 줄: 끌어서 창 옮기기
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => ref.read(stickerWindowProvider).startDragging(),
            child: Container(
              height: 36,
              padding: const EdgeInsets.only(left: 12, right: 4),
              color: scheme.surfaceContainerLow,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '할 일 · ${open.length}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _BarButton(
                    key: const ValueKey('sticker-pin'),
                    icon: sticker.pinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                    tooltip: sticker.pinned ? '항상 위 끄기' : '항상 위',
                    color: sticker.pinned ? context.accent : muted,
                    onTap: () =>
                        ref.read(stickerModeProvider.notifier).togglePinned(),
                  ),
                  _BarButton(
                    key: const ValueKey('sticker-exit'),
                    icon: Icons.open_in_full,
                    tooltip: '원래 창으로',
                    color: muted,
                    onTap: () => ref.read(stickerModeProvider.notifier).exit(),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: context.lineSubtle),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: TextField(
              key: const ValueKey('sticker-add'),
              controller: _add,
              focusNode: _addFocus,
              style: const TextStyle(fontSize: 13),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: '할 일 추가',
                prefixIcon: const Icon(Icons.add, size: 16),
                prefixIconConstraints: const BoxConstraints(minWidth: 30),
                // 기한: 고르면 "내일" 같은 글자로 보이고, 누르면 다시 고름
                suffixIcon: _DueButton(
                  key: const ValueKey('sticker-add-due'),
                  due: _newDue,
                  now: now,
                  onTap: _pickNewDue,
                ),
                suffixIconConstraints: const BoxConstraints(minWidth: 30),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Text(
                      '남은 할 일이 없습니다',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
                    children: [
                      for (final todo in shown)
                        _StickerRow(
                          key: ValueKey('sticker-todo-${todo.id}'),
                          todo: todo,
                          subtasks: subtasksOf(all, todo.id),
                          now: now,
                          onToggle: () => _toggle(todo),
                          onPickDue: (position) => _pickDue(todo, position),
                          expanded: _expanded == todo.id,
                          onExpand: (value) => setState(
                            () => _expanded = value ? todo.id : null,
                          ),
                          onToggleSub: (sub) => ref
                              .read(todoListProvider.notifier)
                              .setDone(sub.id, !sub.done),
                          onRenameSub: (sub, title) => ref
                              .read(todoListProvider.notifier)
                              .rename(sub.id, title),
                          onDeleteSub: (sub) => ref
                              .read(todoListProvider.notifier)
                              .delete(sub.id),
                          onAddSub: (title) => ref
                              .read(todoListProvider.notifier)
                              .addSubtask(todo.id, title),
                          onOpen: () => ref
                              .read(stickerModeProvider.notifier)
                              .exit(openTodo: todo.id),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _BarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    icon: Icon(icon, size: 16, color: color),
    tooltip: tooltip,
    visualDensity: VisualDensity.compact,
    splashRadius: 16,
    onPressed: onTap,
  );
}

/// 기한 버튼: 기한이 있으면 "내일" 같은 글자(기한 색), 없으면 달력 아이콘.
/// 누르면 누른 위치에 기한 메뉴를 띄움
class _DueButton extends StatelessWidget {
  final DateTime? due;
  final DateTime now;
  final void Function(Offset position) onTap;
  const _DueButton({
    super.key,
    required this.due,
    required this.now,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final due = this.due;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Tooltip(
      message: due == null ? '기한' : '기한 바꾸기',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTapUp: (d) => onTap(d.globalPosition),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: due == null
              ? Icon(Icons.event_outlined, size: 15, color: muted)
              : Text(
                  dueLabel(due, now),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: todoBucketColor(context, todoBucketOf(due, now)),
                  ),
                ),
        ),
      ),
    );
  }
}

/// 할 일 한 줄: 체크 상자 · 제목(하위 할 일 진행) · 기한.
/// 한 번 누르면 펼쳐서 하위 할 일 보기·추가, 두 번 누르면 원래 창에서 엶,
/// 오른쪽 클릭이나 기한을 누르면 기한 메뉴
class _StickerRow extends StatefulWidget {
  final TodoItem todo;
  final List<TodoItem> subtasks;
  final DateTime now;
  final bool expanded;
  final VoidCallback onToggle;
  final void Function(Offset position) onPickDue;
  final VoidCallback onOpen;
  final ValueChanged<bool> onExpand;
  final ValueChanged<TodoItem> onToggleSub;
  final void Function(TodoItem sub, String title) onRenameSub;
  final ValueChanged<TodoItem> onDeleteSub;
  final ValueChanged<String> onAddSub;
  const _StickerRow({
    super.key,
    required this.todo,
    required this.subtasks,
    required this.now,
    required this.expanded,
    required this.onToggle,
    required this.onPickDue,
    required this.onOpen,
    required this.onExpand,
    required this.onToggleSub,
    required this.onRenameSub,
    required this.onDeleteSub,
    required this.onAddSub,
  });

  @override
  State<_StickerRow> createState() => _StickerRowState();
}

class _StickerRowState extends State<_StickerRow> {
  bool _hover = false;

  /// 방금 한 번 눌렀음 (이 사이에 또 누르면 두 번 누르기)
  Timer? _tapWindow;

  @override
  void dispose() {
    _tapWindow?.cancel();
    super.dispose();
  }

  /// 한 번 누르면 바로 펼치고(두 번 누르기를 기다리지 않음),
  /// 곧이어 한 번 더 누르면 원래 창에서 엶
  void _handleTap() {
    if (_tapWindow?.isActive ?? false) {
      _tapWindow!.cancel();
      widget.onOpen();
      return;
    }
    _tapWindow = Timer(kDoubleTapTimeout, () {});
    if (widget.todo.done) return;
    widget.onExpand(!widget.expanded);
  }

  @override
  Widget build(BuildContext context) {
    final todo = widget.todo;
    final subtasks = widget.subtasks;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final due = todo.dueDate;
    final subDone = subtasks.where((s) => s.done).length;
    final expanded = widget.expanded && !todo.done;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: expanded
              ? scheme.onSurface.withValues(alpha: 0.05)
              : _hover
              ? scheme.onSurface.withValues(alpha: 0.03)
              : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onSecondaryTapUp: todo.done
                  ? null
                  : (d) => widget.onPickDue(d.globalPosition),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CheckBox(
                    key: ValueKey('sticker-check-${todo.id}'),
                    done: todo.done,
                    onTap: widget.onToggle,
                  ),
                  // 누를 때 물결 효과 없이 바로 펼침
                  Expanded(
                    child: GestureDetector(
                      key: ValueKey('sticker-title-${todo.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: _handleTap,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              todo.title,
                              maxLines: expanded ? null : 2,
                              overflow: expanded ? null : TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.25,
                                color: todo.done ? muted : null,
                                decoration: todo.done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (subtasks.isNotEmpty && !expanded)
                              Text(
                                '하위 $subDone/${subtasks.length}',
                                style: TextStyle(fontSize: 11, color: muted),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 기한은 늘 보이고, 기한이 없으면 마우스를 올렸거나 펼쳤을 때만 달력 아이콘
                  if (!todo.done && (due != null || _hover || expanded))
                    _DueButton(
                      key: ValueKey('sticker-due-${todo.id}'),
                      due: due,
                      now: widget.now,
                      onTap: widget.onPickDue,
                    )
                  else if (todo.done && due != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Text(
                        dueLabel(due, widget.now),
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ),
                ],
              ),
            ),
            if (expanded)
              _SubtaskPanel(
                key: ValueKey('sticker-subs-${todo.id}'),
                subtasks: subtasks,
                onToggle: widget.onToggleSub,
                onRename: widget.onRenameSub,
                onDelete: widget.onDeleteSub,
                onAdd: widget.onAddSub,
                onClose: () => widget.onExpand(false),
              ),
          ],
        ),
      ),
    );
  }
}

/// 체크 상자 (물결 효과 없음)
class _CheckBox extends StatelessWidget {
  final bool done;
  final VoidCallback onTap;
  final double size;
  const _CheckBox({
    super.key,
    required this.done,
    required this.onTap,
    this.size = 15,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: done ? context.accent : null,
            borderRadius: BorderRadius.circular(4),
            border: done
                ? null
                : Border.all(color: scheme.onSurfaceVariant, width: 1.4),
          ),
          child: done
              ? Icon(Icons.check, size: size - 4, color: scheme.onPrimary)
              : null,
        ),
      ),
    );
  }
}

/// 펼친 할 일 아래: 하위 할 일 목록과 추가 칸.
/// Enter로 추가(칸은 그대로 남아 이어서 입력), 빈 칸에서 Enter나 Esc로 접기
class _SubtaskPanel extends StatefulWidget {
  final List<TodoItem> subtasks;
  final ValueChanged<TodoItem> onToggle;
  final void Function(TodoItem sub, String title) onRename;
  final ValueChanged<TodoItem> onDelete;
  final ValueChanged<String> onAdd;
  final VoidCallback onClose;
  const _SubtaskPanel({
    super.key,
    required this.subtasks,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
    required this.onAdd,
    required this.onClose,
  });

  @override
  State<_SubtaskPanel> createState() => _SubtaskPanelState();
}

class _SubtaskPanelState extends State<_SubtaskPanel> {
  final _text = TextEditingController();
  final _focus = FocusNode(debugLabel: 'sticker-sub-add');

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _text.text.trim();
    if (text.isEmpty) {
      widget.onClose();
      return;
    }
    _text.clear();
    _focus.requestFocus();
    widget.onAdd(text);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final sub in widget.subtasks)
            _StickerSubRow(
              key: ValueKey('sticker-sub-${sub.id}'),
              sub: sub,
              onToggle: () => widget.onToggle(sub),
              onRename: (title) => widget.onRename(sub, title),
              onDelete: () => widget.onDelete(sub),
            ),
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): widget.onClose,
            },
            child: TextField(
              key: const ValueKey('sticker-sub-add'),
              controller: _text,
              focusNode: _focus,
              autofocus: true,
              style: const TextStyle(fontSize: 12),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: '하위 할 일 추가',
                hintStyle: TextStyle(fontSize: 12, color: muted),
                prefixIcon: Icon(
                  Icons.subdirectory_arrow_right,
                  size: 14,
                  color: muted,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 27),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 펼친 할 일 아래 하위 할 일 한 줄: 체크 · 제목(누르면 이름 바꾸기) · 삭제(마우스를 올렸을 때)
class _StickerSubRow extends StatefulWidget {
  final TodoItem sub;
  final VoidCallback onToggle;
  final ValueChanged<String> onRename;
  final VoidCallback onDelete;
  const _StickerSubRow({
    super.key,
    required this.sub,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_StickerSubRow> createState() => _StickerSubRowState();
}

class _StickerSubRowState extends State<_StickerSubRow> {
  bool _hover = false;
  bool _editing = false;
  final _edit = TextEditingController();
  final _focus = FocusNode(debugLabel: 'sticker-sub-rename');

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _finish(save: true);
    });
  }

  @override
  void dispose() {
    _edit.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    _edit.text = widget.sub.title;
    _edit.selection = TextSelection.collapsed(offset: widget.sub.title.length);
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _finish({required bool save}) {
    if (!_editing) return;
    setState(() => _editing = false);
    final text = _edit.text.trim();
    if (save && text.isNotEmpty && text != widget.sub.title) {
      widget.onRename(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.sub;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final style = TextStyle(
      fontSize: 12,
      height: 1.25,
      color: sub.done ? muted : null,
      decoration: sub.done && !_editing ? TextDecoration.lineThrough : null,
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CheckBox(
            key: ValueKey('sticker-subcheck-${sub.id}'),
            done: sub.done,
            size: 13,
            onTap: widget.onToggle,
          ),
          Expanded(
            child: _editing
                ? CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.escape): () =>
                          _finish(save: false),
                    },
                    child: TextField(
                      key: const ValueKey('sticker-sub-rename'),
                      controller: _edit,
                      focusNode: _focus,
                      style: style,
                      onSubmitted: (_) => _finish(save: true),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                  )
                : GestureDetector(
                    key: ValueKey('sticker-subtitle-${sub.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _start,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(sub.title, style: style),
                    ),
                  ),
          ),
          if (_hover && !_editing)
            GestureDetector(
              key: ValueKey('sticker-subdelete-${sub.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: widget.onDelete,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 3, 2, 3),
                  child: Icon(Icons.delete_outline, size: 14, color: muted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
