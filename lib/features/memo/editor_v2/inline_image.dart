import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// 줄 안에 들어가는 그림·첨부파일. 글자 하나(object replacement character)로
/// 저장하고 그 글자의 서식에 경로 등을 담음 → 바로 옆에 글을 쓸 수 있음.
const inlineImageChar = '￼';
const imageMarkKey = 'image';
const imageWidthKey = 'image_width';
const fileMarkKey = 'file';
const fileNameKey = 'file_name';

/// 줄 안의 그림·파일 서식 키 (옆에 친 글자에는 이어지지 않음)
const inlineObjectKeys = [
  imageMarkKey,
  imageWidthKey,
  fileMarkKey,
  fileNameKey,
];

const defaultImageWidth = 300.0;

/// 다른 앱에 붙여넣거나 글자만 볼 때 그림·파일 자리 표시는 뺌
String stripInlineImages(String text) => text.replaceAll(inlineImageChar, '');

/// 그림 글자의 서식
Map<String, Object?> inlineImageMarks(
  String src, {
  double width = defaultImageWidth,
}) => {imageMarkKey: src, imageWidthKey: width};

/// 첨부파일 글자의 서식
Map<String, Object?> inlineFileMarks(String src, String fileName) => {
  fileMarkKey: src,
  fileNameKey: fileName,
};

/// 줄 안의 그림·파일이 골라졌는지: 입력창 선택 범위 안에 있고 그 입력창에 포커스가
/// 있거나, 여러 줄 선택에 들어 있을 때. 포커스가 바뀌면 다시 그림.
mixin _InlineSelection<T extends StatefulWidget> on State<T> {
  FocusNode get focusNode;
  bool get inSelection;
  bool get highlighted;

  bool get selected => highlighted || (inSelection && focusNode.hasFocus);

  @override
  void initState() {
    super.initState();
    focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }
}

typedef _MenuEntry = (String value, IconData icon, String label);

Future<void> _showObjectMenu(
  BuildContext context,
  Offset position,
  List<_MenuEntry> entries,
  void Function(String value) onSelected,
) async {
  final action = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx,
      position.dy,
    ),
    items: [
      for (final (value, icon, label) in entries)
        PopupMenuItem(
          value: value,
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: value == 'delete' ? Colors.red : null,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: value == 'delete'
                    ? const TextStyle(color: Colors.red)
                    : null,
              ),
            ],
          ),
        ),
    ],
  );
  if (action != null) onSelected(action);
}

class InlineImage extends StatefulWidget {
  const InlineImage({
    super.key,
    required this.src,
    required this.width,
    required this.focusNode,
    required this.inSelection,
    required this.highlighted,
    required this.onSelect,
    required this.onResize,
    required this.onDelete,
  });

  final String src;
  final double width;

  /// 이 그림이 들어 있는 입력창의 포커스
  final FocusNode focusNode;
  final bool inSelection;
  final bool highlighted;

  /// 그림을 누르면 그림을 고름 (그림 옆 빈 곳을 누르면 입력창이 커서를 놓음)
  final VoidCallback onSelect;
  final ValueChanged<double> onResize;
  final VoidCallback onDelete;

  /// 그림 비율 (다시 그릴 때 높이가 0으로 튀지 않게 기억)
  static final _aspectRatios = <String, double>{};

  /// 크기 조절 손잡이를 끄는 중 (에디터가 여러 줄 선택 드래그를 하지 않도록)
  static bool resizing = false;

  @override
  State<InlineImage> createState() => _InlineImageState();
}

