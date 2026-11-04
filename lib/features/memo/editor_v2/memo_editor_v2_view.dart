import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../core/providers/navigation_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../map/services/location_search_result.dart';
import '../../map/widgets/location_search_dialog.dart';
import '../data/note_repository.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';
import '../providers/tab_provider.dart';
import '../services/note_import_export_service.dart';
import '../services/note_template_service.dart';
import '../services/note_version_service.dart';
import '../services/pdf_export_service.dart';
import '../views/memo_editor_widgets.dart';
import '../widgets/ask_ai_dialog.dart';
import '../widgets/memo_tab_bar.dart';
import '../widgets/note_version_dialog.dart';
import 'block_editor.dart';
import 'block_editor_controller.dart';
import 'editor_block.dart';
import 'inline_image.dart';
import 'find_bar.dart';
import 'outline_panel.dart';

/// 새 에디터를 쓰는 메모 화면. 화면 구성(탭·제목·토글·태그·하단 툴바)은 기존과 같음.
class MemoEditorV2View extends ConsumerStatefulWidget {
  const MemoEditorV2View({super.key});

  @override
  ConsumerState<MemoEditorV2View> createState() => _MemoEditorV2ViewState();
}

enum _SaveStatus { idle, saving, saved }

class _MemoEditorV2ViewState extends ConsumerState<MemoEditorV2View> {
  BlockEditorController? _editor;
  Note? _currentNote;
  final _titleController = TextEditingController();
  bool _isDragging = false;
  bool _isToolbarExpanded = true;
  // 저장 표시는 화면 전체 setState 대신 이 notifier로만 갱신
  final _saveStatus = ValueNotifier<_SaveStatus>(_SaveStatus.idle);
  Timer? _saveTimer;

  // 찾기/바꾸기
  bool _findOpen = false;
  bool _replaceMode = false;

  /// 오른쪽 목차(제목 목록)
  bool _outlineOpen = false;

  /// `[[` 메모 링크용 전체 메모 (검색 중일 때만 따로 불러 둠, 링크 메뉴를 열 때 불러옴)
  List<Note>? _allNotesCache;
  bool _allNotesStale = true;

  /// 지금 에디터·제목 칸이 담고 있는 메모 (전환 중엔 _currentNote와 다를 수 있음)
  Note? _editorNote;

  /// 저장 대기 중인 메모와 에디터 (타이머를 만들 때 고정해 다른 메모에 쓰지 않게)
  Note? _pendingNote;
  BlockEditorController? _pendingEditor;

  /// 화면이 닫힌 뒤에도 마지막 저장을 할 수 있게 미리 잡아 둠
  late NoteListNotifier _noteList;

