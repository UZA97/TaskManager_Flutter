import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/folder.dart';
import '../models/note.dart';
import '../providers/folder_provider.dart';
import '../providers/note_provider.dart';
import '../data/note_repository.dart';
import '../data/folder_repository.dart';
import '../models/tree_drag_data.dart';

class MemoListView extends ConsumerWidget {
  const MemoListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foldersAsync = ref.watch(folderListProvider);
    final notesAsync = ref.watch(noteListProvider);

    return Column(
      children: [
        // 상단 액션 바: 폴더와 메모 생성 버튼을 한눈에 보여줍니다.
        Padding(
          padding: const EdgeInsets.all(8),
          child: _buildActionBar(context, ref),
        ),

        // 검색창: 현재 메모 목록을 빠르게 필터링합니다.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _buildSearchField(ref),
        ),

        const SizedBox(height: 8),

        // 트리 형태의 폴더/메모 구조를 렌더링합니다.
        Expanded(
          child: foldersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
            data: (folders) => notesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
              data: (notes) => _FolderTree(folders: folders, notes: notes),
            ),
          ),
        ),
      ],
    );
  }

  /// 메모 목록 상단의 폴더/메모 생성 버튼을 구성합니다.
  Widget _buildActionBar(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showCreateFolderDialog(context, ref, null),
            icon: const Icon(Icons.create_new_folder, size: 14),
            label: const Text('폴더', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 6),
              side: const BorderSide(color: Color(0xFFDDDDDD)),
              foregroundColor: Colors.grey[700],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => ref.read(noteListProvider.notifier).createNote(),
            icon: const Icon(Icons.note_add, size: 14),
            label: const Text('메모', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 6),
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// 메모 목록 검색 입력창을 구성합니다.
  Widget _buildSearchField(WidgetRef ref) {
    return TextField(
      decoration: InputDecoration(
        hintText: '검색',
        prefixIcon: const Icon(Icons.search, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        isDense: true,
      ),
      onChanged: (value) {
        ref.read(searchQueryProvider.notifier).update(value);
        ref.read(noteListProvider.notifier).refresh();
      },
    );
  }

  /// 새 폴더를 생성하기 위한 다이얼로그를 표시합니다.
  void _showCreateFolderDialog(
    BuildContext context,
    WidgetRef ref,
    int? parentId,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 폴더'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '폴더 이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(folderListProvider.notifier)
                    .createFolder(name: controller.text, parentId: parentId);
                Navigator.pop(context);
              }
            },
            child: const Text('만들기'),
          ),
        ],
      ),
    );
  }
}

// 트리 루트
class _FolderTree extends ConsumerWidget {
  final List<Folder> folders;
  final List<Note> notes;

