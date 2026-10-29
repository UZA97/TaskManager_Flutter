import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'link_preview.dart';

/// 앱 화면(밝게/다크 모드)에 맞춘 색
class _Palette {
  _Palette(BuildContext context)
    : background = context.popupSurface,
      field = context.isDark
          ? const Color(0xFF424242)
          : const Color(0xFFF1F3F4),
      text = context.isDark ? darkText : const Color(0xFF222222),
      accent = context.accent;

  final Color background;
  final Color field;
  final Color text;
  final Color accent;
  static const hint = Color(0xFF9E9E9E);
}

/// `/` 메뉴의 Embed Video: 링크를 넣으면 미리보기를 보여주고, Done이면 그 링크를 돌려줌
Future<String?> showEmbedVideoDialog(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (_) => const _EmbedVideoDialog(),
    );

class _EmbedVideoDialog extends StatefulWidget {
  const _EmbedVideoDialog();

  @override
  State<_EmbedVideoDialog> createState() => _EmbedVideoDialogState();
}

class _EmbedVideoDialogState extends State<_EmbedVideoDialog> {
  final _link = TextEditingController();
  String? _id;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _done() {
    final id = _id;
    if (id == null) return;
    var url = _link.text.trim();
    if (!url.contains('://')) url = 'https://$url';
    Navigator.of(context).pop(url);
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    final p = _Palette(context);
    return Dialog(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 600,
        height: 460,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _HeaderButton(
                        label: 'Cancel',
                        color: p.accent,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Text(
                      'Embed Video',
                      style: TextStyle(
                        color: p.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _HeaderButton(
                        label: 'Done',
                        color: id == null ? _Palette.hint : p.accent,
                        bold: true,
                        onTap: id == null ? null : _done,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _link,
                autofocus: true,
                style: TextStyle(color: p.text, fontSize: 14),
                cursorColor: p.accent,
                decoration: InputDecoration(
                  hintText: 'Please enter a link',
                  hintStyle: const TextStyle(
                    color: _Palette.hint,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: p.field,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (text) =>
                    setState(() => _id = youtubeIdOfUrl(text.trim())),
                onSubmitted: (_) => _done(),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: p.field,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: id == null
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            'Preview',
                            style: TextStyle(
                              color: _Palette.hint,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : _Preview(id: id, textColor: p.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.bold = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool bold;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
    child: GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: bold ? FontWeight.w600 : null,
        ),
      ),
    ),
  );
}

/// 썸네일 + 제목
class _Preview extends StatelessWidget {
  const _Preview({required this.id, required this.textColor});

  final String id;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      youtubeThumbnailUrl(id),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: Color(0xFFE0E0E0)),
                    ),
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        size: 56,
                        color: Color(0xDDFF0000),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        FutureBuilder<String?>(
          future: youtubeTitle(id),
          builder: (context, snapshot) => Text(
            snapshot.data ?? 'YouTube',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor, fontSize: 14),
          ),
        ),
      ],
    ),
  );
}
