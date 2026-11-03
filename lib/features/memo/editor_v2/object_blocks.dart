import 'package:taskmanager/core/theme/app_colors.dart';

import 'package:flutter/material.dart';
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
    localTableType => ('표 삭제', '표를 삭제할까요?'),
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

/// 한 번 누르면 고르기만 하므로, 여는 방법을 마우스를 올리면 알려줌
Widget _openHint(Widget child) => Tooltip(
  message: '더블클릭하여 열기',
  waitDuration: const Duration(milliseconds: 600),
  child: child,
);

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

    // 한 번 누르면 고르고, 두 번 누르면 지도에서 보기
    return GestureDetector(
      onDoubleTap: () {
        ref
            .read(selectedLocationProvider.notifier)
            .select(SelectedLocation(name: name, position: LatLng(lat, lng)));
        ref.read(navigationProvider.notifier).navigateTo(3); // 지도 탭
      },
      onSecondaryTap: onDelete,
      child: _openHint(
        Padding(
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
