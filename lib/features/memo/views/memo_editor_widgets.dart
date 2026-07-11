import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/note_repository.dart';

/// 메모 에디터에서 사용하는 태그 관리 다이얼로그입니다.
class MemoEditorTagDialog extends ConsumerStatefulWidget {
  final int noteId;
  final List<String> initialTags;

  const MemoEditorTagDialog({
    super.key,
    required this.noteId,
    required this.initialTags,
  });

  @override
  ConsumerState<MemoEditorTagDialog> createState() =>
      _MemoEditorTagDialogState();
}

class _MemoEditorTagDialogState extends ConsumerState<MemoEditorTagDialog> {
  late List<String> _tags;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.initialTags);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _controller.text.trim();
    if (tag.isEmpty || _tags.contains(tag)) return;
    setState(() => _tags.add(tag));
    _controller.clear();
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  Future<void> _save() async {
    final repo = ref.read(noteRepositoryProvider);
    await repo.saveNoteTags(widget.noteId, _tags);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '태그 관리',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '태그 입력',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                      prefixText: '# ',
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTag,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('추가'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_tags.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text('#$tag', style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => _removeTag(tag),
                    backgroundColor: const Color(0xFFE8F0FE),
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                }).toList(),
              )
            else
              const Text(
                '태그가 없어요',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('저장'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 에디터 정렬 드롭다운 메뉴 위젯입니다.
class MemoEditorAlignDropdown extends StatelessWidget {
  final void Function(String align) onAlign;

  const MemoEditorAlignDropdown({required this.onAlign, super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '정렬',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: const Icon(Icons.format_align_left, size: 18),
      onSelected: onAlign,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'left',
          child: Row(
            children: [
              Icon(Icons.format_align_left, size: 16),
              SizedBox(width: 8),
              Text('왼쪽 정렬'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'center',
          child: Row(
            children: [
              Icon(Icons.format_align_center, size: 16),
              SizedBox(width: 8),
              Text('가운데 정렬'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'right',
          child: Row(
            children: [
              Icon(Icons.format_align_right, size: 16),
              SizedBox(width: 8),
              Text('오른쪽 정렬'),
            ],
          ),
        ),
      ],
    );
  }
}

/// 에디터 색상 선택 드롭다운 위젯입니다.
class MemoEditorColorDropdown extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final void Function(Color color) onColorSelected;
  final VoidCallback? onOpen;

  static const _colors = [
    (Color(0xFFE53935), '빨강'),
    (Color(0xFFFF9800), '주황'),
    (Color(0xFFFFEB3B), '노랑'),
    (Color(0xFF4CAF50), '초록'),
    (Color(0xFF2196F3), '파랑'),
    (Color(0xFF3F51B5), '남색'),
    (Color(0xFF9C27B0), '보라'),
    (Color(0xFF9E9E9E), '회색'),
    (Color(0xFF009688), '에메랄드'),
  ];

  const MemoEditorColorDropdown({
    required this.tooltip,
    required this.icon,
    required this.onColorSelected,
    required this.onOpen,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Color>(
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Icon(icon, size: 18),
      onOpened: onOpen,
      onSelected: onColorSelected,
      itemBuilder: (context) => _colors.map((item) {
        final (color, label) = item;
        return PopupMenuItem(
          value: color,
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        );
      }).toList(),
    );
  }
}
