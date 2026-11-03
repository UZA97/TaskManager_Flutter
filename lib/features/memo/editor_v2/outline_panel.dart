import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'block_editor_controller.dart';
import 'editor_block.dart';
import 'inline_image.dart';

/// 오른쪽 목차: 메모의 제목(H1~H3)과 섹션 제목 목록. 누르면 그 줄로 이동.
class OutlinePanel extends StatelessWidget {
  const OutlinePanel({
    super.key,
    required this.editor,
    required this.refresh,
    required this.onSelect,
    required this.onClose,
  });

  final BlockEditorController editor;

  /// 글자가 바뀌면(저장될 때) 다시 그림
  final Listenable refresh;
  final void Function(EditorBlock block) onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: context.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            child: Row(
              children: [
                const Text(
                  '목차',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  tooltip: '목차 닫기',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([editor, refresh]),
              builder: (context, _) {
                final items = [
                  for (final block in editor.blocks)
                    if ((block.type == 'heading' || block.isSection) &&
                        stripInlineImages(
                          block.controller.text,
                        ).trim().isNotEmpty)
                      block,
                ];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      '제목(H1~H3)이나 섹션을 넣으면\n여기에 목차가 생겨요',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _OutlineItem(
                    block: items[i],
                    onTap: () => onSelect(items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineItem extends StatelessWidget {
  const _OutlineItem({required this.block, required this.onTap});

  final EditorBlock block;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // H1은 굵게, 아래 단계일수록 들여씀. 섹션은 H3 위치에 접기 아이콘
    final level = block.isSection ? 3 : block.level.clamp(1, 3);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          14 + (level - 1) * 12.0 + block.depth * 8,
          6,
          10,
          6,
        ),
        child: Row(
          children: [
            if (block.isSection) ...[
              const Icon(Icons.unfold_less, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                stripInlineImages(block.controller.text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: level == 1 ? 13 : 12,
                  fontWeight: level == 1 ? FontWeight.w600 : null,
                  color: level == 1 ? null : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
