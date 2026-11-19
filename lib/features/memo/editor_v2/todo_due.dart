import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'editor_block.dart';

/// 체크리스트 줄을 캘린더 일정으로 등록하면 그 일정 번호와 날짜를 block.data에 남김
/// (날짜는 칩 표시용, 일정을 고치면 다시 맞춤)
const todoEventIdKey = 'eventId';
const todoEventDateKey = 'eventDate';

/// 예전 버전의 마감일 ('yyyy-MM-dd'). 이제는 캘린더 일정을 만들 때 기본 날짜로만 씀
const todoDueKey = 'due';

DateTime? parseDueDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

/// 체크리스트 줄 오른쪽의 캘린더 버튼.
/// 일정이 연결돼 있으면 날짜 칩(누르면 일정 편집), 없으면 커서가 있을 때만 달력 버튼
/// (누르면 이 줄로 일정 만들기).
class TodoCalendarButton extends StatelessWidget {
  const TodoCalendarButton({
    super.key,
    required this.block,
    required this.onOpen,
  });

  final EditorBlock block;

  /// 일정 만들기·편집 창 열기 (메모 화면이 처리)
  final void Function(EditorBlock block) onOpen;

  @override
  Widget build(BuildContext context) {
    // 입력창 영역으로 묶음: 데스크톱에서는 입력창 밖을 누르면 포커스가 풀리는데,
    // 그러면 버튼이 누르는 도중에 사라져 클릭이 먹히지 않음
    return TextFieldTapRegion(child: _build(context));
  }

  Widget _build(BuildContext context) {
    final linked = block.data[todoEventIdKey] is num;
    final date = linked
        ? parseDueDate(block.data[todoEventDateKey])
        : parseDueDate(block.data[todoDueKey]);

    if (date == null) {
      // 날짜가 없으면 그 줄에 커서가 있을 때만 버튼을 보여 줌
      return ListenableBuilder(
        listenable: block.focusNode,
        builder: (context, _) => block.focusNode.hasFocus
            ? Tooltip(
                message: '캘린더에 일정으로 등록',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => onOpen(block),
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
    final color = !linked || block.checked
        ? Colors.grey
        : DateUtils.isSameDay(date, today)
        ? context.accent
        : Colors.grey[600]!;
    final label = date.year == today.year
        ? '${date.month}/${date.day}'
        : '${date.year}/${date.month}/${date.day}';
    return Tooltip(
      message: linked ? '캘린더 일정 · 눌러서 편집' : '캘린더에 없는 날짜 · 눌러서 일정으로 등록',
      child: GestureDetector(
        onTap: () => onOpen(block),
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
                Icon(
                  linked ? Icons.event : Icons.event_outlined,
                  size: 12,
                  color: color,
                ),
                const SizedBox(width: 3),
                Text(label, style: TextStyle(fontSize: 11, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
