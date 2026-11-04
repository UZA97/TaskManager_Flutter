import 'dart:convert';

import '../editor_v2/editor_block.dart';
import '../editor_v2/inline_image.dart';
import '../editor_v2/table_block.dart';

// ───────────── 메모 → 마크다운

/// 블록 목록을 마크다운으로. [linkOf]로 그림·첨부파일 경로를 바꿀 수 있음
/// (내보낼 폴더 기준 상대 경로 등).
String blocksToMarkdown(
  List<EditorBlock> blocks, {
  String Function(String src)? linkOf,
}) {
  final link = linkOf ?? (src) => src;
  final out = StringBuffer();
  var previousWasList = false;
  final numbers = <int, int>{};

  void emit(String text, {bool list = false}) {
    if (out.isNotEmpty) out.write(list && previousWasList ? '\n' : '\n\n');
    out.write(text);
    previousWasList = list;
  }

  for (final block in blocks) {
    // 번호 목록은 같은 깊이에서 이어지는 동안 번호를 셈
    if (block.type == 'numbered_list') {
      numbers[block.depth] = (numbers[block.depth] ?? 0) + 1;
    }
    numbers.removeWhere(
      (depth, _) =>
          depth > block.depth ||
          (depth == block.depth && block.type != 'numbered_list'),
    );

    final indent = '    ' * block.depth;
    if (block.raw != null) {
      final data = block.rawData;
      switch (block.type) {
        case dividerType:
          emit('---');
        case localCodeType:
          final language = data['language'] as String? ?? '';
          emit('```$language\n${data['code'] as String? ?? ''}\n```');
        case localTableType:
          emit(_tableToMarkdown(tableRowsOf(block)));
        case localLocationType:
          final name = data['name'] as String? ?? '위치';
          emit(
            '[📍 ${_escape(name)}](https://www.google.com/maps?q='
            '${data['lat']},${data['lng']})',
          );
      }
      continue;
    }

    final text = _inlineToMarkdown(block.controller.toDelta(), link);
    switch (block.type) {
      case 'heading':
        emit('${'#' * block.level.clamp(1, 6)} $text');
      case 'todo_list':
        emit('$indent- [${block.checked ? 'x' : ' '}] $text', list: true);
      case 'bulleted_list':
        emit('$indent- $text', list: true);
      case 'numbered_list':
        emit('$indent${numbers[block.depth] ?? 1}. $text', list: true);
      case 'quote':
        emit('> $text');
      case collapsibleSectionType:
        emit('**$text**');
      default:
        if (text.trim().isEmpty) {
          previousWasList = false; // 빈 줄은 목록을 끊음
          continue;
        }
        // 목록 아래 들여쓴 글은 목록 항목에 이어지게
        emit(previousWasList && block.depth > 0 ? '$indent$text' : text);
    }
  }
  return '$out\n';
}

String _tableToMarkdown(List<List<String>> rows) {
  String cell(String text) =>
      _escape(text).replaceAll('|', r'\|').replaceAll('\n', '<br>');
  String row(List<String> cells) => '| ${cells.map(cell).join(' | ')} |';
  return [
    row(rows.first),
    '| ${List.filled(rows.first.length, '---').join(' | ')} |',
    for (final r in rows.skip(1)) row(r),
  ].join('\n');
}

String _escape(String text) =>
    text.replaceAllMapped(RegExp(r'[\\`*_\[\]]'), (m) => '\\${m[0]}');

/// 공백이 있으면 <> 로 감싸야 마크다운 링크가 깨지지 않음
String _target(String url) => url.contains(RegExp(r'[\s()]')) ? '<$url>' : url;

String _inlineToMarkdown(
  List<Map<String, Object?>> delta,
  String Function(String) link,
) {
  final out = StringBuffer();
  for (final op in delta) {
    final insert = op['insert'] as String;
    final marks = (op['attributes'] as Map?) ?? const {};
    final image = marks[imageMarkKey] as String?;
    final file = marks[fileMarkKey] as String?;
    if (image != null || file != null) {
      for (var i = 0; i < insert.length; i++) {
        out.write(
          image != null
              ? '![](${_target(link(image))})'
              : '[${_escape(marks[fileNameKey] as String? ?? '첨부파일')}]'
                    '(${_target(link(file!))})',
        );
      }
      continue;
    }
    final code = marks['code'] == true;
    var text = code ? insert : _escape(insert);
    // 앞뒤 공백은 서식 기호 바깥으로 (`** 글**`은 굵게가 안 됨)
    final lead = RegExp(r'^\s*').firstMatch(text)![0]!;
    final trail = RegExp(r'\s*$').firstMatch(text.substring(lead.length))![0]!;
    var core = text.substring(lead.length, text.length - trail.length);
    if (core.isNotEmpty) {
      if (code) core = '`$core`';
      if (marks['bold'] == true) core = '**$core**';
      if (marks['italic'] == true) core = '*$core*';
      if (marks['strikethrough'] == true) core = '~~$core~~';
      if (marks['underline'] == true) core = '<u>$core</u>';
      final href = marks['href'] as String?;
      if (href != null) core = '[$core](${_target(href)})';
    }
    text = '$lead$core$trail';
    out.write(text.replaceAll('\n', '  \n'));
  }
  return out.toString();
}

// ───────────── 마크다운 → 메모

/// 마크다운 앞의 YAML 머리말 (title, tags, created만 읽음)
class MarkdownFrontMatter {
  MarkdownFrontMatter({this.title, this.tags = const [], this.created});
  final String? title;
  final List<String> tags;
  final DateTime? created;
}

/// 머리말을 떼어낸 본문과 머리말
(String, MarkdownFrontMatter) splitFrontMatter(String markdown) {
  final text = markdown.replaceAll('\r\n', '\n').replaceFirst('﻿', '');
  final match = RegExp(r'^---\n([\s\S]*?)\n---[ \t]*(\n|$)').firstMatch(text);
  if (match == null) return (text, MarkdownFrontMatter());
  String? title;
  DateTime? created;
  var tags = <String>[];
  String unquote(String s) {
    final value = s.trim();
    if (value.startsWith('"')) {
      try {
        return jsonDecode(value) as String;
      } catch (_) {}
    }
    return value.replaceAll(RegExp(r'''^["']|["']$'''), '');
  }

  final lines = match[1]!.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final title_ = RegExp(r'^title:\s*(.*)$').firstMatch(line);
    if (title_ != null) title = unquote(title_[1]!);
    final date = RegExp(r'^(?:created|date):\s*(.*)$').firstMatch(line);
    if (date != null) created = DateTime.tryParse(unquote(date[1]!));
    final tagLine = RegExp(r'^tags:\s*(.*)$').firstMatch(line);
    if (tagLine == null) continue;
    final inline = tagLine[1]!.trim();
    if (inline.isNotEmpty) {
      // tags: [a, b] 또는 tags: a, b
      tags = inline
          .replaceAll(RegExp(r'^\[|\]$'), '')
          .split(',')
          .map(unquote)
          .where((t) => t.isNotEmpty)
          .toList();
    } else {
      // tags:\n  - a\n  - b
      while (i + 1 < lines.length &&
          RegExp(r'^\s*-\s+').hasMatch(lines[i + 1])) {
        i++;
        final tag = unquote(lines[i].replaceFirst(RegExp(r'^\s*-\s+'), ''));
        if (tag.isNotEmpty) tags.add(tag);
      }
    }
  }
  return (
    text.substring(match.end),
    MarkdownFrontMatter(
      title: title,
      tags: [for (final t in tags) t.replaceFirst('#', '')],
      created: created,
    ),
  );
}

