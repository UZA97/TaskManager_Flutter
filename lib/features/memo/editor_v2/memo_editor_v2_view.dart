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
import '../../calendar/data/event_repository.dart';
import '../../calendar/providers/event_provider.dart';
import '../../calendar/views/calendar_editor_view.dart';
import '../../map/services/location_search_result.dart';
import '../../map/widgets/location_search_dialog.dart';
import '../../todo/todo_memo.dart';
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
import '../widgets/backlinks_button.dart';
import '../widgets/memo_tab_bar.dart';
import '../widgets/note_version_dialog.dart';
import 'block_editor.dart';
import 'block_editor_controller.dart';
import 'editor_block.dart';
import 'inline_image.dart';
import 'note_dates.dart';
import 'find_bar.dart';
import 'outline_panel.dart';
import 'styled_text_controller.dart';
import 'todo_due.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFocusRequest();
      _applyLocationRequest();
      _applyTodoRequest();
    });
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

  /// 지도에서 고른 장소를 이 메모 끝에 위치 블록으로 넣음
  void _applyLocationRequest() {
    final request = ref.read(memoLocationRequestProvider);
    final editor = _editor;
    if (!mounted ||
        request == null ||
        editor == null ||
        request.noteId != _currentNote?.id) {
      return;
    }
    ref.read(memoLocationRequestProvider.notifier).request(null);

    // 끝에 붙이려고 마지막 줄에 커서를 둠 (빈 줄이면 그 자리를 대신함)
    final last = editor.blocks.last;
    if (last.isText) {
      editor.focus(last, last.controller.text.length);
    } else {
      editor.insertParagraphAfter(last);
    }
    final next = EditorBlock(type: 'paragraph'); // 이어서 쓸 줄
    editor.insertBlocks([
      EditorBlock.location(request.name, request.lat, request.lng),
      next,
    ], focusTarget: next);
    // 새 메모면 장소 이름을 제목으로
    if (_titleController.text.trim().isEmpty) {
      _titleController.text = request.name;
    }
    _onContentChanged();
  }

  /// 할 일 탭에서 보낸 할 일을 고른 목차 맨 아래에 체크리스트로 넣음
  void _applyTodoRequest() {
    final request = ref.read(memoTodoRequestProvider);
    final editor = _editor;
    if (!mounted ||
        request == null ||
        editor == null ||
        request.noteId != _currentNote?.id) {
      return;
    }
    ref.read(memoTodoRequestProvider.notifier).request(null);

    final blocks = editor.blocks;
    // 고를 때와 줄 번호가 달라졌으면 같은 이름의 목차를 찾고, 없으면 맨 끝
    var anchor = request.anchor;
    if (anchor != null &&
        !(anchor < blocks.length &&
            isOutlineBlock(blocks[anchor]) &&
            outlineTextOf(blocks[anchor]) == request.anchorText)) {
      final found = blocks.indexWhere(
        (b) => isOutlineBlock(b) && outlineTextOf(b) == request.anchorText,
      );
      anchor = found < 0 ? null : found;
    }
    if (anchor != null && blocks[anchor].isSection) {
      blocks[anchor].data['collapsed'] = false; // 접힌 섹션이면 펼쳐서 보이게
    }
    final point = todoInsertPoint(blocks, anchor);
    editor.insertBlocksAt(
      point.index,
      memoTodoBlocks(request.lines, point.depth),
    );
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

  // ───────────── 글 속 날짜 → 캘린더

  static const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  static const _calendarTab = 1;

  String _dateLabel(DateMention m) {
    final d = m.date;
    final day =
        '${d.year}년 ${d.month}월 ${d.day}일 (${_weekdays[d.weekday - 1]})';
    if (!m.hasTime) return day;
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day ${d.hour < 12 ? '오전' : '오후'} $hour12:$minute';
  }

  /// 날짜를 뺀 그 줄의 글을 일정 제목으로 (없으면 메모 제목)
  String _eventTitleFrom(EditorBlock block, DateMention m) {
    final raw = block.controller.text;
    // 그림 글자를 빼기 전 위치 기준으로 날짜 부분을 잘라냄
    final title =
        stripInlineImages(
              m.end <= raw.length ? raw.replaceRange(m.start, m.end, ' ') : raw,
            )
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(RegExp(r'^[\s:\-~·,]+|[\s:\-~·,]+$'), '')
            .trim();
    if (title.isNotEmpty) return title;
    return _currentNote?.title.trim() ?? '';
  }

  Future<void> _onDateTap(
    DateMention m,
    EditorBlock block,
    Offset position,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        overlay.globalToLocal(position) & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          height: 28,
          child: Text(
            _dateLabel(m),
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
        const PopupMenuItem(
          value: 'event',
          height: 36,
          child: _MenuRow(Icons.event_available_outlined, '일정 만들기'),
        ),
        const PopupMenuItem(
          value: 'reminder',
          height: 36,
          child: _MenuRow(Icons.notifications_active_outlined, '알림 일정 만들기'),
        ),
        const PopupMenuItem(
          value: 'show',
          height: 36,
          child: _MenuRow(Icons.calendar_month_outlined, '캘린더에서 보기'),
        ),
      ],
    );
    if (!mounted || action == null) return;
    final date = DateUtils.dateOnly(m.date);
    if (action == 'show') {
      ref.read(currentMonthProvider.notifier)
        ..setYear(date.year)
        ..setMonth(date.month);
      ref.read(selectedDateProvider.notifier).select(date);
      ref.read(navigationProvider.notifier).navigateTo(_calendarTab);
      return;
    }
    final noteTitle = _currentNote?.title.trim() ?? '';
    await showDialog(
      context: context,
      builder: (context) => EventDialog(
        initialDate: date,
        initialTitle: _eventTitleFrom(block, m),
        initialContent: noteTitle.isEmpty ? null : '메모: $noteTitle',
        initialTime: m.hasTime ? TimeOfDay.fromDateTime(m.date) : null,
        initialAlarm: action == 'reminder',
      ),
    );
  }

  /// 체크리스트 줄 오른쪽의 캘린더 버튼: 연결된 일정이 있으면 편집, 없으면 이 줄로
  /// 새 일정을 만들어 연결. 일정은 캘린더에만 저장됨 (브리핑·할 일 탭과는 별개).
  Future<void> _onTodoCalendar(EditorBlock block) async {
    final editor = _editor;
    if (editor == null) return;
    final repo = ref.read(eventRepositoryProvider);
    final linkedId = (block.data[todoEventIdKey] as num?)?.toInt();
    final existing = linkedId == null
        ? null
        : await repo.getEventById(linkedId);
    if (!mounted) return;

    final noteTitle = _currentNote?.title.trim() ?? '';
    final savedId = await showDialog<int>(
      context: context,
      builder: (context) => existing != null
          ? EventDialog(
              initialDate:
                  DateTime.tryParse(existing.startDate ?? existing.eventDate) ??
                  DateTime.now(),
              event: existing,
            )
          : EventDialog(
              // 예전 버전에서 정한 마감일이 있으면 그 날짜로
              initialDate:
                  parseDueDate(block.data[todoDueKey]) ??
                  DateUtils.dateOnly(DateTime.now()),
              initialTitle: block.controller.text.trim(),
              initialContent: noteTitle.isEmpty ? null : '메모: $noteTitle',
            ),
    );

    // 저장·편집·삭제 결과를 다시 읽어 줄의 연결 정보를 맞춤
    final eventId = savedId ?? (existing != null ? linkedId : null);
    final event = eventId == null ? null : await repo.getEventById(eventId);
    if (!mounted || editor != _editor || !editor.blocks.contains(block)) return;
    final before = (
      block.data[todoEventIdKey],
      block.data[todoEventDateKey],
      block.data[todoDueKey],
    );
    if (event != null) {
      block.data[todoEventIdKey] = event.id;
      block.data[todoEventDateKey] = event.startDate ?? event.eventDate;
      block.data.remove(todoDueKey);
    } else if (linkedId != null) {
      // 연결된 일정이 지워짐
      block.data
        ..remove(todoEventIdKey)
        ..remove(todoEventDateKey);
    }
    final after = (
      block.data[todoEventIdKey],
      block.data[todoEventDateKey],
      block.data[todoDueKey],
    );
    if (before != after) editor.contentChanged();
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
        onDateTap: _onDateTap,
        onTodoCalendar: _onTodoCalendar,
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

  /// 메모 상태 토글 (즐겨찾기·고정·중요). 켜져 있으면 그 색으로 옅은 배경
  Widget _buildToggleButton({
    required IconData icon,
    required Color activeColor,
    required bool isActive,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return _toolbarButton(
      icon,
      tooltip,
      onTap,
      active: isActive,
      activeColor: activeColor,
      size: 32,
    );
  }

  Widget _toolbarButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed, {
    bool active = false,
    Color? activeColor,
    double size = 30,
  }) {
    final color = activeColor ?? context.accent;
    // 지금 줄·선택에 적용된 서식은 테마색으로 표시
    return IconButton(
      icon: Icon(icon, size: 18, color: active ? color : null),
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      style: IconButton.styleFrom(
        backgroundColor: active ? color.withValues(alpha: 0.18) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: onPressed,
    );
  }

  /// 커서가 있는 줄·선택에 적용돼 있으면 켜진 모양으로 보이는 서식 버튼
  Widget _formatButton(
    BlockEditorController editor,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
    bool Function() isActive,
  ) {
    return ListenableBuilder(
      listenable: editor.formatState,
      builder: (context, _) =>
          _toolbarButton(icon, tooltip, onPressed, active: isActive()),
    );
  }

  /// 관련 버튼끼리 묶는 둥근 칸
  Widget _toolGroup(List<Widget> children, {double radius = 8}) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            children[i],
          ],
        ],
      ),
    );
  }

  /// 드롭다운 버튼을 다른 버튼과 같은 크기 칸에 맞춤
  Widget _toolCell(Widget child) =>
      SizedBox(width: 30, height: 30, child: Center(child: child));

  // ───────────── 제목 줄

  Widget _buildHeader(bool hasTags) {
    final note = _currentNote;
    return Padding(
      // 태그가 있으면 태그와 제목 사이를 좁게
      padding: EdgeInsets.fromLTRB(36, hasTags ? 6 : 20, 24, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _titleController,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
              decoration: const InputDecoration(
                hintText: '제목 없음',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
                hintStyle: TextStyle(color: Colors.grey),
              ),
              onChanged: (_) => _onContentChanged(),
            ),
          ),
          if (note != null)
            _toolGroup(radius: 10, [
              _buildToggleButton(
                icon: Icons.star,
                activeColor: Colors.amber,
                isActive: note.isFavorite,
                tooltip: note.isFavorite ? '즐겨찾기 해제' : '즐겨찾기',
                onTap: () => ref
                    .read(noteListProvider.notifier)
                    .toggleFavorite(note.id!, !note.isFavorite),
              ),
              _buildToggleButton(
                icon: Icons.push_pin,
                activeColor: context.accent,
                isActive: note.isPinned,
                tooltip: note.isPinned ? '고정 해제' : '고정',
                onTap: () => ref
                    .read(noteListProvider.notifier)
                    .togglePin(note.id!, !note.isPinned),
              ),
              _buildToggleButton(
                icon: Icons.priority_high,
                activeColor: Colors.orange,
                isActive: note.isImportant,
                tooltip: note.isImportant ? '중요 해제' : '중요',
                onTap: () => ref
                    .read(noteListProvider.notifier)
                    .toggleImportant(note.id!, !note.isImportant),
              ),
              _toolbarButton(
                Icons.search,
                '찾기/바꾸기 [Ctrl+F]',
                () => _openFind(false),
                size: 32,
              ),
              _toolbarButton(
                Icons.toc,
                _outlineOpen ? '목차 닫기' : '목차',
                () => setState(() => _outlineOpen = !_outlineOpen),
                active: _outlineOpen,
                size: 32,
              ),
            ]),
        ],
      ),
    );
  }

  // ───────────── 하단 툴바

  /// 내보내기·템플릿·버전 기록을 한 메뉴로
  Future<void> _showMoreMenu(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(buttonContext).context.findRenderObject() as RenderBox;
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    PopupMenuItem<String> item(String value, IconData icon, String label) =>
        PopupMenuItem(
          value: value,
          height: 36,
          child: Row(
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        );
    final choice = await showMenu<String>(
      context: context,
      // 툴바가 화면 아래에 있으므로 버튼 위로 펼침
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: [
        item('pdf', Icons.picture_as_pdf, 'PDF 내보내기'),
        item('md', Icons.description_outlined, '마크다운 내보내기'),
        const PopupMenuDivider(),
        item('template', Icons.dashboard_customize_outlined, '템플릿'),
        item('versions', Icons.history, '버전 기록'),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'pdf':
        await _exportToPdf();
      case 'md':
        await _exportToMarkdown();
      case 'template':
        if (buttonContext.mounted) await _showTemplateMenu(buttonContext);
      case 'versions':
        await _showVersions();
    }
  }

  Widget _buildToolbar(BlockEditorController editor) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: context.line)),
      ),
      child: Row(
        children: [
          _toolbarButton(
            _isToolbarExpanded ? Icons.expand_more : Icons.expand_less,
            _isToolbarExpanded ? '툴바 접기' : '툴바 펼치기',
            () => setState(() => _isToolbarExpanded = !_isToolbarExpanded),
          ),
          const SizedBox(width: 6),
          if (_isToolbarExpanded)
            Expanded(
              // 창이 좁으면 툴바만 가로로 스크롤
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _toolGroup([
                      _toolbarButton(Icons.attach_file, '파일 첨부', _pickFile),
                      _toolCell(
                        ListenableBuilder(
                          listenable: editor.formatState,
                          builder: (context, _) => MemoEditorAlignDropdown(
                            onAlign: editor.setAlign,
                            current: editor.activeAlign,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(width: 8),
                    _toolGroup([
                      _formatButton(
                        editor,
                        Icons.format_bold,
                        '굵게 [Ctrl+B]',
                        () => editor.toggleMark('bold'),
                        () => editor.isMarkActive('bold'),
                      ),
                      _formatButton(
                        editor,
                        Icons.format_italic,
                        '기울임 [Ctrl+I]',
                        () => editor.toggleMark('italic'),
                        () => editor.isMarkActive('italic'),
                      ),
                      _formatButton(
                        editor,
                        Icons.format_underline,
                        '밑줄 [Ctrl+U]',
                        () => editor.toggleMark('underline'),
                        () => editor.isMarkActive('underline'),
                      ),
                      _formatButton(
                        editor,
                        Icons.format_strikethrough,
                        '취소선 [Ctrl+Shift+X]',
                        () => editor.toggleMark('strikethrough'),
                        () => editor.isMarkActive('strikethrough'),
                      ),
                      _toolCell(
                        ListenableBuilder(
                          listenable: editor.formatState,
                          builder: (context, _) => MemoEditorColorDropdown(
                            tooltip: '글자색 [Alt+1~8]',
                            icon: Icons.format_color_text,
                            onOpen: null,
                            isHighlight: false,
                            activeColor: StyledTextController.parseColor(
                              editor.activeMarkValue('font_color'),
                            ),
                            onColorSelected: (color) =>
                                editor.toggleColor('font_color', color),
                          ),
                        ),
                      ),
                      _toolCell(
                        ListenableBuilder(
                          listenable: editor.formatState,
                          builder: (context, _) => MemoEditorColorDropdown(
                            tooltip: '하이라이트 [Alt+↑+1~8]',
                            icon: Icons.highlight,
                            isHighlight: true,
                            onOpen: null,
                            activeColor: StyledTextController.parseColor(
                              editor.activeMarkValue('bg_color'),
                            ),
                            onColorSelected: (color) =>
                                editor.toggleColor('bg_color', color),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(width: 8),
                    _toolGroup([
                      _formatButton(
                        editor,
                        Icons.format_list_bulleted,
                        '불릿 목록 [Ctrl+4]',
                        () => editor.toggleBlockType('bulleted_list'),
                        () => editor.isBlockTypeActive('bulleted_list'),
                      ),
                      _formatButton(
                        editor,
                        Icons.format_list_numbered,
                        '번호 목록 [Ctrl+5]',
                        () => editor.toggleBlockType('numbered_list'),
                        () => editor.isBlockTypeActive('numbered_list'),
                      ),
                      _formatButton(
                        editor,
                        Icons.check_box_outlined,
                        '체크박스 [Ctrl+6]',
                        () => editor.toggleBlockType('todo_list'),
                        () => editor.isBlockTypeActive('todo_list'),
                      ),
                    ]),
                    const SizedBox(width: 8),
                    _toolGroup([
                      _toolbarButton(
                        Icons.horizontal_rule,
                        '구분선 [Ctrl+Shift+H]',
                        () => editor.insertBlocks([EditorBlock.divider()]),
                      ),
                      _toolbarButton(
                        Icons.code,
                        '코드 블록 [Ctrl+Shift+C]',
                        () => editor.insertBlocks([EditorBlock.code()]),
                      ),
                      _toolbarButton(
                        Icons.unfold_less,
                        '접기 섹션',
                        editor.insertSection,
                      ),
                      _toolbarButton(Icons.label_outline, '태그', _showTagDialog),
                    ]),
                    const SizedBox(width: 8),
                    Builder(
                      builder: (buttonContext) => TextButton.icon(
                        onPressed: () => _showMoreMenu(buttonContext),
                        icon: const Icon(Icons.ios_share, size: 16),
                        label: const Text(
                          '내보내기 · 템플릿 · 기록',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLowest,
                          minimumSize: const Size(0, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 8),
          if (_currentNote?.id != null) ...[
            BacklinksButton(
              noteId: _currentNote!.id!,
              onOpen: (n) => ref.read(selectedNoteProvider.notifier).select(n),
            ),
            const SizedBox(width: 8),
          ],
          // 저장 상태
          ValueListenableBuilder<_SaveStatus>(
            valueListenable: _saveStatus,
            builder: (context, status, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: switch (status) {
                _SaveStatus.saving => [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 6),
                  Text('저장 중', style: TextStyle(fontSize: 12, color: muted)),
                ],
                _SaveStatus.saved => [
                  Icon(
                    Icons.check,
                    size: 14,
                    // 밝은 배경에서는 진한 초록
                    color: context.isDark
                        ? const Color(0xFF6FCF97)
                        : const Color(0xFF2E9D5B),
                  ),
                  const SizedBox(width: 4),
                  Text('저장됨', style: TextStyle(fontSize: 12, color: muted)),
                ],
                _SaveStatus.idle => const [],
              },
            ),
          ),
        ],
      ),
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
    // 이미 열려 있는 메모에 지도 장소 넣기 (다른 메모면 _initEditor에서 처리)
    ref.listen(memoLocationRequestProvider, (_, next) {
      if (next != null && next.noteId == _currentNote?.id) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _applyLocationRequest(),
        );
      }
    });

    ref.listen(memoTodoRequestProvider, (_, next) {
      if (next != null && next.noteId == _currentNote?.id) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _applyTodoRequest(),
        );
      }
    });

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
              _buildHeader(hasTags),
              const SizedBox(height: 8), // 제목 <-> 내용 간격
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
              _buildToolbar(editor),
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

/// 아이콘 + 글자 메뉴 항목
class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: Colors.grey[700]),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 13)),
    ],
  );
}
