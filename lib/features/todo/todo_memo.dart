import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/navigation_provider.dart';
import '../../core/theme/app_colors.dart';
import '../memo/data/note_repository.dart';
import '../memo/editor_v2/editor_block.dart';
import '../memo/editor_v2/inline_image.dart';
import '../memo/models/note.dart';
import '../memo/providers/note_provider.dart';
import 'todo_provider.dart';

/// 메모 화면 번호 (navigationProvider 값)
const _memoTabIndex = 0;

/// 메모에 넣을 체크리스트 한 줄 ([depth]는 넣는 위치 기준 추가 들여쓰기)
typedef MemoTodoLine = ({String text, bool checked, int depth});

/// 할 일을 메모의 목차 아래에 체크리스트로 넣어 달라는 요청 (메모 에디터가 열리면 처리).
/// [anchor]는 목차(제목·섹션) 줄 번호, null이면 메모 맨 끝.
/// 그 사이 메모가 바뀌었을 수 있어 [anchorText]로 다시 확인함.
typedef MemoTodoRequest = ({
  int noteId,
  int? anchor,
  String anchorText,
  List<MemoTodoLine> lines,
});

class MemoTodoRequestNotifier extends Notifier<MemoTodoRequest?> {
  @override
  MemoTodoRequest? build() => null;

  void request(MemoTodoRequest? value) => state = value;
}

final memoTodoRequestProvider =
    NotifierProvider<MemoTodoRequestNotifier, MemoTodoRequest?>(
      MemoTodoRequestNotifier.new,
    );

/// 할 일과 하위 할 일 → 체크리스트 줄들
List<MemoTodoLine> memoTodoLines(TodoItem todo, List<TodoItem> subtasks) => [
  (text: todo.title, checked: todo.done, depth: 0),
  for (final sub in subtasks) (text: sub.title, checked: sub.done, depth: 1),
];

// ───────────── 목차와 넣을 위치

/// 목차 한 항목 (제목 H1~H3 또는 접는 섹션)
typedef MemoOutlineEntry = ({
  int index,
  String text,
  int level,
  bool isSection,
});

bool isOutlineBlock(EditorBlock block) =>
    (block.type == 'heading' || block.isSection) &&
    outlineTextOf(block).isNotEmpty;

String outlineTextOf(EditorBlock block) =>
    stripInlineImages(block.controller.text).trim();

/// 메모 목차 (에디터의 목차 패널과 같은 항목)
List<MemoOutlineEntry> memoOutlineOf(List<EditorBlock> blocks) => [
  for (var i = 0; i < blocks.length; i++)
    if (isOutlineBlock(blocks[i]))
      (
        index: i,
        text: outlineTextOf(blocks[i]),
        level: blocks[i].isSection ? 3 : blocks[i].level.clamp(1, 3),
        isSection: blocks[i].isSection,
      ),
];

bool _isBlankLine(EditorBlock block) =>
    block.raw == null &&
    block.type == 'paragraph' &&
    block.controller.text.trim().isEmpty;

/// 체크리스트를 넣을 위치: [anchor] 목차의 내용 맨 아래 (다음 같은·상위 제목 전,
/// 끝의 빈 줄 앞). [anchor]가 null이면 메모 맨 끝.
({int index, int depth}) todoInsertPoint(
  List<EditorBlock> blocks,
  int? anchor,
) {
  if (anchor == null) {
    var last = blocks.length - 1;
    while (last >= 0 && _isBlankLine(blocks[last])) {
      last--;
    }
    return (index: last + 1, depth: 0);
  }
  final head = blocks[anchor];
  final headLevel = head.isSection ? 3 : head.level;
  var end = anchor;
  for (var i = anchor + 1; i < blocks.length; i++) {
    final block = blocks[i];
    if (head.isSection) {
      // 섹션 내용은 더 들여쓴 줄들
      if (block.depth <= head.depth) break;
    } else {
      if (block.depth < head.depth) break;
      if (block.depth == head.depth) {
        if (block.type == 'heading' && block.level <= headLevel) break;
        if (block.isSection && headLevel >= 3) break;
      }
    }
    if (!_isBlankLine(block)) end = i;
  }
  return (index: end + 1, depth: head.isSection ? head.depth + 1 : head.depth);
}

/// 체크리스트 줄 → 에디터 블록
List<EditorBlock> memoTodoBlocks(List<MemoTodoLine> lines, int baseDepth) => [
  for (final line in lines)
    EditorBlock(
      type: 'todo_list',
      depth: baseDepth + line.depth,
      data: {'checked': line.checked},
      delta: [
        {'insert': line.text},
      ],
    ),
];

// ───────────── 메모·목차 고르기

typedef _Target = ({Note note, MemoOutlineEntry? entry});

/// 메모와 목차를 골라 그 아래에 할 일을 체크리스트로 넣음 (메모 화면으로 이동)
Future<void> addTodoToMemo(
  BuildContext context,
  WidgetRef ref,
  TodoItem todo,
  List<TodoItem> subtasks,
) async {
  final target = await showDialog<_Target>(
    context: context,
    builder: (context) => const _MemoTargetDialog(),
  );
  if (target == null || target.note.id == null) return;
  final noteId = target.note.id!;
  ref.read(memoTodoRequestProvider.notifier).request((
    noteId: noteId,
    anchor: target.entry?.index,
    anchorText: target.entry?.text ?? '',
    lines: memoTodoLines(todo, subtasks),
  ));
  // 넣은 메모를 할 일에 연결해 둠 (할 일에서 바로 열 수 있게)
  await ref.read(todoListProvider.notifier).setNote(todo.id, noteId);
  await openTodoMemo(ref, noteId);
}

