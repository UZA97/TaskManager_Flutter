import 'package:taskmanager/core/theme/app_colors.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:highlight/highlight.dart' show highlight;
import 'package:latlong2/latlong.dart';

import '../../../core/providers/navigation_provider.dart';
import '../../map/providers/map_provider.dart';
import '../../map/services/vworld_service.dart';
import 'editor_block.dart';

// 기존 에디터의 이미지·파일·위치·코드 블록과 같은 모양.
// 속성(rawData)을 바꾸면 onChanged로 저장.

/// 삭제 확인 대화상자 (기존 에디터와 같은 문구)
Future<bool> confirmBlockDelete(BuildContext context, EditorBlock block) async {
  final data = block.rawData;
  final (title, message) = switch (block.type) {
    localImageType => ('이미지 삭제', '이미지를 삭제할까요?'),
    localFileType => ('파일 삭제', '"${data['fileName'] ?? '파일'}" 을 삭제할까요?'),
    localLocationType => ('위치 삭제', '"${data['name'] ?? ''}" 위치를 삭제할까요?'),
    localCodeType => ('코드 블록 삭제', '코드 블록을 삭제할까요?'),
    _ => ('블록 삭제', '이 블록을 삭제할까요?'),
  };
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('삭제', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class ImageBlockView extends StatefulWidget {
  const ImageBlockView({
    super.key,
    required this.block,
    required this.onChanged,
    required this.onDelete,
    required this.onCut,
  });

  final EditorBlock block;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final VoidCallback onCut;

  @override
  State<ImageBlockView> createState() => _ImageBlockViewState();
}

class _ImageBlockViewState extends State<ImageBlockView> {
  late double _width;
  double? _aspectRatio;
  bool _isSelected = false;
  bool _isDragging = false;
  double _dragStartX = 0;
  double _dragStartY = 0;
  double _dragStartWidth = 0;

  Map<String, Object?> get _data => widget.block.rawData;

  String get _src => (_data['src'] ?? _data['url'] ?? '') as String;

  @override
  void initState() {
    super.initState();
    _width = ((_data['width'] as num?)?.toDouble() ?? 300).clamp(100.0, 800.0);
    _loadImageSize();
  }

  void _loadImageSize() {
    final file = File(_src);
    if (!file.existsSync()) return;
    Image.file(file).image
        .resolve(const ImageConfiguration())
        .addListener(
          ImageStreamListener((info, _) {
            if (!mounted) return;
            final w = info.image.width.toDouble();
            final h = info.image.height.toDouble();
            if (h > 0) setState(() => _aspectRatio = w / h);
          }),
        );
  }

  void _showMenu(BuildContext context) {
    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + box.size.height,
        offset.dx + box.size.width,
        offset.dy,
      ),
      items: <PopupMenuEntry<dynamic>>[
        PopupMenuItem(
          onTap: () => Clipboard.setData(ClipboardData(text: _src)),
          child: const Row(
            children: [
              Icon(Icons.copy, size: 16),
              SizedBox(width: 8),
              Text('복사'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: widget.onCut,
          child: const Row(
            children: [
              Icon(Icons.content_cut, size: 16),
              SizedBox(width: 8),
              Text('잘라내기'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          onTap: widget.onDelete,
          child: const Row(
            children: [
              Icon(Icons.delete, size: 16, color: Colors.red),
              SizedBox(width: 8),
              Text('삭제', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) {
        if (!_isDragging && _isSelected) setState(() => _isSelected = false);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: _width,
            height: _aspectRatio != null ? _width / _aspectRatio! : 200,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _isSelected = true),
                    onSecondaryTap: widget.onDelete,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(
                        File(_src),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Container(
                          color: Colors.grey[200],
                          child: const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isSelected) ...[
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: context.accent, width: 2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Builder(
                      builder: (menuContext) => GestureDetector(
                        onTap: () => _showMenu(menuContext),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.menu,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpLeftDownRight,
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) {
                          _isDragging = true;
                          _dragStartX = e.position.dx;
                          _dragStartY = e.position.dy;
                          _dragStartWidth = _width;
                        },
                        onPointerMove: (e) {
                          final delta =
                              (e.position.dx -
                                  _dragStartX +
                                  e.position.dy -
                                  _dragStartY) /
                              2;
                          setState(() {
                            _width = (_dragStartWidth + delta).clamp(
                              100.0,
                              800.0,
                            );
                          });
                        },
                        onPointerUp: (_) {
                          _isDragging = false;
                          _data['width'] = _width;
                          widget.onChanged();
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: context.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const Icon(
                            Icons.open_in_full,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FileBlockView extends StatelessWidget {
  const FileBlockView({super.key, required this.block, required this.onDelete});

  final EditorBlock block;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final data = block.rawData;
    final fileName = data['fileName'] as String? ?? '';
    return GestureDetector(
      onTap: () => Process.run('explorer', [data['src'] as String? ?? '']),
      onSecondaryTap: onDelete,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5FF),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFD0E0FF)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file, size: 16, color: context.accent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    fileName,
                    style: TextStyle(fontSize: 13, color: context.accent),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LocationBlockView extends ConsumerWidget {
  const LocationBlockView({
    super.key,
    required this.block,
    required this.onDelete,
  });

  final EditorBlock block;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = block.rawData;
    final name = data['name'] as String? ?? '';
    final lat = (data['lat'] as num?)?.toDouble() ?? 0;
    final lng = (data['lng'] as num?)?.toDouble() ?? 0;
    final imageUrl = VworldService.staticImageUrl(
      lat: lat,
      lng: lng,
      width: 300,
      height: 150,
    );

    return GestureDetector(
      onTap: () {
        ref
            .read(selectedLocationProvider.notifier)
            .select(SelectedLocation(name: name, position: LatLng(lat, lng)));
        ref.read(navigationProvider.notifier).navigateTo(3); // 지도 탭
      },
      onSecondaryTap: onDelete,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 300,
                height: 150,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 300,
                  height: 150,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.map, color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_pin,
                  color: Color(0xFFE53935),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.accent,
                    decoration: TextDecoration.underline,
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

class CodeBlockView extends StatefulWidget {
  const CodeBlockView({
    super.key,
    required this.block,
    required this.onChanged,
    required this.onDelete,
    this.startEditing = false,
  });

  final EditorBlock block;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final bool startEditing;

  @override
  State<CodeBlockView> createState() => _CodeBlockViewState();
}

class _CodeBlockViewState extends State<CodeBlockView> {
  late final TextEditingController _controller;
  late bool _isEditing = widget.startEditing;

  Map<String, Object?> get _data => widget.block.rawData;
  String get _code => _data['code'] as String? ?? '';
  String get _language => _data['language'] as String? ?? 'dart';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _code);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _detectAndSave() {
    final code = _controller.text;
    _data['code'] = code;
    _data['language'] = code.isEmpty
        ? 'text'
        : highlight.parse(code, autoDetection: true).language ?? 'text';
    widget.onChanged();
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: () => setState(() => _isEditing = true),
        onSecondaryTap: widget.onDelete,
        behavior: HitTestBehavior.translucent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isEditing ? context.accent : context.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.surfaceSoft,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      _language,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Spacer(),
                    if (_isEditing)
                      GestureDetector(
                        onTap: _detectAndSave,
                        child: const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              if (_isEditing)
                TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: null,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(12),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    _data['code'] = value;
                    widget.onChanged();
                  },
                )
              else if (_code.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    '코드를 입력하세요',
                    style: TextStyle(
                      color: Colors.grey,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                )
              else
                HighlightView(
                  _code,
                  language: _language,
                  theme: githubTheme,
                  padding: const EdgeInsets.all(12),
                  textStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