/// 마크다운 → 블록. 줄 하나가 블록 하나 (메모 앱처럼 줄바꿈을 그대로 살림).
/// [attachmentOf]: 그림·파일 링크 주소 → 메모에 넣을 로컬 경로 (없으면 일반 링크로).
List<EditorBlock> markdownToBlocks(
  String markdown, {
  String? Function(String target)? attachmentOf,
}) {
  final lines = markdown.replaceAll('\r\n', '\n').split('\n');
  final blocks = <EditorBlock>[];
  final listIndents = <int>[]; // 지금 열려 있는 목록들의 들여쓰기

  List<Map<String, Object?>> inline(String text) =>
      _parseInline(text, const {}, attachmentOf);

  int indentOf(String line) {
    var width = 0;
    for (final ch in line.split('')) {
      if (ch == ' ') {
        width++;
      } else if (ch == '\t') {
        width += 4;
      } else {
        break;
      }
    }
    return width;
  }

  int listDepth(int indent) {
    while (listIndents.isNotEmpty && indent < listIndents.last) {
      listIndents.removeLast();
    }
    if (listIndents.isEmpty || indent > listIndents.last) {
      listIndents.add(indent);
    }
    return listIndents.length - 1;
  }

  final fence = RegExp(r'^\s*(```+|~~~+)\s*([\w+#.-]*)');
  final heading = RegExp(r'^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$');
  final rule = RegExp(r'^\s{0,3}([-*_])(\s*\1){2,}\s*$');
  final quote = RegExp(r'^\s{0,3}>\s?(.*)$');
  final listItem = RegExp(r'^(\s*)([-*+]|\d+[.)])\s+(?:\[([ xX])\]\s+)?(.*)$');
  final tableSeparator = RegExp(r'^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$');

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;

    final fenceMatch = fence.firstMatch(line);
    if (fenceMatch != null) {
      final marker = fenceMatch[1]!;
      final code = <String>[];
      while (++i < lines.length && !lines[i].trim().startsWith(marker)) {
        code.add(lines[i]);
      }
      blocks.add(
        EditorBlock.code(
          code: code.join('\n'),
          language: fenceMatch[2]!.isEmpty ? 'plaintext' : fenceMatch[2]!,
        ),
      );
      listIndents.clear();
      continue;
    }

    if (line.contains('|') &&
        i + 1 < lines.length &&
        lines[i + 1].contains('-') &&
        tableSeparator.hasMatch(lines[i + 1])) {
      final rows = [_tableCells(line)];
      i++;
      while (i + 1 < lines.length &&
          lines[i + 1].contains('|') &&
          lines[i + 1].trim().isNotEmpty) {
        rows.add(_tableCells(lines[++i]));
      }
      final columns = rows.first.length;
      blocks.add(
        EditorBlock.object(localTableType, {
          'rows': [
            for (final row in rows)
              [for (var c = 0; c < columns; c++) c < row.length ? row[c] : ''],
          ],
        }),
      );
      listIndents.clear();
      continue;
    }

    final headingMatch = heading.firstMatch(line);
    if (headingMatch != null) {
      blocks.add(
        EditorBlock(
          type: 'heading',
          data: {'level': headingMatch[1]!.length.clamp(1, 3)},
          delta: inline(headingMatch[2]!),
        ),
      );
      listIndents.clear();
      continue;
    }

    if (rule.hasMatch(line)) {
      blocks.add(EditorBlock.divider());
      listIndents.clear();
      continue;
    }

    final quoteMatch = quote.firstMatch(line);
    if (quoteMatch != null) {
      blocks.add(EditorBlock(type: 'quote', delta: inline(quoteMatch[1]!)));
      listIndents.clear();
      continue;
    }

    final itemMatch = listItem.firstMatch(line);
    if (itemMatch != null) {
      final depth = listDepth(indentOf(line));
      final check = itemMatch[3];
      final numbered = RegExp(r'^\d').hasMatch(itemMatch[2]!);
      blocks.add(
        EditorBlock(
          type: check != null
              ? 'todo_list'
              : numbered
              ? 'numbered_list'
              : 'bulleted_list',
          depth: depth,
          data: {if (check != null) 'checked': check != ' '},
          delta: inline(itemMatch[4]!),
        ),
      );
      continue;
    }

    // 일반 글. 목록 바로 아래 들여쓴 줄은 목록 항목 아래로.
    final indent = indentOf(line);
    final depth = listIndents.isNotEmpty && indent > listIndents.first
        ? listDepth(indent)
        : 0;
    if (depth == 0) listIndents.clear();
    blocks.add(
      EditorBlock(
        type: 'paragraph',
        depth: depth,
        delta: inline(line.trim().replaceAll(RegExp(r'\s{2,}$|\\$'), '')),
      ),
    );
  }

  if (blocks.isEmpty) blocks.add(EditorBlock(type: 'paragraph'));
  return blocks;
}