/// 할 일에 연결할 메모 고르기 (목차 단계 없음)
Future<Note?> pickMemo(BuildContext context) async {
  final target = await showDialog<_Target>(
    context: context,
    builder: (context) => const _MemoTargetDialog(noteOnly: true),
  );
  return target?.note.id == null ? null : target!.note;
}

/// 메모 화면으로 가서 그 메모를 엶
Future<void> openTodoMemo(WidgetRef ref, int noteId) async {
  await ref.read(noteListProvider.notifier).selectById(noteId);
  ref.read(navigationProvider.notifier).navigateTo(_memoTabIndex);
}

/// 메모 id → 제목 (할 일의 연결된 메모 표시용). 메모가 바뀌면 다시 읽음.
final todoNoteTitlesProvider = FutureProvider<Map<int, String>>((ref) async {
  ref.watch(noteListProvider);
  // 제목만 읽음 (자동 저장마다 다시 읽으므로 본문까지 읽지 않게)
  final titles = await ref.read(noteRepositoryProvider).getNoteTitles();
  return {
    for (final e in titles.entries)
      e.key: e.value.trim().isEmpty ? '제목 없음' : e.value,
  };
});

class _MemoTargetDialog extends ConsumerStatefulWidget {
  /// true면 메모만 고르고 닫음
  final bool noteOnly;
  const _MemoTargetDialog({this.noteOnly = false});

  @override
  ConsumerState<_MemoTargetDialog> createState() => _MemoTargetDialogState();
}

class _MemoTargetDialogState extends ConsumerState<_MemoTargetDialog> {
  final _search = TextEditingController();
  List<Note>? _notes;
  Note? _note; // 고른 메모 (목차 고르는 단계)
  List<MemoOutlineEntry> _outline = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await ref.read(noteRepositoryProvider).getAllNotes();
    // 지금 연 메모를 맨 위에, 나머지는 최근 수정 순
    final selectedId = ref.read(selectedNoteProvider)?.id;
    notes.sort((a, b) {
      if (a.id == selectedId) return -1;
      if (b.id == selectedId) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    if (mounted) setState(() => _notes = notes);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pickNote(Note note) {
    if (widget.noteOnly) {
      Navigator.pop(context, (note: note, entry: null));
      return;
    }
    List<MemoOutlineEntry> outline = const [];
    try {
      if (note.content.isNotEmpty) {
        final blocks = blocksFromJson(note.content);
        outline = memoOutlineOf(blocks);
        for (final block in blocks) {
          block.dispose();
        }
      }
    } catch (_) {
      // 예전(마크다운) 메모는 목차 없이 맨 끝에만
    }
    setState(() {
      _note = note;
      _outline = outline;
    });
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: note == null
            ? _buildNotes(context)
            : _buildOutline(context, note),
      ),
    );
  }

  Widget _header(BuildContext context, String title, {VoidCallback? onBack}) =>
      Padding(
        padding: EdgeInsets.fromLTRB(onBack == null ? 20 : 8, 14, 8, 6),
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 18),
                onPressed: onBack,
              ),
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );

  Widget _buildNotes(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final query = _search.text.trim().toLowerCase();
    final notes = _notes;
    final shown = notes == null
        ? const <Note>[]
        : [
            for (final n in notes)
              if (query.isEmpty || n.title.toLowerCase().contains(query)) n,
          ];
    final selectedId = ref.read(selectedNoteProvider)?.id;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, widget.noteOnly ? '어느 메모와 연결할까요?' : '어느 메모에 넣을까요?'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _search,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (shown.isNotEmpty) _pickNote(shown.first);
            },
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: '메모 제목 검색',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        Flexible(
          child: notes == null
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : shown.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '메모가 없습니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final n = shown[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.description_outlined,
                        size: 18,
                        color: n.id == selectedId ? context.accent : muted,
                      ),
                      title: Text(
                        n.title.trim().isEmpty ? '제목 없음' : n.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: n.id == selectedId
                          ? Text(
                              '열린 메모',
                              style: TextStyle(fontSize: 11, color: muted),
                            )
                          : null,
                      onTap: () => _pickNote(n),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOutline(BuildContext context, Note note) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final title = note.title.trim().isEmpty ? '제목 없음' : note.title;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, title, onBack: () => setState(() => _note = null)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            _outline.isEmpty
                ? '목차가 없는 메모라 맨 끝에 넣습니다'
                : '고른 목차의 맨 아래에 체크리스트로 넣습니다',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              for (final entry in _outline)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.only(
                    left: 16 + (entry.level - 1) * 16.0,
                    right: 16,
                  ),
                  leading: Icon(
                    entry.isSection ? Icons.unfold_less : Icons.title,
                    size: 16,
                    color: muted,
                  ),
                  title: Text(
                    entry.text,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: entry.level == 1 ? FontWeight.w600 : null,
                    ),
                  ),
                  onTap: () =>
                      Navigator.pop(context, (note: note, entry: entry)),
                ),
              if (_outline.isNotEmpty) const Divider(height: 8),
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.vertical_align_bottom,
                  size: 16,
                  color: context.accent,
                ),
                title: const Text('메모 맨 끝에', style: TextStyle(fontSize: 14)),
                onTap: () => Navigator.pop(context, (note: note, entry: null)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
