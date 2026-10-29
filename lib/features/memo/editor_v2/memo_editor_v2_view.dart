import 'package:taskmanager/core/theme/app_colors.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart'
    show Document, EditorState, markdownToDocument;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../core/providers/navigation_provider.dart';
import '../../map/services/location_search_result.dart';
import '../../map/widgets/location_search_dialog.dart';
import '../data/note_repository.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';
import '../providers/tab_provider.dart';
import '../services/pdf_export_service.dart';
import '../views/memo_editor_widgets.dart';
import '../widgets/ask_ai_dialog.dart';
import '../widgets/memo_tab_bar.dart';
import 'block_editor.dart';
import 'block_editor_controller.dart';
import 'editor_block.dart';
import 'find_bar.dart';

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

  static const _imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];

  bool _isImage(String filePath) =>
      _imageExts.contains(path.extension(filePath).toLowerCase());

  @override
  void dispose() {
    _saveTimer?.cancel();
    _editor?.dispose();
    _titleController.dispose();
    _saveStatus.dispose();
    super.dispose();
  }

  /// 메모 내용(appflowy 문서 JSON, 예전 메모는 마크다운)으로 에디터를 만듦
  void _initEditor(Note note) {
    _titleController.text = note.title;

    List<EditorBlock> blocks;
    try {
      blocks = note.content.isEmpty ? [] : blocksFromJson(note.content);
    } catch (_) {
      try {
        blocks = blocksFromJson(
          jsonEncode(markdownToDocument(note.content).toJson()),
        );
      } catch (_) {
        blocks = [];
      }
    }

    final old = _editor;
    final editor = BlockEditorController(blocks)
      ..onContentChanged = _onContentChanged;
    setState(() {
      _editor = editor;
      _findOpen = false;
    });
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    // 에디터가 그려진 뒤 대기 중인 체크리스트 이동 요청 처리
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyFocusRequest());
  }

  /// 에디터 변경 내용을 일정 시간 동안 모아서 저장합니다.
  void _onContentChanged() {
    if (_currentNote == null || _editor == null) return;

    _saveTimer?.cancel();
    _saveStatus.value = _SaveStatus.saving;

    _saveTimer = Timer(const Duration(milliseconds: 500), () async {
      final editor = _editor;
      if (_currentNote == null || editor == null) return;
      final updated = _currentNote!.copyWith(
        title: _titleController.text,
        content: editor.toJsonString(),
      );
      await ref.read(noteListProvider.notifier).saveNote(updated);
      if (!mounted) return;
      _saveStatus.value = _SaveStatus.saved;
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _saveStatus.value == _SaveStatus.saved) {
          _saveStatus.value = _SaveStatus.idle;
        }
      });
    });
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
    _editor!.insertBlocks([
      _isImage(destPath)
          ? EditorBlock.image(destPath)
          : EditorBlock.file(destPath, path.basename(destPath)),
    ]);
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
      editor.insertBlocks([EditorBlock.image(file.path)]);
      return true;
    }

    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (text != null &&
        !text.contains('\n') &&
        _isImage(text) &&
        File(text).existsSync()) {
      editor.insertBlocks([EditorBlock.image(text)]);
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

  Future<void> _exportToPdf() async {
    final editor = _editor;
    if (_currentNote == null || editor == null) return;
    try {
      final tags = await ref
          .read(noteRepositoryProvider)
          .getNoteTags(_currentNote!.id!);
      // PDF 변환은 기존 문서 형식을 그대로 사용
      final document = Document.fromJson(
        jsonDecode(editor.toJsonString()) as Map<String, Object?>,
      );
      await PdfExportService().exportToPdf(
        editorState: EditorState(document: document),
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
        padding: const EdgeInsets.fromLTRB(44, 0, 36, 0),
      );
    }
    return _editorWidget!;
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
    final notes = ref.watch(noteListProvider).value ?? [];

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
        _currentNote = freshNote;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(tabProvider.notifier).addTab(freshNote.id!);
          _initEditor(freshNote);
        });
      } else {
        _currentNote = freshNote;
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
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: context.line),

              const SizedBox(height: 24), // 제목 <-> 내용 간격
              Expanded(
                child: Stack(
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
                    ],
                    const Spacer(),
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
