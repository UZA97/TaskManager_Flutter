import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';
import '../providers/tab_provider.dart';

class MemoTabBar extends ConsumerWidget {
  const MemoTabBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabAsync = ref.watch(tabProvider);
    final notes = ref.watch(noteListProvider).value ?? [];

    return tabAsync.when(
      loading: () => const SizedBox(height: 36),
      error: (e, _) => const SizedBox(height: 36),
      data: (tabState) {
        final tabs = tabState.tabNoteIds
            .map(
              (id) => notes.firstWhere(
                (n) => n.id == id,
                orElse: () => Note(
                  id: id,
                  title: '...',
                  content: '',
                  createdAt: '',
                  updatedAt: '',
                ),
              ),
            )
            .toList();

        return Container(
          height: 36,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFDDDDDD))),
          ),
          child: Row(
            children: [
              // 탭 목록 (드래그 가능)
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    // 드래그 가능한 탭 목록
                    ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex--;
                        ref
                            .read(tabProvider.notifier)
                            .reorder(oldIndex, newIndex);
                      },
                      itemCount: tabs.length,
                      itemBuilder: (context, index) {
                        final note = tabs[index];
                        final isActive = tabState.activeNoteId == note.id;
                        return ReorderableDragStartListener(
                          key: ValueKey(note.id),
                          index: index,
                          child: _TabItem(
                            note: note,
                            isActive: isActive,
                            onTap: () {
                              ref
                                  .read(tabProvider.notifier)
                                  .setActive(note.id!);
                              ref
                                  .read(selectedNoteProvider.notifier)
                                  .select(note);
                            },
                            onClose: () {
                              ref.read(tabProvider.notifier).closeTab(note.id!);
                              final newTabState = ref.read(tabProvider).value;
                              if (newTabState?.activeNoteId != null) {
                                final activeNote = notes.firstWhere(
                                  (n) => n.id == newTabState!.activeNoteId,
                                  orElse: () => notes.first,
                                );
                                ref
                                    .read(selectedNoteProvider.notifier)
                                    .select(activeNote);
                              } else {
                                ref
                                    .read(selectedNoteProvider.notifier)
                                    .select(null);
                              }
                            },
                          ),
                        );
                      },
                    ),
                    // + 버튼 탭 바로 옆에
                    _AddTabButton(),
                  ],
                ),
              ),

              // + 버튼
              // _AddTabButton(),

              // ▼ 오버플로우 버튼
              if (tabs.length > 5)
                _OverflowTabButton(tabs: tabs, tabState: tabState),
            ],
          ),
        );
      },
    );
  }
}

// ── 탭 아이템 ─────────────────────────────────────────────
class _TabItem extends StatefulWidget {
  final Note note;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabItem({
    required this.note,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minWidth: 80, maxWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.isActive
                ? Theme.of(context).colorScheme.surface
                : _hovered
                ? const Color(0xFFF5F5F5)
                : const Color(0xFFEEEEEE),
            border: Border(
              bottom: BorderSide(
                color: widget.isActive
                    ? const Color(0xFF4A90E2)
                    : Colors.transparent,
                width: 2,
              ),
              right: const BorderSide(color: Color(0xFFDDDDDD)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.note, size: 12, color: Colors.grey),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  widget.note.title.isEmpty ? '제목 없음' : widget.note.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: widget.isActive
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: widget.isActive ? const Color(0xFF4A90E2) : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              // 닫기 버튼
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _hovered
                          ? const Color(0xFFDDDDDD)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 10,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── + 버튼 ────────────────────────────────────────────────
class _AddTabButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showAddTabDialog(context, ref),
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Color(0xFFDDDDDD))),
          ),
          child: const Icon(Icons.add, size: 16, color: Colors.grey),
        ),
      ),
    );
  }

  void _showAddTabDialog(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (context) => const _AddTabDialog());
  }
}

// ── 탭 추가 다이얼로그 ─────────────────────────────────────
class _AddTabDialog extends ConsumerStatefulWidget {
  const _AddTabDialog();

  @override
  ConsumerState<_AddTabDialog> createState() => _AddTabDialogState();
}

class _AddTabDialogState extends ConsumerState<_AddTabDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(noteListProvider).value ?? [];
    final filtered = notes
        .where(
          (n) =>
              _query.isEmpty ||
              n.title.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 360,
        height: 480,
        child: Column(
          children: [
            // 검색창
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '메모 검색',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),

            // 메모 목록
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        '메모 없음',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final note = filtered[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.note,
                            size: 16,
                            color: Colors.grey,
                          ),
                          title: Text(
                            note.title.isEmpty ? '제목 없음' : note.title,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () {
                            ref.read(tabProvider.notifier).addTab(note.id!);
                            ref
                                .read(selectedNoteProvider.notifier)
                                .select(note);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),

            // 닫기
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 오버플로우 버튼 ───────────────────────────────────────
class _OverflowTabButton extends ConsumerWidget {
  final List<Note> tabs;
  final TabState tabState;

  const _OverflowTabButton({required this.tabs, required this.tabState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showOverflowMenu(context, ref),
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Color(0xFFDDDDDD))),
          ),
          child: const Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  void _showOverflowMenu(BuildContext context, WidgetRef ref) async {
    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    final notes = ref.read(noteListProvider).value ?? [];

    await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + box.size.height,
        offset.dx + box.size.width,
        offset.dy,
      ),
      items: tabs.map((note) {
        final isActive = tabState.activeNoteId == note.id;
        return PopupMenuItem(
          onTap: () {
            ref.read(tabProvider.notifier).setActive(note.id!);
            ref.read(selectedNoteProvider.notifier).select(note);
          },
          child: Row(
            children: [
              Icon(
                Icons.note,
                size: 14,
                color: isActive ? const Color(0xFF4A90E2) : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                note.title.isEmpty ? '제목 없음' : note.title,
                style: TextStyle(
                  fontSize: 13,
                  color: isActive ? const Color(0xFF4A90E2) : null,
                  fontWeight: isActive ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