List<String> _tableCells(String line) {
  var text = line.trim();
  if (text.startsWith('|')) text = text.substring(1);
  if (text.endsWith('|') && !text.endsWith(r'\|')) {
    text = text.substring(0, text.length - 1);
  }
  return text
      .split(RegExp(r'(?<!\\)\|'))
      .map(
        (cell) => _plainText(
          cell
              .trim()
              .replaceAll(r'\|', '|')
              .replaceAll(RegExp(r'<br\s*/?>'), '\n'),
        ),
      )
      .toList();
}

/// 서식 기호를 뺀 글자만 (표 칸처럼 서식을 담을 수 없는 곳)
String _plainText(String markdown) => _parseInline(
  markdown,
  const {},
  null,
).map((op) => op['insert'] as String).join().replaceAll(inlineImageChar, '');

const _imageExtensions = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp'};

bool isImagePath(String path) {
  final dot = path.lastIndexOf('.');
  return dot >= 0 &&
      _imageExtensions.contains(path.substring(dot).toLowerCase());
}

final _inlinePattern = RegExp(
  r'\\([\\`*_{}\[\]()#+\-.!|~<>])' // 1 이스케이프
  r'|`([^`]+)`' // 2 코드
  r'|!\[([^\]]*)\]\((<[^>]*>|[^)\s]*)(?:\s+"[^"]*")?\)' // 3 설명 4 그림 주소
  r'|\[([^\]]+)\]\((<[^>]*>|[^)\s]*)(?:\s+"[^"]*")?\)' // 5 글 6 링크 주소
  r'|<(https?://[^>\s]+)>' // 7 자동 링크
  r'|\*\*(.+?)\*\*|__(.+?)__' // 8, 9 굵게
  r'|~~(.+?)~~' // 10 취소선
  r'|<u>(.+?)</u>' // 11 밑줄
  r'|\*([^*\s](?:.*?[^*\s])?)\*' // 12 기울임
  r'|(?<!\w)_([^_\s](?:.*?[^_\s])?)_(?!\w)' // 13 기울임
  r'|<br\s*/?>', // 줄바꿈
);

