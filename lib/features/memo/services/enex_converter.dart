import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

/// Evernote 내보내기 파일(.enex)의 메모 하나
class EnexNote {
  EnexNote({
    required this.title,
    required this.enml,
    required this.tags,
    required this.resources,
    this.created,
  });

  final String title;

  /// 본문 (ENML: Evernote용 XHTML)
  final String enml;
  final List<String> tags;
  final List<EnexResource> resources;
  final DateTime? created;
}

/// 메모에 들어 있는 그림·첨부파일
class EnexResource {
  EnexResource({required this.bytes, required this.mime, this.fileName});

  final Uint8List bytes;
  final String mime;
  final String? fileName;

  /// 본문의 `<en-media hash="...">` 가 가리키는 값
  String get hash => md5.convert(bytes).toString();

  bool get isImage => mime.startsWith('image/');
}

List<EnexNote> parseEnex(String content) {
  final document = XmlDocument.parse(content);
  return [
    for (final note in document.findAllElements('note'))
      EnexNote(
        title: note.getElement('title')?.innerText.trim() ?? '',
        enml: note.getElement('content')?.innerText ?? '',
        tags: [
          for (final tag in note.findElements('tag'))
            if (tag.innerText.trim().isNotEmpty) tag.innerText.trim(),
        ],
        created: _parseEnexDate(note.getElement('created')?.innerText),
        resources: [
          for (final resource in note.findElements('resource'))
            if (resource.getElement('data') case final data?)
              EnexResource(
                bytes: base64.decode(
                  data.innerText.replaceAll(RegExp(r'\s'), ''),
                ),
                mime:
                    resource.getElement('mime')?.innerText.trim() ??
                    'application/octet-stream',
                fileName: resource
                    .getElement('resource-attributes')
                    ?.getElement('file-name')
                    ?.innerText
                    .trim(),
              ),
        ],
      ),
  ];
}

/// 20231101T120000Z
DateTime? _parseEnexDate(String? value) {
  final m = RegExp(
    r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$',
  ).firstMatch(value?.trim() ?? '');
  if (m == null) return null;
  final parts = [for (var i = 1; i <= 6; i++) int.parse(m[i]!)];
  return DateTime.utc(
    parts[0],
    parts[1],
    parts[2],
    parts[3],
    parts[4],
    parts[5],
  ).toLocal();
}

/// ENML 본문 → 마크다운 (그 뒤 마크다운 변환기로 메모 블록을 만듦).
/// [mediaPath]: 그림·파일 hash → 저장한 로컬 경로.
String enmlToMarkdown(String enml, Map<String, String> mediaPath) {
  final XmlDocument document;
  try {
    document = XmlDocument.parse(
      enml.replaceFirst(RegExp(r'<!DOCTYPE[^>]*>'), ''),
      entityMapping: const XmlDefaultEntityMapping.html5(),
    );
  } catch (_) {
    // XML이 깨진 본문은 태그를 떼고 글자만
    return enml.replaceAll(RegExp(r'<[^>]+>'), '\n');
  }
  final writer = _MarkdownWriter(mediaPath);
  writer.block(document.rootElement);
  return writer.finish();
}

const _blockTags = {
  'en-note', 'div', 'p', 'section', 'article', 'header', 'footer', 'center', //
  'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'table', 'pre',
  'blockquote', 'hr', 'dl', 'dt', 'dd',
};

class _MarkdownWriter {
  _MarkdownWriter(this.mediaPath);

  final Map<String, String> mediaPath;
  final _lines = <String>[];
  final _line = StringBuffer();

  /// 다음 줄 앞에 붙일 기호 (목록·인용 등). 글자가 들어가야 줄이 생김.
  String _prefix = '';
  String _quote = '';

  void _flush() {
    final text = _line.toString().trim();
    if (text.isNotEmpty) {
      _lines.add('$_quote$_prefix$text');
      _prefix = '';
    }
    _line.clear();
  }

  String finish() {
    _flush();
    return _lines.join('\n');
  }

  void block(XmlNode node, {int listDepth = 0}) {
    for (final child in node.children) {
      if (child is XmlText || child is XmlCDATA) {
        _line.write(_text(child.value ?? ''));
        continue;
      }
      if (child is! XmlElement) continue;
      final name = child.localName.toLowerCase();
      switch (name) {
        case 'br':
          _flush();
        case 'hr':
          _flush();
          _lines.add('---');
        case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
          _flush();
          _prefix = '${'#' * int.parse(name.substring(1))} ';
          block(child, listDepth: listDepth);
          _flush();
          _prefix = '';
        case 'ul' || 'ol':
          _flush();
          _list(child, listDepth);
        case 'table':
          _flush();
          _table(child);
        case 'pre':
          _flush();
          _lines.add('```\n${child.innerText.trimRight()}\n```');
        case 'blockquote':
          _flush();
          final saved = _quote;
          _quote = '$_quote> ';
          block(child, listDepth: listDepth);
          _flush();
          _quote = saved;
        case 'en-todo':
          final checked = child.getAttribute('checked') == 'true';
          // 줄 맨 앞의 체크 상자만 할 일로 (목록 항목 안이면 그 들여쓰기 유지)
          if (_line.toString().trim().isEmpty) {
            final indent = RegExp(r'^\s*').firstMatch(_prefix)![0]!;
            _prefix = '$indent- [${checked ? 'x' : ' '}] ';
          }
        case 'en-media':
          _line.write(_media(child));
        case 'en-crypt':
          _line.write('[암호화된 내용]');
        default:
          if (_blockTags.contains(name)) {
            _flush();
            block(child, listDepth: listDepth);
            _flush();
          } else if (_hasBlock(child)) {
            block(child, listDepth: listDepth);
          } else {
            _line.write(_inline(child));
          }
      }
    }
  }