  static const _imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];

  bool _isImage(String filePath) =>
      _imageExts.contains(path.extension(filePath).toLowerCase());

  @override
  void initState() {
    super.initState();
    _noteList = ref.read(noteListProvider.notifier);
  }

  @override
  void dispose() {
    // 닫히기 전 마지막 입력 저장 (에디터를 정리하기 전에 내용을 꺼냄)
    _flushSave();
    _editor?.dispose();
    _titleController.dispose();
    _saveStatus.dispose();
    super.dispose();
  }

  /// 메모 내용(appflowy 문서 JSON)으로 에디터를 만듦.
  /// JSON이 아닌 예전(마크다운) 메모는 한 줄씩 문단으로 엶.
  void _initEditor(Note note) {
    _titleController.text = note.title;

    List<EditorBlock> blocks;
    try {
      blocks = note.content.isEmpty ? [] : blocksFromJson(note.content);
    } catch (_) {
      blocks = [
        for (final line in note.content.split('\n'))
          EditorBlock(
            type: 'paragraph',
            delta: [
              if (line.isNotEmpty) {'insert': line},
            ],
          ),
      ];
    }

    final old = _editor;
    final editor = BlockEditorController(blocks);
    editor.onContentChanged = () => _onContentChanged(editor);
    setState(() {
      _editor = editor;
      _editorNote = note;
      _findOpen = false;
    });
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    // 에디터가 그려진 뒤 대기 중인 체크리스트 이동 요청 처리
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyFocusRequest());
    // 열 때의 내용을 버전으로 (편집 전 상태로 되돌릴 수 있게)
    if (note.id != null) {
      NoteVersionService.snapshot(note.id!, note.title, note.content);
    }
  }

  /// `[[` 후보 메모. 검색 중이 아니면 이미 불러온 목록을 그대로 씀
  List<Note> get _allNotes {
    final listed = ref.read(noteListProvider).value ?? const <Note>[];
    if (ref.read(searchQueryProvider).isEmpty) return listed;
    if (_allNotesStale) {
      _allNotesStale = false;
      _loadAllNotes();
    }
    return _allNotesCache ?? listed;
  }

  Future<void> _loadAllNotes() async {
    final notes = await ref.read(noteRepositoryProvider).getAllNotes();
    if (mounted) _allNotesCache = notes;
  }

  /// 에디터 변경 내용을 일정 시간 동안 모아서 저장합니다.
  /// [editor]가 지금 에디터가 아니면(메모 전환 중) 무시.
  void _onContentChanged([BlockEditorController? editor]) {
    final current = _editor;
    final note = _editorNote;
    if (note?.id == null || current == null) return;
    if (editor != null && editor != current) return;

    _saveTimer?.cancel();
    _pendingNote = note;
    _pendingEditor = current;
    _saveStatus.value = _SaveStatus.saving;
    _saveTimer = Timer(const Duration(milliseconds: 500), _flushSave);
  }

  /// 대기 중인 저장을 바로 실행 (메모 전환·화면 닫힘 전에 마지막 입력을 남김).
  /// 내용은 await 전에 동기로 꺼내므로 바로 뒤에 에디터를 정리해도 됨.
  Future<void> _flushSave() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final note = _pendingNote;
    final editor = _pendingEditor;
    _pendingNote = null;
    _pendingEditor = null;
    if (note?.id == null || editor == null) return;
    // 즐겨찾기 등은 최신 값을 쓰고 제목·본문만 바꿈
    final base = _editorNote?.id == note!.id ? _editorNote! : note;
    final updated = base.copyWith(
      // 제목 칸은 지금 에디터의 메모 것
      title: editor == _editor ? _titleController.text : null,
      content: editor.toJsonString(),
    );
    await _noteList.saveNote(updated);
    NoteVersionService.snapshot(updated.id!, updated.title, updated.content);
    // 그사이 새 입력이 저장을 기다리면 표시는 그쪽에 맡김
    if (!mounted || _saveTimer != null) return;
    _saveStatus.value = _SaveStatus.saved;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _saveStatus.value == _SaveStatus.saved) {
        _saveStatus.value = _SaveStatus.idle;
      }
    });
  }

  /// 대기 중인 저장을 버림 (내용을 통째로 바꿀 때)
  void _cancelPendingSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _pendingNote = null;
    _pendingEditor = null;
    if (_saveStatus.value == _SaveStatus.saving) {
      _saveStatus.value = _SaveStatus.idle;
    }
  }

  /// 오늘 브리핑에서 고른 체크리스트로 이동하고 그 줄 끝에 커서를 둡니다.
  void _applyFocusRequest() {
    final request = ref.read(memoFocusRequestProvider);
    final editor = _editor;
    if (!mounted ||
        request == null ||
        editor == null ||
        request.noteId != _currentNote?.id) {
      return;
    }
    ref.read(memoFocusRequestProvider.notifier).request(null);

    bool isTodo(EditorBlock b) =>
        b.type == 'todo_list' &&
        !b.checked &&
        b.controller.text.trim() == request.text;
    final blocks = editor.blocks;
    var index = -1;
    for (var i = 0; i < blocks.length; i++) {
      if (!isTodo(blocks[i])) continue;
      if (index < 0) index = i; // 위치가 바뀌었으면 같은 내용의 첫 항목
      if (_samePath(editor.pathOf(i), request.path)) {
        index = i;
        break;
      }
    }
    if (index < 0) return;

    // 접힌 섹션 안에 있으면 펼침
    var depth = blocks[index].depth;
    for (var i = index - 1; i >= 0 && depth > 0; i--) {
      if (blocks[i].depth >= depth) continue;
      if (blocks[i].isSection) blocks[i].data['collapsed'] = false;
      depth = blocks[i].depth;
    }
    setState(() {});

    final block = blocks[index];
    // 브리핑 팝업이 닫히며 포커스가 되돌아간 뒤에 커서를 둬야 입력 포커스가 유지됨
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || _editor != editor) return;
      editor.focus(block, block.controller.text.length);
    });
  }

  static bool _samePath(List<int> a, List<int> b) =>
      a.length == b.length &&
      Iterable.generate(a.length).every((i) => a[i] == b[i]);

  // ───────────── 첨부

  /// 첨부 파일을 앱 지원 디렉토리로 복사합니다.
  Future<String> _copyToAppDir(String srcPath) async {
    final appDir = await getApplicationSupportDirectory();
    final attachDir = Directory(
      path.join(appDir.path, 'Attachments', _currentNote!.id.toString()),
    );
    await attachDir.create(recursive: true);

    final fileName = path.basename(srcPath);
    var destPath = path.join(attachDir.path, fileName);
    if (File(destPath).existsSync()) {
      final ext = path.extension(fileName);
      final name = path.basenameWithoutExtension(fileName);
      destPath = path.join(
        attachDir.path,
        '${name}_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
    }
    await File(srcPath).copy(destPath);
    return destPath;
  }

  Future<void> _processFile(String srcPath) async {
    if (_currentNote == null || _editor == null) return;
    final destPath = await _copyToAppDir(srcPath);
    if (_isImage(destPath)) {
      _editor!.insertImage(destPath);
    } else {
      _editor!.insertFile(destPath, path.basename(destPath));
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;
    for (final file in result.files) {
      if (file.path != null) await _processFile(file.path!);
    }
  }

  Future<void> _handleDrop(DropDoneDetails details) async {
    for (final file in details.files) {
      await _processFile(file.path);
    }
  }

  /// Ctrl+V: 캡처한 이미지나 이미지 파일 경로면 이미지 블록으로
  Future<bool> _handlePaste() async {
    final editor = _editor;
    if (editor == null || _currentNote == null) return false;

    final imageBytes = await Pasteboard.image;
    if (imageBytes != null) {
      final appDir = await getApplicationSupportDirectory();
      final dir = Directory(
        path.join(appDir.path, 'Attachments', _currentNote!.id.toString()),
      );
      await dir.create(recursive: true);
      final file = File(
        path.join(
          dir.path,
          'paste_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await file.writeAsBytes(imageBytes);
      editor.insertImage(file.path);
      return true;
    }

    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (text != null &&
        !text.contains('\n') &&
        _isImage(text) &&
        File(text).existsSync()) {
      editor.insertImage(text);
      return true;
    }
    return false;
  }

  // ───────────── 메뉴 동작

  Future<void> _showLocationSearchDialog() async {
    final result = await showDialog<LocationSearchResult>(
      context: context,
      builder: (context) => const LocationSearchDialog(),
    );
    if (result == null) return;
    _editor?.insertBlocks([
      EditorBlock.location(result.name, result.lat, result.lng),
    ]);
  }

  List<SlashMenuItem> get _extraSlashItems => [
    SlashMenuItem('Location', Icons.location_pin, [
      '위치',
      'location',
      'map',
      '지도',
    ], _showLocationSearchDialog),
    SlashMenuItem('Code', Icons.code, [
      '코드',
      'code',
      '코드블록',
    ], () => _editor?.insertBlocks([EditorBlock.code()])),
    SlashMenuItem('file', Icons.attach_file, ['파일', 'file', '첨부'], _pickFile),
    SlashMenuItem(
      'Ask AI',
      Icons.auto_awesome,
      ['ai', 'ask', '질문', 'gemini'],
      () => showDialog(context: context, builder: (_) => const AskAiDialog()),
    ),
  ];

  // ───────────── 메모 링크 `[[`

  /// 제목이 검색어로 시작하는 메모 먼저, 검색어가 없으면 최근 수정한 메모부터
  List<NoteLinkTarget> _searchNoteLinks(String query) {
    final q = query.toLowerCase();
    final candidates = _allNotes.where(
      (n) => n.id != null && n.id != _currentNote?.id,
    );
    final List<Note> matches;
    if (q.isEmpty) {
      matches = candidates.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } else {
      final starts = <Note>[];
      final contains = <Note>[];
      for (final note in candidates) {
        final title = note.title.toLowerCase();
        if (title.startsWith(q)) {
          starts.add(note);
        } else if (title.contains(q)) {
          contains.add(note);
        }
      }
      matches = [...starts, ...contains];
    }
    return [for (final n in matches) (id: n.id!, title: n.title)];
  }

  void _openNoteLink(int noteId) {
    final note = _allNotes.where((n) => n.id == noteId).firstOrNull;
    if (note == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('삭제되었거나 찾을 수 없는 메모입니다')));
      return;
    }
    ref.read(selectedNoteProvider.notifier).select(note);
  }

  // ───────────── 버전 기록

  Future<void> _showVersions() async {
    final note = _currentNote;
    if (note?.id == null) return;
    final version = await showNoteVersionDialog(context, note!.id!);
    if (version == null || !mounted) return;
    await _replaceContent(version.content, title: version.title);
  }

  /// 메모 내용을 통째로 바꿈 (지금 내용은 버전으로 남김)
  Future<void> _replaceContent(String content, {String? title}) async {
    final note = _currentNote;
    final editor = _editor;
    if (note?.id == null || editor == null) return;
    _cancelPendingSave();
    await NoteVersionService.snapshot(
      note!.id!,
      _titleController.text,
      editor.toJsonString(),
      force: true,
    );
    final updated = note.copyWith(
      title: title ?? _titleController.text,
      content: content,
    );
    await ref.read(noteListProvider.notifier).saveNote(updated);
    if (!mounted) return;
    // 기다리는 사이 입력한 내용이 바꾼 내용을 덮어쓰지 않게
    _cancelPendingSave();
    _currentNote = updated;
    _initEditor(updated);
  }

  // ───────────── 템플릿

  Future<void> _showTemplateMenu(BuildContext buttonContext) async {
    final templates = await NoteTemplateService.list();
    if (!mounted || !buttonContext.mounted) return;
    final box = buttonContext.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
      Offset.zero & overlay.size,
    );
    final choice = await showMenu<(String, NoteTemplate?)>(
      context: context,
      position: position,
      items: [
        for (final t in templates)
          PopupMenuItem(
            value: ('apply', t),
            height: 36,
            child: Builder(
              builder: (itemContext) => Row(
                children: [
                  const Icon(Icons.description_outlined, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.name, overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    tooltip: '템플릿 삭제',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(itemContext, ('delete', t)),
                  ),
                ],
              ),
            ),
          ),
        if (templates.isEmpty)
          const PopupMenuItem(
            enabled: false,
            height: 36,
            child: Text('저장한 템플릿이 없어요', style: TextStyle(fontSize: 13)),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: ('save', null),
          height: 36,
          child: Row(
            children: [
              Icon(Icons.save_outlined, size: 16),
              SizedBox(width: 8),
              Text('현재 메모를 템플릿으로 저장'),
            ],
          ),
        ),
      ],
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case ('apply', final NoteTemplate t):
        await _applyTemplate(t);
      case ('delete', final NoteTemplate t):
        await NoteTemplateService.delete(t);
        _toast('"${t.name}" 템플릿을 삭제했어요');
      case _:
        await _saveAsTemplate();
    }
  }

  /// 빈 메모면 템플릿 내용으로, 내용이 있으면 맨 아래에 이어서 넣음
  Future<void> _applyTemplate(NoteTemplate template) async {
    final editor = _editor;
    if (editor == null) return;
    final empty = editor.blocks.every(
      (b) => b.isText && b.controller.text.trim().isEmpty,
    );
    await _replaceContent(
      empty
          ? template.content
          : appendNoteContent(editor.toJsonString(), template.content),
    );
  }

  Future<void> _saveAsTemplate() async {
    final editor = _editor;
    if (editor == null) return;
    final nameController = TextEditingController(text: _titleController.text);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('템플릿으로 저장'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: '템플릿 이름'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (name == null || name.trim().isEmpty) return;
    await NoteTemplateService.save(name.trim(), editor.toJsonString());
    _toast('"${name.trim()}" 템플릿을 저장했어요');
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ───────────── 목차

  /// 목차에서 고른 제목으로 이동 (접힌 섹션 안이면 펼침)
  void _goToBlock(EditorBlock block) {
    final editor = _editor;
    if (editor == null) return;
    final blocks = editor.blocks;
    final index = blocks.indexOf(block);
    if (index < 0) return;
    var depth = block.depth;
    for (var i = index - 1; i >= 0 && depth > 0; i--) {
      if (blocks[i].depth >= depth) continue;
      if (blocks[i].isSection && blocks[i].collapsed) {
        editor.toggleCollapsed(blocks[i]);
      }
      depth = blocks[i].depth;
    }
    editor.focus(block, 0);
  }

  // ───────────── 글자 수

  String _statusText(BlockEditorController editor) {
    var count = 0;
    for (final block in editor.blocks) {
      if (block.isText) {
        count += stripInlineImages(block.controller.text).length;
      }
    }
    final digits = count.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '$digits자';
  }

  Future<void> _exportToPdf() async {
    final editor = _editor;
    if (_currentNote == null || editor == null) return;
    try {
      final tags = await ref
          .read(noteRepositoryProvider)
          .getNoteTags(_currentNote!.id!);
      await PdfExportService().exportToPdf(
        blocks: editor.blocks,
        title: _currentNote!.title,
        tags: tags,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF 내보내기 실패: $e')));
    }
  }

  Future<void> _exportToMarkdown() async {
    final editor = _editor;
    final note = _currentNote;
    if (note == null || editor == null) return;
    final name = note.title.trim().isEmpty
        ? '제목없음'
        : note.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), ' ').trim();
    final mdPath = await FilePicker.platform.saveFile(
      dialogTitle: '마크다운으로 내보내기',
      fileName: '$name.md',
      type: FileType.custom,
      allowedExtensions: ['md'],
    );
    if (mdPath == null) return;
    try {
      await ref
          .read(noteImportExportProvider)
          .exportNote(
            note: note,
            blocks: editor.blocks,
            mdPath: mdPath.toLowerCase().endsWith('.md')
                ? mdPath
                : '$mdPath.md',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('마크다운으로 내보냈습니다')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('마크다운 내보내기 실패: $e')));
    }
  }

  Future<void> _showTagDialog() async {
    if (_currentNote == null) return;
    final repo = ref.read(noteRepositoryProvider);
    final currentTags = await repo.getNoteTags(_currentNote!.id!);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => MemoEditorTagDialog(
        noteId: _currentNote!.id!,
        initialTags: currentTags,
      ),
    );
    // 다이얼로그 닫힌 후 메모 갱신
    ref.read(noteListProvider.notifier).refresh();
  }

  Future<void> _removeTag(String tag) async {
    final note = _currentNote;
    if (note == null) return;
    await ref
        .read(noteRepositoryProvider)
        .saveNoteTags(note.id!, [...note.tags]..remove(tag));
    ref.read(noteListProvider.notifier).refresh();
  }

  // 에디터 위젯은 메모(컨트롤러)가 바뀔 때만 새로 만듦.
  // 저장할 때마다 메모 목록이 갱신되어 이 화면이 다시 그려지는데, 같은 위젯 객체를
  // 넘기면 Flutter가 에디터 전체를 다시 만들지 않음 (긴 메모 버벅임 원인).
  Widget? _editorWidget;
  BlockEditorController? _editorWidgetOwner;

  Widget _editorWidgetFor(BlockEditorController editor) {
    if (_editorWidgetOwner != editor) {
      _editorWidgetOwner = editor;
      _editorWidget = BlockEditor(
        controller: editor,
        extraSlashItems: _extraSlashItems,
        onPaste: _handlePaste,
        onFind: _openFind,
        noteLinkSearch: _searchNoteLinks,
        onOpenNoteLink: _openNoteLink,
        padding: const EdgeInsets.fromLTRB(44, 0, 36, 0),
      );
    }
    return _editorWidget!;
  }

  Widget _buildEditorArea(BlockEditorController editor) {
    return Stack(
      children: [
        Positioned.fill(child: _editorWidgetFor(editor)),
        if (_findOpen)
          Positioned(
            top: 0,
            right: 24,
            child: FindBar(
              key: ValueKey(editor),
              controller: editor,
              replaceMode: _replaceMode,
              onToggleReplace: () =>
                  setState(() => _replaceMode = !_replaceMode),
              onClose: _closeFind,
            ),
          ),
      ],
    );
  }

  void _openFind(bool replace) {
    setState(() {
      _findOpen = true;
      _replaceMode = replace;
    });
  }

  void _closeFind() {
    _editor?.clearFindHighlights();
    setState(() => _findOpen = false);
  }

  // ───────────── 화면

  Widget _buildToggleButton({
    required IconData icon,
    required Color activeColor,
    required bool isActive,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive ? activeColor : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _toolbarButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onPressed: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedNote = ref.watch(selectedNoteProvider);
    _noteList = ref.read(noteListProvider.notifier);
    // 자동 저장마다 목록이 바뀌어도 화면에 보이는 값이 같으면 다시 그리지 않음
    final selectedId = selectedNote?.id;
    ref.watch(
      noteListProvider.select((s) {
        final n = s.value?.where((n) => n.id == selectedId).firstOrNull;
        if (n == null) return null;
        return (
          n.isFavorite,
          n.isPinned,
          n.isImportant,
          n.updatedAt,
          n.tags.join('\n'),
        );
      }),
    );
    final notes = ref.read(noteListProvider).value ?? const <Note>[];

    // 링크 후보는 다음에 `[[`를 열 때 다시 불러옴
    ref.listen(noteListProvider, (_, _) => _allNotesStale = true);

    ref.listen(navigationProvider, (prev, next) {
      if (prev == 0 && next != 0 && _findOpen) _closeFind();
    });

    // 이미 열려 있는 메모의 체크리스트로 이동 (다른 메모면 _initEditor에서 처리)
    ref.listen(memoFocusRequestProvider, (_, next) {
      if (next != null && next.noteId == _currentNote?.id) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _applyFocusRequest(),
        );
      }
    });

    // 항상 최신 상태로 동기화
    if (selectedNote != null) {
      final freshNote = notes.firstWhere(
        (n) => n.id == selectedNote.id,
        orElse: () => selectedNote,
      );
      if (freshNote.id != _currentNote?.id) {
        // 이전 메모의 저장 대기분을 바로 저장 (500ms 안에 전환해도 잃지 않게)
        _flushSave();
        _currentNote = freshNote;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(tabProvider.notifier).addTab(freshNote.id!);
          _initEditor(freshNote);
        });
      } else {
        _currentNote = freshNote;
        if (_editorNote?.id == freshNote.id) _editorNote = freshNote;
      }
    }

    if (selectedNote == null) {
      return const Center(
        child: Text(
          '메모를 선택하세요',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    final editor = _editor;
    if (editor == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final hasTags = _currentNote != null && _currentNote!.tags.isNotEmpty;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        await _handleDrop(details);
      },
      child: Stack(
        children: [
          Column(
            children: [
              const MemoTabBar(),
              // 태그: 제목 위 (메모와 함께 불러온 목록 사용, X로 바로 제거)
              if (hasTags)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final tag in _currentNote!.tags)
                          Container(
                            padding: const EdgeInsets.fromLTRB(8, 2, 4, 2),
                            decoration: BoxDecoration(
                              color: context.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '#$tag',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.accent,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Tooltip(
                                  message: '태그 제거',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _removeTag(tag),
                                    child: Padding(
                                      padding: EdgeInsets.all(2),
                                      child: Icon(
                                        Icons.close,
                                        size: 12,
                                        color: context.accent,
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
                ),
              Padding(
                // 태그가 있으면 태그와 제목 사이를 좁게
                padding: EdgeInsets.fromLTRB(24, hasTags ? 4 : 20, 24, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleController,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          hintText: '제목 없음',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                        onChanged: (_) => _onContentChanged(),
                      ),
                    ),
                    // 토글 버튼들
                    if (_currentNote != null) ...[
                      _buildToggleButton(
                        icon: Icons.star,
                        activeColor: Colors.amber,
                        isActive: _currentNote!.isFavorite,
                        tooltip: _currentNote!.isFavorite ? '즐겨찾기 해제' : '즐겨찾기',
                        onTap: () => ref
                            .read(noteListProvider.notifier)
                            .toggleFavorite(
                              _currentNote!.id!,
                              !_currentNote!.isFavorite,
                            ),
                      ),
                      const SizedBox(width: 4),
                      _buildToggleButton(
                        icon: Icons.push_pin,
                        activeColor: context.accent,
                        isActive: _currentNote!.isPinned,
                        tooltip: _currentNote!.isPinned ? '고정 해제' : '고정',
                        onTap: () => ref
                            .read(noteListProvider.notifier)
                            .togglePin(
                              _currentNote!.id!,
                              !_currentNote!.isPinned,
                            ),
                      ),
                      const SizedBox(width: 4),
                      _buildToggleButton(
                        icon: Icons.priority_high,
                        activeColor: Colors.orange,
                        isActive: _currentNote!.isImportant,
                        tooltip: _currentNote!.isImportant ? '중요 해제' : '중요',
                        onTap: () => ref
                            .read(noteListProvider.notifier)
                            .toggleImportant(
                              _currentNote!.id!,
                              !_currentNote!.isImportant,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search, size: 18),
                        tooltip: '찾기/바꾸기 [Ctrl+F]',
                        onPressed: () => _openFind(false),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.toc,
                          size: 20,
                          color: _outlineOpen ? context.accent : null,
                        ),
                        tooltip: _outlineOpen ? '목차 닫기' : '목차',
                        onPressed: () =>
                            setState(() => _outlineOpen = !_outlineOpen),
                      ),
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: context.line),

              const SizedBox(height: 24), // 제목 <-> 내용 간격
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildEditorArea(editor)),
                    if (_outlineOpen)
                      OutlinePanel(
                        editor: editor,
                        refresh: _saveStatus,
                        onSelect: _goToBlock,
                        onClose: () => setState(() => _outlineOpen = false),
                      ),
                  ],
                ),
              ),
              // 하단 툴바
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: context.line)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _isToolbarExpanded
                            ? Icons.expand_more
                            : Icons.expand_less,
                        size: 18,
                      ),
                      tooltip: _isToolbarExpanded ? '툴바 접기' : '툴바 펼치기',
                      onPressed: () => setState(
                        () => _isToolbarExpanded = !_isToolbarExpanded,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    if (_isToolbarExpanded) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.attach_file, size: 18),
                        tooltip: '파일 첨부',
                        onPressed: _pickFile,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 4),
                      MemoEditorAlignDropdown(onAlign: editor.setAlign),
                      _toolbarButton(
                        Icons.format_bold,
                        '굵게 [Ctrl+B]',
                        () => editor.toggleMark('bold'),
                      ),
                      const SizedBox(width: 4),
                      _toolbarButton(
                        Icons.format_italic,
                        '기울임 [Ctrl+I]',
                        () => editor.toggleMark('italic'),
                      ),
                      const SizedBox(width: 4),
                      _toolbarButton(
                        Icons.format_underline,
                        '밑줄 [Ctrl+U]',
                        () => editor.toggleMark('underline'),
                      ),
                      const SizedBox(width: 4),
                      _toolbarButton(
                        Icons.format_strikethrough,
                        '취소선 [Ctrl+Shift+X]',
                        () => editor.toggleMark('strikethrough'),
                      ),
                      const SizedBox(width: 4),
                      MemoEditorColorDropdown(
                        tooltip: '글자색 [Alt+1~8]',
                        icon: Icons.format_color_text,
                        onOpen: null,
                        isHighlight: false,
                        onColorSelected: (color) =>
                            editor.toggleColor('font_color', color),
                      ),
                      const SizedBox(width: 4),
                      MemoEditorColorDropdown(
                        tooltip: '하이라이트 [Alt+↑+1~8]',
                        icon: Icons.highlight,
                        isHighlight: true,
                        onOpen: null,
                        onColorSelected: (color) =>
                            editor.toggleColor('bg_color', color),
                      ),
                      const SizedBox(width: 4),
                      _toolbarButton(
                        Icons.format_list_bulleted,
                        '불릿 목록 [Ctrl+4]',
                        () => editor.toggleBlockType('bulleted_list'),
                      ),
                      const SizedBox(width: 4),
                      _toolbarButton(
                        Icons.format_list_numbered,
                        '번호 목록 [Ctrl+5]',
                        () => editor.toggleBlockType('numbered_list'),
                      ),
                      const SizedBox(width: 4),
                      _toolbarButton(
                        Icons.check_box_outline_blank,
                        '체크박스 [Ctrl+6]',
                        () => editor.toggleBlockType('todo_list'),
                      ),
                      const SizedBox(width: 4),
                      _toolbarButton(
                        Icons.horizontal_rule,
                        '구분선 [Ctrl+Shift+H]',
                        () => editor.insertBlocks([EditorBlock.divider()]),
                      ),
                      const SizedBox(width: 4),
                      _toolbarButton(
                        Icons.code,
                        '코드 블록 [Ctrl+Shift+C]',
                        () => editor.insertBlocks([EditorBlock.code()]),
                      ),
                      const SizedBox(width: 4),
                      _toolbarButton(
                        Icons.unfold_less,
                        '접기 섹션',
                        editor.insertSection,
                      ),
                      const SizedBox(width: 4),
                      _toolbarButton(Icons.label_outline, '태그', _showTagDialog),
                      const SizedBox(width: 8),
                      _toolbarButton(
                        Icons.picture_as_pdf,
                        'PDF 내보내기',
                        _exportToPdf,
                      ),
                      const SizedBox(width: 4),
                      _toolbarButton(
                        Icons.description_outlined,
                        '마크다운 내보내기',
                        _exportToMarkdown,
                      ),
                      const SizedBox(width: 4),
                      Builder(
                        builder: (buttonContext) => _toolbarButton(
                          Icons.dashboard_customize_outlined,
                          '템플릿',
                          () => _showTemplateMenu(buttonContext),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _toolbarButton(Icons.history, '버전 기록', _showVersions),
                      const SizedBox(width: 4),
                    ],
                    const Spacer(),
                    // 글자 수·마지막 수정 (저장될 때마다 갱신)
                    ValueListenableBuilder<_SaveStatus>(
                      valueListenable: _saveStatus,
                      builder: (context, _, _) => Text(
                        _statusText(editor),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<_SaveStatus>(
                      valueListenable: _saveStatus,
                      builder: (context, status, _) => switch (status) {
                        _SaveStatus.saving => const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        _SaveStatus.saved => const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.blueGrey,
                        ),
                        _SaveStatus.idle => const SizedBox.shrink(),
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isDragging)
            Container(
              decoration: BoxDecoration(
                color: const Color.fromRGBO(74, 144, 226, 0.1),
                border: Border.all(color: context.accent, width: 2),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_file, size: 48, color: context.accent),
                    SizedBox(height: 8),
                    Text(
                      '파일을 여기에 놓으세요',
                      style: TextStyle(
                        fontSize: 16,
                        color: context.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