List<Map<String, Object?>> _parseInline(
  String text,
  Map<String, Object?> marks,
  String? Function(String)? attachmentOf,
) {
  final ops = <Map<String, Object?>>[];
  void add(String insert, Map<String, Object?> attributes) {
    if (insert.isEmpty) return;
    ops.add({
      'insert': insert,
      if (attributes.isNotEmpty) 'attributes': attributes,
    });
  }

  List<Map<String, Object?>> nested(String inner, Map<String, Object?> extra) =>
      _parseInline(inner, {...marks, ...extra}, attachmentOf);

  String target(String raw) {
    final unwrapped = raw.startsWith('<')
        ? raw.substring(1, raw.length - 1)
        : raw;
    return unwrapped.trim();
  }

  var last = 0;
  for (final m in _inlinePattern.allMatches(text)) {
    add(text.substring(last, m.start), marks);
    last = m.end;
    if (m[1] != null) {
      add(m[1]!, marks);
    } else if (m[2] != null) {
      add(m[2]!, {...marks, 'code': true});
    } else if (m[4] != null) {
      final src = target(m[4]!);
      final local = attachmentOf?.call(src);
      if (local != null && isImagePath(local)) {
        add(inlineImageChar, inlineImageMarks(local));
      } else if (local != null) {
        add(inlineImageChar, inlineFileMarks(local, _fileName(local)));
      } else {
        add(m[3]!.isEmpty ? src : m[3]!, {...marks, 'href': src});
      }
    } else if (m[6] != null) {
      final href = target(m[6]!);
      final local = attachmentOf?.call(href);
      if (local != null) {
        // 내보낸 첨부파일 링크 → 다시 첨부파일로
        add(
          inlineImageChar,
          isImagePath(local)
              ? inlineImageMarks(local)
              : inlineFileMarks(local, _plainText(m[5]!)),
        );
      } else {
        ops.addAll(nested(m[5]!, {'href': href}));
      }
    } else if (m[7] != null) {
      add(m[7]!, {...marks, 'href': m[7]});
    } else if (m[8] != null || m[9] != null) {
      ops.addAll(nested(m[8] ?? m[9]!, {'bold': true}));
    } else if (m[10] != null) {
      ops.addAll(nested(m[10]!, {'strikethrough': true}));
    } else if (m[11] != null) {
      ops.addAll(nested(m[11]!, {'underline': true}));
    } else if (m[12] != null || m[13] != null) {
      ops.addAll(nested(m[12] ?? m[13]!, {'italic': true}));
    } else {
      add('\n', marks);
    }
  }
  add(text.substring(last), marks);
  return ops;
}

String _fileName(String path) => path
    .split(RegExp(r'[\\/]'))
    .lastWhere((s) => s.isNotEmpty, orElse: () => path);
