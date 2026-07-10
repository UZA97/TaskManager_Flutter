import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/note.dart';
import 'dart:convert';
import 'dart:typed_data';

class PdfExportService {
  Future<pw.Font> _loadSystemFont({bool bold = false}) async {
    final fontFile = File(
      bold
          ? 'C:\\Windows\\Fonts\\malgunbd.ttf'
          : 'C:\\Windows\\Fonts\\malgun.ttf',
    );
    if (fontFile.existsSync()) {
      final bytes = await fontFile.readAsBytes();
      final byteData = ByteData.sublistView(bytes);
      return pw.Font.ttf(byteData);
    }

    return bold ? pw.Font.helveticaBold() : pw.Font.helvetica();
  }

  Future<String> exportToPdf(Note note) async {
    final font = await _loadSystemFont();
    final boldFont = await _loadSystemFont(bold: true);

    final pdf = pw.Document();
    final theme = pw.ThemeData.withFont(base: font, bold: boldFont);

    // JSON 파싱
    final blocks = _parseBlocks(note.content);

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // 제목
          pw.Text(
            note.title.isEmpty ? '제목 없음' : note.title,
            style: pw.TextStyle(font: boldFont, fontSize: 24),
          ),
          pw.SizedBox(height: 8),
          // 태그
          if (note.tags.isNotEmpty)
            pw.Wrap(
              spacing: 6,
              children: note.tags.map((tag) {
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(12),
                    ),
                  ),
                  child: pw.Text(
                    '#$tag',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 10,
                      color: PdfColors.blue,
                    ),
                  ),
                );
              }).toList(),
            ),
          pw.SizedBox(height: 4),
          pw.Divider(),
          pw.SizedBox(height: 8),
          // 본문
          ...blocks,
        ],
      ),
    );

    // 저장
    final dir = await getApplicationSupportDirectory();
    final fileName =
        '${note.title.isEmpty ? '제목없음' : note.title}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(p.join(dir.path, 'exports', fileName));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  List<pw.Widget> _parseBlocks(String content) {
    if (content.isEmpty) return [];

    try {
      final json = jsonDecode(content);
      final document = json['document'] as Map<String, dynamic>?;
      if (document == null) return [];

      final children = document['children'] as List<dynamic>? ?? [];
      return children.map((block) => _blockToWidget(block)).toList();
    } catch (e) {
      return [pw.Text(content)];
    }
  }

  pw.Widget _blockToWidget(Map<String, dynamic> block) {
    final type = block['type'] as String? ?? 'paragraph';
    final attrs = block['attributes'] as Map<String, dynamic>? ?? {};
    final children = block['delta'] as List<dynamic>? ?? [];

    switch (type) {
      case 'heading':
        final level = attrs['level'] as int? ?? 1;
        final text = _deltaToText(children);
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: level == 1
                  ? 20
                  : level == 2
                  ? 16
                  : 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );

      case 'todo_list':
        final checked = attrs['checked'] as bool? ?? false;
        final text = _deltaToText(children);
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            children: [
              pw.Container(
                width: 12,
                height: 12,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  color: checked ? PdfColors.blue : PdfColors.white,
                ),
                child: checked
                    ? pw.Center(
                        child: pw.Text(
                          '✓',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.white,
                          ),
                        ),
                      )
                    : null,
              ),
              pw.SizedBox(width: 6),
              pw.Text(text),
            ],
          ),
        );

      case 'bulleted_list':
        final text = _deltaToText(children);
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4, left: 12),
          child: pw.Row(
            children: [
              pw.Text('• '),
              pw.Expanded(child: pw.Text(text)),
            ],
          ),
        );

      case 'numbered_list':
        final text = _deltaToText(children);
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4, left: 12),
          child: pw.Text(text),
        );

      case 'quote':
        final text = _deltaToText(children);
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8, left: 12),
          child: pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.grey, width: 3),
              ),
            ),
            padding: const pw.EdgeInsets.only(left: 8),
            child: pw.Text(
              text,
              style: const pw.TextStyle(color: PdfColors.grey600),
            ),
          ),
        );

      case 'code':
        final text = _deltaToText(children);
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              text,
              style: pw.TextStyle(font: pw.Font.courier(), fontSize: 11),
            ),
          ),
        );

      case 'local_image':
        final src = attrs['src'] as String? ?? '';
        final file = File(src);
        if (file.existsSync()) {
          try {
            final imageBytes = file.readAsBytesSync();
            final image = pw.MemoryImage(imageBytes);
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Image(image, width: 300),
            );
          } catch (_) {}
        }
        return pw.Text('[이미지: $src]');

      case 'local_location':
        final name = attrs['name'] as String? ?? '';
        final lat = (attrs['lat'] as num?)?.toDouble() ?? 0.0;
        final lng = (attrs['lng'] as num?)?.toDouble() ?? 0.0;
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            children: [pw.Text('📍 '), pw.Text('$name ($lat, $lng)')],
          ),
        );

      case 'local_code':
        final code = attrs['code'] as String? ?? '';
        final language = attrs['language'] as String? ?? '';
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  language,
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  code,
                  style: pw.TextStyle(font: pw.Font.courier(), fontSize: 11),
                ),
              ],
            ),
          ),
        );

      case 'local_file':
        final fileName = attrs['fileName'] as String? ?? '';
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text('📎 $fileName'),
        );

      default:
        final text = _deltaToText(children);
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(text),
        );
    }
  }

  String _deltaToText(List<dynamic> delta) {
    return delta.map((op) => op['insert'] as String? ?? '').join();
  }
}