  const _FolderTree({required this.folders, required this.notes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);

    if (searchQuery.isNotEmpty) {
      return _buildSearchResult(searchQuery);
    }

    final favFolders = folders.where((f) => f.isFavorite).toList()
      ..sort((a, b) => a.favoriteSortOrder.compareTo(b.favoriteSortOrder));
    final favNotes = notes.where((n) => n.isFavorite).toList()
      ..sort((a, b) => a.favoriteSortOrder.compareTo(b.favoriteSortOrder));

    final rootFolders = folders.where((f) => f.parentId == null).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final rootNotes = notes.where((n) => n.folderId == null).toList()
      ..sort((a, b) => (a.sortOrder ?? 0.0).compareTo(b.sortOrder ?? 0.0));

    final favItems = [
      ...favFolders.map((f) => _TreeItem.folder(f)),
      ...favNotes.map((n) => _TreeItem.note(n)),
    ]..sort((a, b) => a.favoriteSortOrder.compareTo(b.favoriteSortOrder));

    final favWidgets = <Widget>[];

    // 즐겨찾기 첫 번째 DropIndicator
    favWidgets.add(
      _FavoriteDropIndicator(
        beforeSortOrder: favItems.isEmpty
            ? 0.0
            : favItems.first.favoriteSortOrder - 1.0,
        afterSortOrder: favItems.isEmpty
            ? 1.0
            : favItems.first.favoriteSortOrder,
      ),
    );

    for (int i = 0; i < favItems.length; i++) {
      final item = favItems[i];
      if (item.isFolder) {
        favWidgets.add(
          _FavoriteItem(
            folder: item.folder!,
            allFolders: folders,
            allNotes: notes,
          ),
        );
      } else {
        favWidgets.add(_FavoriteNoteItem(note: item.note!));
      }

      final after = i < favItems.length - 1
          ? favItems[i + 1].favoriteSortOrder
          : favItems[i].favoriteSortOrder + 1.0;

      favWidgets.add(
        _FavoriteDropIndicator(
          beforeSortOrder: favItems[i].favoriteSortOrder,
          afterSortOrder: after,
        ),
      );
    }

    // 일반 트리
    final allItems = [
      ...rootFolders.map((f) => _TreeItem.folder(f)),
      ...rootNotes.map((n) => _TreeItem.note(n)),
    ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final normalWidgets = <Widget>[];
    normalWidgets.add(
      _DropIndicator(
        parentId: null,
        beforeSortOrder: allItems.isEmpty
            ? 0.0
            : allItems.first.sortOrder - 1.0,
        afterSortOrder: allItems.isEmpty ? 1.0 : allItems.first.sortOrder,
      ),
    );

    for (int i = 0; i < allItems.length; i++) {
      final item = allItems[i];
      if (item.isFolder) {
        normalWidgets.add(
          _FolderNode(
            folder: item.folder!,
            allFolders: folders,
            allNotes: notes,
            depth: 0,
          ),
        );
      } else {
        normalWidgets.add(_NoteNode(note: item.note!, depth: 0));
      }

      final after = i < allItems.length - 1
          ? allItems[i + 1].sortOrder
          : allItems[i].sortOrder + 1.0;

      normalWidgets.add(
        _DropIndicator(
          parentId: null,
          beforeSortOrder: allItems[i].sortOrder,
          afterSortOrder: after,
        ),
      );
    }

    return ListView(
      children: [
        // 즐겨찾기 섹션 (항상 표시)
        const _FavoriteSectionHeader(),
        ...favWidgets,
        const Divider(
          height: 1,
          thickness: 1.5,
          color: Color.fromARGB(255, 180, 180, 180),
        ),
        // 일반 트리
        ...normalWidgets,
      ],
    );
  }

  /// 검색어와 일치하는 메모와 그 조상 폴더를 보여줍니다.
  Widget _buildSearchResult(String searchQuery) {
    // 검색된 메모만
    // 태그 검색 포함 - provider에서 이미 검색된 결과 그대로 사용
    final matchedNotes = notes
        .where(
          (n) =>
              n.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              n.content.toLowerCase().contains(searchQuery.toLowerCase()) ||
              n.tags.any(
                (tag) => tag.toLowerCase().contains(searchQuery.toLowerCase()),
              ), // 추가
        )
        .toList();

    if (matchedNotes.isEmpty) {
      return const Center(
        child: Text('검색 결과 없음', style: TextStyle(color: Colors.grey)),
      );
    }

    // 검색된 메모의 조상 폴더 id 수집
    final ancestorIds = <int>{};
    for (final note in matchedNotes) {
      if (note.folderId == null) continue;
      _collectAncestors(note.folderId!, ancestorIds);
    }

    // 조상 폴더만 필터
    final visibleFolders = folders
        .where((f) => ancestorIds.contains(f.id))
        .toList();

    return ListView(
      children: [
        // 루트 메모 (folderId == null)
        ...matchedNotes
            .where((n) => n.folderId == null)
            .map((n) => _NoteNode(note: n, depth: 0)),

        // 조상 폴더 트리 (루트만)
        ...visibleFolders
            .where((f) => f.parentId == null)
            .map(
              (f) => _FolderNode(
                folder: f,
                allFolders: visibleFolders,
                allNotes: matchedNotes,
                depth: 0,
                forceExpanded: true, // 추가
              ),
            ),
      ],
    );
  }

  void _collectAncestors(int folderId, Set<int> result) {
    final folder = folders.firstWhere(
      (f) => f.id == folderId,
      orElse: () => Folder(id: -1, name: '', createdAt: ''),
    );
    if (folder.id == -1) return;
    result.add(folder.id!);
    if (folder.parentId != null) {
      _collectAncestors(folder.parentId!, result);
    }
  }
}

// 폴더 노드 (재귀)
class _FolderNode extends ConsumerStatefulWidget {
  final Folder folder;
  final List<Folder> allFolders;
  final List<Note> allNotes;
  final int depth;
  final bool forceExpanded; // 추가
  const _FolderNode({
    required this.folder,
    required this.allFolders,
    required this.allNotes,
    required this.depth,
    this.forceExpanded = false,
  });

