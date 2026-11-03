import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../services/note_version_service.dart';

/// 버전 기록: 왼쪽 시각 목록, 오른쪽 미리보기. 복원할 버전을 돌려줌.
Future<NoteVersion?> showNoteVersionDialog(BuildContext context, int noteId) =>
    showDialog<NoteVersion>(
      context: context,
      builder: (_) => _NoteVersionDialog(noteId: noteId),
    );

class _NoteVersionDialog extends StatefulWidget {
  const _NoteVersionDialog({required this.noteId});

  final int noteId;

  @override
  State<_NoteVersionDialog> createState() => _NoteVersionDialogState();
}

class _NoteVersionDialogState extends State<_NoteVersionDialog> {
  List<NoteVersion>? _versions;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    NoteVersionService.list(widget.noteId).then((versions) {
      if (mounted) setState(() => _versions = versions);
    });
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  String _timeLabel(DateTime time) {
    final now = DateTime.now();
    final clock = '${_two(time.hour)}:${_two(time.minute)}';
    if (DateUtils.isSameDay(time, now)) return '오늘 $clock';
    if (DateUtils.isSameDay(time, now.subtract(const Duration(days: 1)))) {
      return '어제 $clock';
    }
    final date = time.year == now.year
        ? '${time.month}/${time.day}'
        : '${time.year}/${time.month}/${time.day}';
    return '$date $clock';
  }

  @override
  Widget build(BuildContext context) {
    final versions = _versions;
    final selected = versions == null || versions.isEmpty
        ? null
        : versions[_selected];
    return Dialog(
      backgroundColor: context.popupSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: 760,
        height: 520,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Icon(Icons.history, size: 20, color: context.accent),
                  const SizedBox(width: 8),
                  const Text(
                    '버전 기록',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '메모를 열 때와 편집 중 10분마다 저장돼요',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: context.line),
            Expanded(
              child: versions == null
                  ? const Center(child: CircularProgressIndicator())
                  : versions.isEmpty
                  ? const Center(
                      child: Text(
                        '아직 저장된 버전이 없어요',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 200,
                          child: ListView.builder(
                            itemCount: versions.length,
                            itemBuilder: (context, i) => ListTile(
                              dense: true,
                              selected: i == _selected,
                              selectedTileColor: context.selectedTint,
                              selectedColor: context.accent,
                              title: Text(_timeLabel(versions[i].time)),
                              subtitle: Text(
                                versions[i].title.isEmpty
                                    ? '(제목 없음)'
                                    : versions[i].title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () => setState(() => _selected = i),
                            ),
                          ),
                        ),
                        VerticalDivider(width: 1, color: context.line),
                        Expanded(child: _Preview(version: selected!)),
                      ],
                    ),
            ),
            Divider(height: 1, color: context.line),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text(
                    '복원하면 지금 내용도 버전으로 남아요',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text('이 버전으로 복원'),
                    onPressed: selected == null
                        ? null
                        : () => Navigator.pop(context, selected),
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

class _Preview extends StatelessWidget {
  const _Preview({required this.version});

  final NoteVersion version;

  @override
  Widget build(BuildContext context) {
    final lines = noteContentLines(version.content);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          version.title.isEmpty ? '제목 없음' : version.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        SelectableText(
          lines.join('\n'),
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
      ],
    );
  }
}
