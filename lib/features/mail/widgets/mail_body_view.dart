import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';

import '../models/mail_message.dart';
import '../services/mail_check_service.dart';

/// 본문 파일을 웹뷰에 보여 줄 때 쓰는 가상 주소
const _host = 'mail.taskmanager';

/// 메일 본문을 웹뷰에 보여 줄 페이지 (원래 인코딩 그대로의 바이트).
///
/// 맨 앞에 charset을 적어 euc-kr 등도 웹뷰가 알아서 글자로 바꾸게 하고,
/// 메일 안의 스크립트·폼은 막음 (그림·글꼴·서식은 허용).
Uint8List mailPageBytes(MailBody body) {
  final charset = body.charset.replaceAll(RegExp(r'[^A-Za-z0-9_.:-]'), '');
  final out = BytesBuilder(copy: false)
    ..add(
      ascii.encode(
        '<!doctype html><html><head>'
        '<meta charset="${charset.isEmpty ? 'utf-8' : charset}">'
        '<meta http-equiv="Content-Security-Policy" content="'
        "default-src * data: blob: 'unsafe-inline'; script-src 'none'; "
        "object-src 'none'; form-action 'none'\">"
        '<style>'
        'body{margin:0;padding:16px 36px 32px;'
        'font-family:"Segoe UI","Malgun Gothic",sans-serif;font-size:14px;'
        'line-height:1.6;color:#222;background:#fff;overflow-wrap:anywhere}'
        'img{max-width:100%;height:auto}'
        'pre.plain{white-space:pre-wrap;font-family:inherit;margin:0}'
        '</style></head><body>',
      ),
    );
  if (body.isHtml) {
    out.add(body.bytes);
  } else {
    // 일반 글자: <, >, & 만 바꿈 (euc-kr·utf-8은 이 바이트가 글자 중간에 안 나옴)
    out.add(ascii.encode('<pre class="plain">'));
    final escaped = BytesBuilder(copy: false);
    for (final b in body.bytes) {
      switch (b) {
        case 0x3C:
          escaped.add(ascii.encode('&lt;'));
        case 0x3E:
          escaped.add(ascii.encode('&gt;'));
        case 0x26:
          escaped.add(ascii.encode('&amp;'));
        default:
          escaped.addByte(b);
      }
    }
    out
      ..add(escaped.takeBytes())
      ..add(ascii.encode('</pre>'));
  }
  out.add(ascii.encode('</body></html>'));
  return out.takeBytes();
}

/// 메일 안의 링크를 누르면 앱 웹뷰가 아니라 기본 브라우저로 열도록 앱에 알림
const _linkScript = '''
document.addEventListener('click', function (e) {
  var a = e.target && e.target.closest ? e.target.closest('a[href]') : null;
  if (!a) return;
  e.preventDefault();
  window.chrome.webview.postMessage(a.href);
}, true);
''';

/// 메일 본문 (WebView2). 웹뷰를 쓸 수 없거나 본문을 못 받으면 요약 글자를 보여 줌.
class MailBodyView extends ConsumerStatefulWidget {
  const MailBodyView({super.key, required this.mail});

  final MailMessage mail;

  @override
  ConsumerState<MailBodyView> createState() => _MailBodyViewState();
}

enum _Status { loading, shown, fallback }

class _MailBodyViewState extends ConsumerState<MailBodyView> {
  final _controller = WebviewController();
  late final Future<bool> _webviewReady = _initWebview();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Directory? _folder;
  var _status = _Status.loading;
  var _request = 0;
  var _disposed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MailBodyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mail.id != widget.mail.id) _load();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subscriptions) {
      s.cancel();
    }
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _initWebview() async {
    try {
      final folder = Directory(
        p.join(Directory.systemTemp.path, 'taskmanager_mail'),
      );
      // 전에 본 메일 파일은 지우고 시작
      if (await folder.exists()) await folder.delete(recursive: true);
      await folder.create(recursive: true);
      _folder = folder;

      await _controller.initialize();
      if (_disposed) return false;
      await _controller.setBackgroundColor(Colors.white);
      await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      await _controller.addVirtualHostNameMapping(
        _host,
        folder.path,
        WebviewHostResourceAccessKind.allow,
      );
      await _controller.addScriptToExecuteOnDocumentCreated(_linkScript);
      _subscriptions
        ..add(_controller.webMessage.listen((url) => _openExternal('$url')))
        // 스크립트가 막혀 링크가 웹뷰 안에서 열리면 되돌리고 브라우저로
        ..add(
          _controller.url.listen((url) {
            final uri = Uri.tryParse(url);
            if (uri == null || uri.host == _host || uri.scheme == 'about') {
              return;
            }
            _openExternal(url);
            _controller.goBack();
          }),
        );
      return true;
    } catch (_) {
      return false;
    }
  }

  void _openExternal(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !const {'http', 'https', 'mailto'}.contains(uri.scheme)) {
      return;
    }
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _load() async {
    final request = ++_request;
    final mail = widget.mail;
    if (_status != _Status.loading) setState(() => _status = _Status.loading);
    final results = await Future.wait<Object?>([
      ref.read(mailCheckServiceProvider).fetchBody(mail.id),
      _webviewReady,
    ]);
    if (!mounted || request != _request) return;
    final body = results[0] as MailBody?;
    final ready = results[1] as bool;
    final folder = _folder;
    if (body == null || !ready || folder == null) {
      setState(() => _status = _Status.fallback);
      return;
    }
    try {
      final name = '${mail.id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}.html';
      await File(p.join(folder.path, name)).writeAsBytes(mailPageBytes(body));
      await _controller.loadUrl('https://$_host/$name');
      if (mounted && request == _request) {
        setState(() => _status = _Status.shown);
      }
    } catch (_) {
      if (mounted && request == _request) {
        setState(() => _status = _Status.fallback);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (_status == _Status.fallback) {
      final preview = widget.mail.preview;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(36, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '본문을 불러오지 못해 요약만 보여 줍니다',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const SizedBox(height: 8),
            SelectableText(
              preview.isEmpty ? '(내용 없음)' : preview,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      );
    }
    return Stack(
      children: [
        // 웹뷰는 한 번 만든 것을 계속 씀 (메일을 바꿔도 다시 만들지 않음)
        Positioned.fill(
          child: FutureBuilder<bool>(
            future: _webviewReady,
            builder: (context, snapshot) => snapshot.data == true
                ? Webview(_controller)
                : const SizedBox.shrink(),
          ),
        ),
        if (_status == _Status.loading)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