class _InlineImageState extends State<InlineImage>
    with _InlineSelection<InlineImage> {
  late double _width = widget.width;
  bool _hovering = false;
  bool _resizing = false;
  double _dragStartX = 0;
  double _dragStartY = 0;
  double _dragStartWidth = 0;

  @override
  FocusNode get focusNode => widget.focusNode;
  @override
  bool get inSelection => widget.inSelection;
  @override
  bool get highlighted => widget.highlighted;

  // 비율을 알아내려고 붙인 이미지 스트림 (dispose에서 뗌)
  ImageStream? _ratioStream;
  ImageStreamListener? _ratioListener;
  bool _addingListener = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAspectRatio();
  }

  @override
  void didUpdateWidget(InlineImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_resizing) _width = widget.width;
    if (oldWidget.src != widget.src) {
      _removeRatioListener();
      _loadAspectRatio();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _removeRatioListener();
    super.dispose();
  }

  /// 보이는 너비 × 화면 배율에 맞춰 줄여서 읽음.
  /// 크기 조절 중 매번 다시 읽지 않게 256px 단위로 올림.
  ImageProvider _provider(double width) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final cacheWidth = max(1, (width * dpr / 256).ceil()) * 256;
    return ResizeImage(FileImage(File(widget.src)), width: cacheWidth);
  }

  void _loadAspectRatio() {
    if (_ratioStream != null) return;
    if (InlineImage._aspectRatios.containsKey(widget.src)) return;
    final src = widget.src;
    // 화면에 그릴 이미지와 같은 것을 읽어 한 번만 디코딩
    final stream = _provider(
      _width,
    ).resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (info, _) {
        final h = info.image.height;
        if (h > 0) InlineImage._aspectRatios[src] = info.image.width / h;
        _removeRatioListener();
        // 붙이는 중 바로 불리면(이미 읽어 둔 그림) 곧 그려지므로 setState 생략
        if (mounted && !_addingListener) setState(() {});
      },
      // 파일이 없으면 errorBuilder가 표시
      onError: (_, _) => _removeRatioListener(),
    );
    _ratioStream = stream;
    _ratioListener = listener;
    _addingListener = true;
    stream.addListener(listener);
    _addingListener = false;
  }

  void _removeRatioListener() {
    final listener = _ratioListener;
    if (listener != null) _ratioStream?.removeListener(listener);
    _ratioStream = null;
    _ratioListener = null;
  }

  void _showMenu(Offset position) => _showObjectMenu(
    context,
    position,
    const [('copy', Icons.copy, '경로 복사'), ('delete', Icons.delete, '삭제')],
    (value) {
      if (value == 'copy') Clipboard.setData(ClipboardData(text: widget.src));
      if (value == 'delete') widget.onDelete();
    },
  );

  @override
  Widget build(BuildContext context) {
    // 줄보다 넓으면 줄 너비로 줄어듦 (SizedBox 너비는 줄 너비를 넘지 못함)
    final ratio = InlineImage._aspectRatios[widget.src] ?? 1 / 0.6;
    final showFrame = selected || _hovering || _resizing;
    final showHandle = selected || _resizing;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        onSecondaryTapUp: (details) {
          widget.onSelect();
          _showMenu(details.globalPosition);
        },
        child: SizedBox(
          width: _width,
          child: AspectRatio(
            aspectRatio: ratio,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image(
                      image: _provider(_width),
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => Container(
                        color: context.surfaceSoft,
                        child: const Center(child: Icon(Icons.broken_image)),
                      ),
                    ),
                  ),
                ),
                if (showFrame)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: selected
                              ? context.accent.withValues(alpha: 0.12)
                              : null,
                          border: Border.all(color: context.accent, width: 2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                if (showHandle)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpLeftDownRight,
                      // 누르자마자 이 손잡이가 끌기를 차지 (입력창의 글자 선택 드래그 막기)
                      child: RawGestureDetector(
                        gestures: {
                          EagerGestureRecognizer:
                              GestureRecognizerFactoryWithHandlers<
                                EagerGestureRecognizer
                              >(EagerGestureRecognizer.new, (_) {}),
                        },
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (e) {
                            InlineImage.resizing = true;
                            _resizing = true;
                            _dragStartX = e.position.dx;
                            _dragStartY = e.position.dy;
                            _dragStartWidth =
                                (context.findRenderObject() as RenderBox?)
                                    ?.size
                                    .width ??
                                _width;
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
                                40.0,
                                1200.0,
                              );
                            });
                          },
                          onPointerUp: (_) {
                            InlineImage.resizing = false;
                            setState(() => _resizing = false);
                            widget.onResize(_width);
                          },
                          onPointerCancel: (_) {
                            InlineImage.resizing = false;
                            setState(() => _resizing = false);
                          },
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: context.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const Icon(
                              Icons.open_in_full,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
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

/// 줄 안의 첨부파일. 누르면 파일을 엶 (옆 빈 곳을 누르면 커서).
class InlineFile extends StatefulWidget {
  const InlineFile({
    super.key,
    required this.src,
    required this.fileName,
    required this.focusNode,
    required this.inSelection,
    required this.highlighted,
    required this.onSelect,
    required this.onDelete,
  });

  final String src;
  final String fileName;
  final FocusNode focusNode;
  final bool inSelection;
  final bool highlighted;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  State<InlineFile> createState() => _InlineFileState();
}

class _InlineFileState extends State<InlineFile>
    with _InlineSelection<InlineFile> {
  @override
  FocusNode get focusNode => widget.focusNode;
  @override
  bool get inSelection => widget.inSelection;
  @override
  bool get highlighted => widget.highlighted;

  @override
  void didUpdateWidget(InlineFile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
  }

  void _open() => Process.run('explorer', [widget.src]);

  void _showMenu(Offset position) => _showObjectMenu(
    context,
    position,
    const [
      ('open', Icons.open_in_new, '열기'),
      ('copy', Icons.copy, '경로 복사'),
      ('delete', Icons.delete, '삭제'),
    ],
    (value) {
      if (value == 'open') _open();
      if (value == 'copy') Clipboard.setData(ClipboardData(text: widget.src));
      if (value == 'delete') widget.onDelete();
    },
  );

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return Tooltip(
      message: '클릭하여 열기',
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _open,
          onSecondaryTapUp: (details) => _showMenu(details.globalPosition),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.2)
                  : accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected ? accent : accent.withValues(alpha: 0.3),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.insert_drive_file, size: 15, color: accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.fileName,
                    style: TextStyle(fontSize: 13, color: accent),
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
