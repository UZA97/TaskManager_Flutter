import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'editor_block.dart';

/// 체크리스트 마감일 (block.data에 'yyyy-MM-dd'로 저장, 캘린더·브리핑에 표시)
const todoDueKey = 'due';

DateTime? parseDueDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

String formatDueDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// 체크리스트 줄 오른쪽의 마감일: 있으면 날짜 칩, 없으면 커서가 있을 때만 달력 버튼
class TodoDueButton extends StatelessWidget {
  const TodoDueButton({
    super.key,
    required this.block,
    required this.onChanged,
  });

  final EditorBlock block;
  final VoidCallback onChanged;

  DateTime? get _due => parseDueDate(block.data[todoDueKey]);

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
      helpText: '마감일',
    );
    if (picked == null) return;
    block.data[todoDueKey] = formatDueDate(picked);
    onChanged();
  }

  Future<void> _showMenu(BuildContext context, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<bool>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: true, height: 36, child: Text('날짜 변경')),
        PopupMenuItem(value: false, height: 36, child: Text('날짜 지우기')),
      ],
    );
    if (!context.mounted || action == null) return;
    if (action) return _pick(context);
    block.data.remove(todoDueKey);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final due = _due;
    if (due == null) {
      // 날짜가 없으면 그 줄에 커서가 있을 때만 버튼을 보여 줌
      return ListenableBuilder(
        listenable: block.focusNode,
        builder: (context, _) => block.focusNode.hasFocus
            ? Tooltip(
                message: '마감일 (캘린더·브리핑에 표시)',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _pick(context),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(
                      Icons.event_outlined,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      );
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final overdue = !block.checked && due.isBefore(today);
    final color = block.checked
        ? Colors.grey
        : overdue
        ? Colors.red
        : DateUtils.isSameDay(due, today)
        ? context.accent
        : Colors.grey[600]!;
    final label = due.year == today.year
        ? '${due.month}/${due.day}'
        : '${due.year}/${due.month}/${due.day}';
    return GestureDetector(
      onTapDown: (details) => _showMenu(context, details.globalPosition),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          margin: const EdgeInsets.only(left: 6, top: 1),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event, size: 12, color: color),
              const SizedBox(width: 3),
              Text(label, style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
