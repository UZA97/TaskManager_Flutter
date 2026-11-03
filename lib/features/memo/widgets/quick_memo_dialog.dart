import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/note_repository.dart';
import '../providers/note_provider.dart';

/// 어디서든 Ctrl+Alt+M으로 여는 빠른 메모. 저장하면 새 메모로 만들어짐.
/// 저장했으면 true.
Future<bool> showQuickMemoDialog(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => const _QuickMemoDialog(),
    ) ??
    false;

/// 한 줄씩 문단으로 된 메모 본문 (appflowy 문서 JSON)
String plainTextToNoteContent(String text) => jsonEncode({
  'document': {
    'type': 'page',
    'children': [
      for (final line in text.split('\n'))
        {
          'type': 'paragraph',
          'data': {
            'delta': [
              if (line.isNotEmpty) {'insert': line},
            ],
          },
        },
    ],
  },
});

class _QuickMemoDialog extends ConsumerStatefulWidget {
  const _QuickMemoDialog();

  @override
  ConsumerState<_QuickMemoDialog> createState() => _QuickMemoDialogState();
}

class _QuickMemoDialogState extends ConsumerState<_QuickMemoDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final body = _body.text.trimRight();
    if (_saving || (title.isEmpty && body.isEmpty)) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(noteRepositoryProvider);
      final note = await repo.createNote(); // 폴더 없이 맨 위에
      await repo.saveNote(
        note.copyWith(
          // 제목이 없으면 첫 줄을 제목으로
          title: title.isNotEmpty ? title : body.split('\n').first.trim(),
          content: plainTextToNoteContent(body),
        ),
      );
      await ref.read(noteListProvider.notifier).refresh();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text('메모 저장 실패: $e')));
      }
    } finally {
      // 실패해도 다시 저장할 수 있도록
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true):
            _save,
      },
      child: Dialog(
        backgroundColor: context.popupSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: SizedBox(
          width: 480,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt, size: 18, color: context.accent),
                    const SizedBox(width: 6),
                    const Text(
                      '빠른 메모',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: _title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    hintText: '제목 (비우면 첫 줄)',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                TextField(
                  controller: _body,
                  autofocus: true,
                  minLines: 6,
                  maxLines: 12,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '내용을 입력하세요',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: context.surfaceSoft,
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'Ctrl+Enter 저장 · Esc 닫기',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: const Text('저장'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