  @override
  ConsumerState<_FolderNode> createState() => _FolderNodeState();
}

class _FolderNodeState extends ConsumerState<_FolderNode> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.forceExpanded) {
      _isExpanded = true;
    }
  }

  @override
  void didUpdateWidget(_FolderNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.forceExpanded && !_isExpanded) {
      setState(() => _isExpanded = true);
    } else if (!widget.forceExpanded && oldWidget.forceExpanded) {
      setState(() => _isExpanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final childFolders = widget.allFolders
        .where((f) => f.parentId == widget.folder.id)
        .toList();
    final childNotes = widget.allNotes
        .where((n) => n.folderId == widget.folder.id)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 폴더 행
        DragTarget<TreeDragData>(
          onWillAcceptWithDetails: (details) {
            // 자기 자신이나 자손으로는 드롭 불가
            final repo = ref.read(folderRepositoryProvider);
            final allFolders = ref.read(folderListProvider).value ?? [];
            if (!details.data.isFolder) return true; // 메모는 항상 허용
            final descendants = repo.collectDescendantIds(
              allFolders,
              details.data.id,
            );
            return !descendants.contains(widget.folder.id);
          },
          onAcceptWithDetails: (details) => _onDrop(details.data),
          builder: (context, candidateData, rejectedData) {
            final isHovered = candidateData.isNotEmpty;
            return Draggable<TreeDragData>(
              data: TreeDragData(
                isFolder: true,
                id: widget.folder.id!,
                parentId: widget.folder.parentId,
                sortOrder: widget.folder.sortOrder,
              ),
              feedback: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  color: const Color(0xFFE8F0FE),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.folder,
                        size: 14,
                        color: Color(0xFF4A90E2),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.folder.name,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _buildFolderRow(
                  isSelected: false,
                  hasChildren: false,
                  isHovered: false,
                ),
              ),
              child: _buildFolderRow(
                isSelected:
                    ref.watch(selectedFolderProvider)?.id == widget.folder.id,
                hasChildren:
                    widget.allFolders.any(
                      (f) => f.parentId == widget.folder.id,
                    ) ||
                    widget.allNotes.any((n) => n.folderId == widget.folder.id),
                isHovered: isHovered,
              ),
            );
          },
        ),

        // 펼쳐진 상태
        if (_isExpanded) ...[
          // 폴더랑 메모를 sortOrder 기준으로 합쳐서 렌더링
          () {
            final allItems =
                [
                  ...childFolders.map((f) => _TreeItem.folder(f)),
                  ...childNotes.map((n) => _TreeItem.note(n)),
                ]..sort((a, b) {
                  // 핀된 항목 상단
                  if (a.isPinned && !b.isPinned) return -1;
                  if (!a.isPinned && b.isPinned) return 1;
                  return a.sortOrder.compareTo(b.sortOrder);
                });

            final items = <Widget>[];

            items.add(
              _DropIndicator(
                parentId: widget.folder.id,
                beforeSortOrder: allItems.isEmpty
                    ? 0.0
                    : allItems.first.sortOrder - 1.0,
                afterSortOrder: allItems.isEmpty
                    ? 1.0
                    : allItems.first.sortOrder,
              ),
            );

            for (int i = 0; i < allItems.length; i++) {
              final item = allItems[i];
              if (item.isFolder) {
                items.add(
                  _FolderNode(
                    folder: item.folder!,
                    allFolders: widget.allFolders,
                    allNotes: widget.allNotes,
                    depth: widget.depth + 1,
                    forceExpanded: widget.forceExpanded, // 추가
                  ),
                );
              } else {
                items.add(_NoteNode(note: item.note!, depth: widget.depth + 1));
              }

              final after = i < allItems.length - 1
                  ? allItems[i + 1].sortOrder
                  : allItems[i].sortOrder + 1.0;

              items.add(
                _DropIndicator(
                  parentId: widget.folder.id,
                  beforeSortOrder: allItems[i].sortOrder,
                  afterSortOrder: after,
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items,
            );
          }(),
        ],
      ],
    );
  }

  Widget _buildFolderRow({
    required bool isSelected,
    required bool hasChildren,
    required bool isHovered,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() => _isExpanded = !_isExpanded);
        ref.read(selectedFolderProvider.notifier).select(widget.folder);
        ref.read(selectedNoteProvider.notifier).select(null); // 추가
      },
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: Container(
        padding: EdgeInsets.only(
          left: 8.0 + widget.depth * 16.0,
          right: 8,
          top: 4,
          bottom: 4,
        ),
        color: isHovered
            ? const Color(0xFFBBDEFB)
            : isSelected
            ? const Color(0xFFE8F0FE)
            : Colors.transparent,
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: hasChildren
                  ? Icon(
                      _isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                      size: 16,
                      color: Colors.grey,
                    )
                  : const SizedBox(),
            ),
            const SizedBox(width: 4),
            Icon(
              _isExpanded ? Icons.folder_open : Icons.folder,
              size: 14,
              color: const Color(0xFF4A90E2),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.folder.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.folder.isFavorite)
              const Icon(Icons.star, size: 10, color: Colors.amber),
          ],
        ),
      ),
    );
  }

  void _onDrop(TreeDragData data) {
    if (data.isFolder) {
      // 폴더 → 폴더 안으로 이동
      ref
          .read(folderListProvider.notifier)
          .moveFolder(data.id, widget.folder.id);
    } else {
      // 메모 → 폴더 안으로 이동
      ref.read(noteListProvider.notifier).moveNote(data.id, widget.folder.id!);
    }
  }

  void _showContextMenu(BuildContext context, Offset position) async {
    final result = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'favorite',
          child: Row(
            children: [
              Icon(
                widget.folder.isFavorite ? Icons.star : Icons.star_border,
                size: 16,
                color: Colors.amber,
              ),
              const SizedBox(width: 8),
              Text(widget.folder.isFavorite ? '즐겨찾기 해제' : '즐겨찾기'),
            ],
          ),
        ),
        const PopupMenuItem(value: 'new_folder', child: Text('하위 폴더 만들기')),
        const PopupMenuItem(value: 'new_note', child: Text('메모 만들기')),
        const PopupMenuItem(value: 'rename', child: Text('이름 변경')),
        const PopupMenuItem(value: 'delete', child: Text('삭제')),
        // PopupMenuItem(
        //   value: 'pin',
        //   child: Row(
        //     children: [
        //       Icon(
        //         widget.folder.isPinned
        //             ? Icons.push_pin_outlined
        //             : Icons.push_pin,
        //         size: 16,
        //       ),
        //       const SizedBox(width: 8),
        //       Text(widget.folder.isPinned ? '고정 해제' : '상단 고정'),
        //     ],
        //   ),
        // ),
      ],
    );

    if (!context.mounted) return;

    switch (result) {
      case 'favorite':
        ref
            .read(folderListProvider.notifier)
            .toggleFavorite(widget.folder.id!, !widget.folder.isFavorite);
        break;
      case 'new_folder':
        _showCreateFolderDialog(context, widget.folder.id);
        break;
      case 'new_note':
        ref
            .read(noteListProvider.notifier)
            .createNote(folderId: widget.folder.id);
        break;
      case 'rename':
        _showRenameDialog(context);
        break;
      case 'delete':
        _showDeleteDialog(context);
        break;
      case 'pin':
        ref
            .read(folderListProvider.notifier)
            .togglePin(widget.folder.id!, !widget.folder.isPinned);
        break;
    }
  }

  void _showCreateFolderDialog(BuildContext context, int? parentId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 폴더'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '폴더 이름'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(folderListProvider.notifier)
                    .createFolder(name: controller.text, parentId: parentId);
                Navigator.pop(context);
              }
            },
            child: const Text('만들기'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.folder.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이름 변경'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(folderListProvider.notifier)
                    .renameFolder(widget.folder.id!, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('변경'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('폴더 삭제'),
        content: Text('"${widget.folder.name}" 폴더와 하위 항목이 모두 삭제됩니다. 계속할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(folderListProvider.notifier)
                  .deleteFolder(widget.folder.id!);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// 메모 노드
class _NoteNode extends ConsumerWidget {
  final Note note;
  final int depth;

  const _NoteNode({required this.note, required this.depth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedNote = ref.watch(selectedNoteProvider);
    final isSelected = selectedNote?.id == note.id;

    final noteRow = GestureDetector(
      onTap: () {
        ref.read(selectedNoteProvider.notifier).select(note);
        ref.read(selectedFolderProvider.notifier).select(null); // 추가
      },
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, ref, details.globalPosition),
      child: Container(
        padding: EdgeInsets.only(
          left: 8.0 + depth * 16.0 + 20,
          right: 8,
          top: 4,
          bottom: 4,
        ),
        color: isSelected ? const Color(0xFFE8F0FE) : Colors.transparent,
        child: Row(
          children: [
            const Icon(Icons.note, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                note.title.isEmpty ? '제목 없음' : note.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (note.isImportant)
              const Icon(Icons.priority_high, size: 12, color: Colors.orange),
            if (note.isPinned)
              const Icon(Icons.push_pin, size: 12, color: Color(0xFF4A90E2)),
            if (note.isFavorite)
              const Icon(Icons.star, size: 10, color: Colors.amber),
          ],
        ),
      ),
    );

    return Draggable<TreeDragData>(
      data: TreeDragData(
        isFolder: false,
        id: note.id!,
        parentId: note.folderId,
        sortOrder: note.sortOrder ?? 0.0,
      ),
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: const Color(0xFFE8F0FE),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.note, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                note.title.isEmpty ? '제목 없음' : note.title,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: noteRow),
      child: noteRow,
    );
  }

  void _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
  ) async {
    final result = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'favorite',
          child: Row(
            children: [
              Icon(
                note.isFavorite ? Icons.star : Icons.star_border,
                size: 16,
                color: Colors.amber,
              ),
              const SizedBox(width: 8),
              Text(note.isFavorite ? '즐겨찾기 해제' : '즐겨찾기'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'pin',
          child: Row(
            children: [
              Icon(
                note.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(note.isPinned ? '고정 해제' : '상단 고정'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'important',
          child: Row(
            children: [
              Icon(
                note.isImportant ? Icons.priority_high : Icons.outlined_flag,
                size: 16,
                color: note.isImportant ? Colors.orange : null,
              ),
              const SizedBox(width: 8),
              Text(note.isImportant ? '중요 해제' : '중요 표시'),
            ],
          ),
        ),
        const PopupMenuItem(value: 'delete', child: Text('삭제')),
        const PopupMenuItem(value: 'duplicate', child: Text('복제')),
      ],
    );

    if (!context.mounted) return;

    switch (result) {
      case 'favorite':
        ref
            .read(noteListProvider.notifier)
            .toggleFavorite(note.id!, !note.isFavorite);
        break;
      case 'delete':
        ref.read(noteListProvider.notifier).deleteNote(note.id!);
        break;
      case 'duplicate':
        final repo = ref.read(noteRepositoryProvider);
        final newNote = await repo.createNote(folderId: note.folderId);
        await repo.saveNote(
          newNote.copyWith(title: '${note.title} (복사)', content: note.content),
        );
        ref.read(noteListProvider.notifier).refresh();
        break;
      case 'pin':
        ref.read(noteListProvider.notifier).togglePin(note.id!, !note.isPinned);
        break;
      case 'important':
        ref
            .read(noteListProvider.notifier)
            .toggleImportant(note.id!, !note.isImportant);
        break;
    }
  }
}

class _DropIndicator extends ConsumerWidget {
  final int? parentId;
  final double beforeSortOrder;
  final double afterSortOrder;

  const _DropIndicator({
    this.parentId,
    required this.beforeSortOrder,
    required this.afterSortOrder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<TreeDragData>(
      onWillAcceptWithDetails: (details) =>
          !details.data.isFavoriteItem, // 즐겨찾기 아이템 막기
      onAcceptWithDetails: (details) {
        final newSortOrder = (beforeSortOrder + afterSortOrder) / 2;
        if (details.data.isFolder) {
          ref
              .read(folderListProvider.notifier)
              .moveFolderWithOrder(details.data.id, parentId, newSortOrder);
        } else {
          ref
              .read(noteListProvider.notifier)
              .moveNoteWithOrder(details.data.id, parentId, newSortOrder);
        }
      },
      builder: (context, candidateData, _) {
        final isHovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: isHovered ? 3 : 2,
          margin: const EdgeInsets.symmetric(vertical: 1),
          color: isHovered ? const Color(0xFF4A90E2) : Colors.transparent,
        );
      },
    );
  }
}

class _FavoriteDropIndicator extends ConsumerWidget {
  final double beforeSortOrder;
  final double afterSortOrder;

  const _FavoriteDropIndicator({
    required this.beforeSortOrder,
    required this.afterSortOrder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<TreeDragData>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final newSortOrder = (beforeSortOrder + afterSortOrder) / 2;
        if (details.data.isFavoriteItem) {
          // 즐겨찾기 내 순서 변경
          if (details.data.isFolder) {
            ref
                .read(folderListProvider.notifier)
                .updateFolderFavoriteSortOrder(details.data.id, newSortOrder);
          } else {
            ref
                .read(noteListProvider.notifier)
                .updateFavoriteSortOrder(details.data.id, newSortOrder);
          }
        } else {
          // 일반 아이템 → 즐겨찾기 등록
          if (details.data.isFolder) {
            ref
                .read(folderListProvider.notifier)
                .toggleFavorite(details.data.id, true);
          } else {
            ref
                .read(noteListProvider.notifier)
                .toggleFavorite(details.data.id, true);
          }
        }
      },
      builder: (context, candidateData, _) {
        final isHovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: isHovered ? 3 : 2,
          margin: const EdgeInsets.symmetric(vertical: 1),
          color: isHovered ? Colors.amber : Colors.transparent,
        );
      },
    );
  }
}

class _TreeItem {
  final bool isFolder;
  final Folder? folder;
  final Note? note;
  final double sortOrder;
  final bool isPinned;
  final bool isFavorite;
  final double favoriteSortOrder;

  _TreeItem.folder(Folder f)
    : isFolder = true,
      folder = f,
      note = null,
      sortOrder = f.sortOrder,
      isPinned = f.isPinned,
      isFavorite = f.isFavorite,
      favoriteSortOrder = f.favoriteSortOrder;

  _TreeItem.note(Note n)
    : isFolder = false,
      folder = null,
      note = n,
      sortOrder = n.sortOrder ?? 0.0,
      isPinned = n.isPinned,
      isFavorite = n.isFavorite,
      favoriteSortOrder = n.favoriteSortOrder;
}

class _FavoriteSectionHeader extends ConsumerWidget {
  const _FavoriteSectionHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<TreeDragData>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        if (!details.data.isFavoriteItem) {
          if (details.data.isFolder) {
            ref
                .read(folderListProvider.notifier)
                .toggleFavorite(details.data.id, true);
          } else {
            ref
                .read(noteListProvider.notifier)
                .toggleFavorite(details.data.id, true);
          }
        }
      },
      builder: (context, candidateData, _) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
          height: 32,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          color: isHovered
              ? Colors.amber.withValues(alpha: 0.1)
              : Colors.transparent,
          child: Row(
            children: [
              const Icon(Icons.star, size: 14, color: Colors.amber),
              const SizedBox(width: 6),
              Text(
                '즐겨찾기',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isHovered
                      ? Colors.amber
                      : const Color.fromARGB(255, 0, 0, 0),
                  letterSpacing: 0.8,
                ),
              ),
              if (isHovered) ...[
                const Spacer(),
                const Icon(Icons.add, size: 12, color: Colors.amber),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _FavoriteItem extends ConsumerWidget {
  final Folder folder;
  final List<Folder> allFolders;
  final List<Note> allNotes;

  const _FavoriteItem({
    required this.folder,
    required this.allFolders,
    required this.allNotes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = GestureDetector(
      onTap: () => ref.read(selectedFolderProvider.notifier).select(folder),
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, ref, details.globalPosition),
      child: Container(
        padding: const EdgeInsets.fromLTRB(30, 4, 8, 4),
        child: Row(
          children: [
            const Icon(Icons.folder, size: 14, color: Color(0xFF4A90E2)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                folder.name,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // const Icon(Icons.star, size: 10, color: Colors.amber),
          ],
        ),
      ),
    );

    return Draggable<TreeDragData>(
      data: TreeDragData(
        isFolder: true,
        id: folder.id!,
        parentId: folder.parentId,
        sortOrder: folder.favoriteSortOrder,
        isFavoriteItem: true,
      ),
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: const Color(0xFFE8F0FE),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder, size: 14, color: Color(0xFF4A90E2)),
              const SizedBox(width: 6),
              Text(folder.name, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: child),
      child: child,
    );
  }

  void _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
  ) async {
    final result = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [PopupMenuItem(value: 'unfavorite', child: Text('즐겨찾기 해제'))],
    );
    if (result == 'unfavorite') {
      ref.read(folderListProvider.notifier).toggleFavorite(folder.id!, false);
    }
  }
}

class _FavoriteNoteItem extends ConsumerWidget {
  final Note note;

  const _FavoriteNoteItem({required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = GestureDetector(
      onTap: () => ref.read(selectedNoteProvider.notifier).select(note),
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, ref, details.globalPosition),
      child: Container(
        padding: const EdgeInsets.fromLTRB(30, 4, 8, 4),
        child: Row(
          children: [
            const Icon(Icons.note, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                note.title.isEmpty ? '제목 없음' : note.title,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // const Icon(Icons.star, size: 10, color: Colors.amber),
          ],
        ),
      ),
    );

    return Draggable<TreeDragData>(
      data: TreeDragData(
        isFolder: false,
        id: note.id!,
        parentId: note.folderId,
        sortOrder: note.favoriteSortOrder,
        isFavoriteItem: true,
      ),
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: const Color(0xFFE8F0FE),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.note, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                note.title.isEmpty ? '제목 없음' : note.title,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: child),
      child: child,
    );
  }

  void _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
  ) async {
    final result = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [PopupMenuItem(value: 'unfavorite', child: Text('즐겨찾기 해제'))],
    );
    if (result == 'unfavorite') {
      ref.read(noteListProvider.notifier).toggleFavorite(note.id!, false);
    }
  }
}
