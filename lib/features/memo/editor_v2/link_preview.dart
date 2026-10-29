import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';

import '../../../core/theme/app_colors.dart';
import 'styled_text_controller.dart';

final _youtubePattern = RegExp(
  r'(?:youtube\.com/(?:watch\?(?:[^\s#]*&)?v=|shorts/|embed/|live/)|youtu\.be/)([\w-]{11})',
);

/// 줄에 들어 있는 첫 유튜브 영상 ID (링크 주소 우선, 없으면 글자에서)
String? youtubeIdOf(StyledTextController controller) {
  for (final mark in controller.marks) {
    final href = mark['href'];
    if (href is String) {
      final match = _youtubePattern.firstMatch(href);
      if (match != null) return match.group(1);
    }
  }
  return _youtubePattern.firstMatch(controller.text)?.group(1);
}

/// 웹 주소를 기본 브라우저로 열기
Future<void> openLink(String href) async {
  final uri = Uri.tryParse(href.contains('://') ? href : 'https://$href');
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _watchUrl(String id) => 'https://www.youtube.com/watch?v=$id';

/// 주소에서 유튜브 영상 ID
String? youtubeIdOfUrl(String url) => _youtubePattern.firstMatch(url)?.group(1);

String youtubeThumbnailUrl(String id) =>
    'https://i.ytimg.com/vi/$id/hqdefault.jpg';

// 영상 제목 (같은 영상은 한 번만 가져옴)
final _titles = <String, Future<String?>>{};

Future<String?> youtubeTitle(String id) =>
    _titles.putIfAbsent(id, () => _fetchTitle(id));

Future<String?> _fetchTitle(String id) async {
  try {
    final response = await http
        .get(
          Uri.https('www.youtube.com', '/oembed', {
            'url': _watchUrl(id),
            'format': 'json',
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    return (json as Map<String, Object?>)['title'] as String?;
  } catch (_) {
    return null;
  }
}

/// 유튜브 링크가 있는 줄 아래에 붙는 미리보기 (썸네일 + 제목, 누르면 그 자리에서 재생).
/// 저장되는 내용은 바뀌지 않음 (줄의 링크에서 매번 만들어 보여줌).
class YoutubePreview extends StatefulWidget {
  const YoutubePreview({super.key, required this.controller});

  final StyledTextController controller;

  @override
  State<YoutubePreview> createState() => _YoutubePreviewState();
}

class _YoutubePreviewState extends State<YoutubePreview> {
  String? _id;

  /// 카드 자리에서 재생 중
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _id = youtubeIdOf(widget.controller);
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(YoutubePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _onChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  // 글자를 칠 때마다 불리므로, 영상이 바뀔 때만 다시 그림
  void _onChanged() {
    final id = youtubeIdOf(widget.controller);
    if (id != _id) {
      setState(() {
        _id = id;
        _playing = false;
      });
    }
  }

  /// WebView2가 없는 PC면 브라우저로
  Future<void> _play(String id) async {
    String? version;
    try {
      version = await WebviewController.getWebViewVersion();
    } catch (_) {}
    if (!mounted) return;
    if (version != null) {
      setState(() => _playing = true);
    } else {
      openLink(_watchUrl(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    if (id == null) return const SizedBox.shrink();
    final title = youtubeTitle(id);
    Widget iconButton(IconData icon, String tooltip, VoidCallback onPressed) =>
        IconButton(
          icon: Icon(icon, size: 18, color: Colors.grey[600]),
          tooltip: tooltip,
          visualDensity: VisualDensity.compact,
          onPressed: onPressed,
        );
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            color: context.popupSurface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: context.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _playing
                      ? _YoutubePlayer(
                          id: id,
                          onFailed: () {
                            if (mounted) setState(() => _playing = false);
                            openLink(_watchUrl(id));
                          },
                        )
                      : InkWell(
                          onTap: () => _play(id),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                youtubeThumbnailUrl(id),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    ColoredBox(color: context.lineSubtle),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: FutureBuilder<String?>(
                          future: title,
                          builder: (context, snapshot) => Text(
                            snapshot.data ?? 'YouTube',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      iconButton(
                        Icons.open_in_new,
                        '브라우저에서 열기',
                        () => openLink(_watchUrl(id)),
                      ),
                      if (_playing)
                        iconButton(
                          Icons.close,
                          '재생 닫기',
                          () => setState(() => _playing = false),
                        ),
                    ],
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

/// 유튜브 플레이어 (WebView2).
///
/// 유튜브는 주소가 없는 페이지(직접 만든 HTML)에 넣은 플레이어(오류 153)와
/// 유튜브 자신의 페이지에 넣은 플레이어(오류 152)의 재생을 막음. 그래서 아주 작은
/// 일반 웹페이지(example.com, 인터넷 표준 기관이 예시용으로 운영)를 연 뒤
/// 그 안에 플레이어를 넣음. 퍼가기가 막힌 영상 등 재생할 수 없으면 브라우저로.
class _YoutubePlayer extends StatefulWidget {
  const _YoutubePlayer({required this.id, required this.onFailed});

  final String id;
  final VoidCallback onFailed;

  @override
  State<_YoutubePlayer> createState() => _YoutubePlayerState();
}

class _YoutubePlayerState extends State<_YoutubePlayer> {
  final _controller = WebviewController();
  StreamSubscription<LoadingState>? _loading;
  Timer? _watch;
  bool _ready = false;
  bool _injected = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await _controller.initialize();
      await _controller.setBackgroundColor(Colors.black);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      _loading = _controller.loadingState.listen((state) {
        if (state == LoadingState.navigationCompleted && !_injected) {
          _injected = true;
          _controller.executeScript(youtubePlayerScript(widget.id));
          _watchPlayer();
        }
      });
      await _controller.loadUrl('https://example.com/');
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      _fail();
    }
  }

  /// 플레이어가 보내는 상태를 잠시 확인: 오류면 브라우저로, 재생이 시작되면 그만
  void _watchPlayer() {
    var checks = 0;
    _watch = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (++checks > 20) return timer.cancel();
      try {
        final events = '${await _controller.executeScript(_eventsScript)}';
        if (events.contains('ERR')) {
          timer.cancel();
          _fail();
        } else if (events.contains('S1')) {
          timer.cancel();
        }
      } catch (_) {}
    });
  }

  void _fail() {
    if (_failed || !mounted) return;
    _failed = true;
    widget.onFailed();
  }

  @override
  void dispose() {
    _watch?.cancel();
    _loading?.cancel();
    _controller.dispose(); // 화면에서 사라지면 재생도 멈춤
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      );
    }
    return Webview(_controller);
  }
}

/// 플레이어가 보낸 상태 기록 ('ERR코드', 'S상태' — S1 = 재생 중)
const _eventsScript = "(window.__yt || []).join(',')";

/// 열린 페이지를 플레이어 하나만 있는 화면으로 바꾸고, 플레이어 상태를 기록
String youtubePlayerScript(String id) {
  final src =
      'https://www.youtube.com/embed/$id'
      '?autoplay=1&rel=0&playsinline=1&enablejsapi=1';
  return '''
window.__yt = [];
window.addEventListener('message', function (e) {
  try {
    var d = typeof e.data === 'string' ? JSON.parse(e.data) : e.data;
    if (d.event === 'onError') window.__yt.push('ERR' + d.info);
    if (d.info && d.info.playerState !== undefined) {
      window.__yt.push('S' + d.info.playerState);
    }
  } catch (x) {}
});
document.documentElement.innerHTML =
  '<head><meta name="viewport" content="width=device-width"></head>' +
  '<body style="margin:0;background:#000;overflow:hidden">' +
  '<iframe id="player" src="$src" style="border:0;width:100vw;height:100vh" ' +
  'allow="autoplay; encrypted-media; picture-in-picture; fullscreen" ' +
  'allowfullscreen></iframe></body>';
var player = document.getElementById('player');
player.addEventListener('load', function () {
  player.contentWindow.postMessage(
    JSON.stringify({event: 'listening', id: 1, channel: 'widget'}), '*');
});
''';
}