  void _list(XmlElement list, int depth) {
    final ordered = list.localName.toLowerCase() == 'ol';
    // 새 Evernote의 체크리스트: <ul style="--en-todo:true"><li style="--en-checked:true">
    final todo = (list.getAttribute('style') ?? '').contains('--en-todo:true');
    var number = 0;
    for (final item in list.childElements) {
      final name = item.localName.toLowerCase();
      if (name == 'ul' || name == 'ol') {
        _list(item, depth + 1);
        continue;
      }
      if (name != 'li') continue;
      number++;
      _flush();
      final checked = (item.getAttribute('style') ?? '').contains(
        '--en-checked:true',
      );
      _prefix =
          '${'    ' * depth}'
          '${todo
              ? '- [${checked ? 'x' : ' '}] '
              : ordered
              ? '$number. '
              : '- '}';
      block(item, listDepth: depth + 1);
      _flush();
    }
  }

  void _table(XmlElement table) {
    final rows = <List<String>>[];
    for (final row in table.findAllElements('tr')) {
      rows.add([
        for (final cell in row.childElements)
          if (cell.localName == 'td' || cell.localName == 'th') _cellText(cell),
      ]);
    }
    if (rows.isEmpty || rows.first.isEmpty) return;
    final columns = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    String line(List<String> cells) =>
        '| ${[for (var c = 0; c < columns; c++) c < cells.length ? cells[c] : ''].join(' | ')} |';
    _lines
      ..add(line(rows.first))
      ..add('| ${List.filled(columns, '---').join(' | ')} |')
      ..addAll(rows.skip(1).map(line));
  }

  String _cellText(XmlElement cell) {
    final writer = _MarkdownWriter(mediaPath)..block(cell);
    return writer
        .finish()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .join('<br>')
        .replaceAll('|', r'\|');
  }

  String _media(XmlElement media) {
    final path = mediaPath[media.getAttribute('hash')];
    if (path == null) return '';
    final target = '<$path>';
    return (media.getAttribute('type') ?? '').startsWith('image/')
        ? '![]($target)'
        : '[${_escape(path.split(RegExp(r'[\\/]')).last)}]($target)';
  }

  bool _hasBlock(XmlElement element) => element.descendantElements.any(
    (e) =>
        _blockTags.contains(e.localName.toLowerCase()) || e.localName == 'br',
  );

  String _inline(XmlElement element) {
    final inner = StringBuffer();
    for (final child in element.children) {
      if (child is XmlText || child is XmlCDATA) {
        inner.write(_text(child.value ?? ''));
      } else if (child is XmlElement) {
        inner.write(
          child.localName == 'en-media' ? _media(child) : _inline(child),
        );
      }
    }
    final text = inner.toString();
    if (text.trim().isEmpty) return text;
    // 앞뒤 공백은 서식 기호 바깥으로
    final lead = RegExp(r'^\s*').firstMatch(text)![0]!;
    final trail = RegExp(r'\s*$').firstMatch(text.substring(lead.length))![0]!;
    final core = text.substring(lead.length, text.length - trail.length);
    final style = element.getAttribute('style') ?? '';
    final wrapped = switch (element.localName.toLowerCase()) {
      'b' || 'strong' => '**$core**',
      'i' || 'em' => '*$core*',
      'u' => '<u>$core</u>',
      's' || 'strike' || 'del' => '~~$core~~',
      'code' => '`${core.replaceAll('\\', '')}`',
      'a' when element.getAttribute('href') != null =>
        '[$core](${_linkTarget(element.getAttribute('href')!)})',
      _ when style.contains(RegExp(r'font-weight:\s*(bold|[6-9]00)')) =>
        '**$core**',
      _ when style.contains('line-through') => '~~$core~~',
      _ => core,
    };
    return '$lead$wrapped$trail';
  }

  static String _linkTarget(String href) =>
      href.contains(RegExp(r'[\s()]')) ? '<$href>' : href;

  /// 글자: 줄바꿈은 공백으로, 마크다운 기호는 이스케이프
  static String _text(String value) =>
      _escape(value.replaceAll(RegExp(r'[\r\n\t]+'), ' ').replaceAll(' ', ' '));

  static String _escape(String text) =>
      text.replaceAllMapped(RegExp(r'[\\`*_\[\]]'), (m) => '\\${m[0]}');
}
