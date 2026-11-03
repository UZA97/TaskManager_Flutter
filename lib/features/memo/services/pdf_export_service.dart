import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';

import '../editor_v2/editor_block.dart';
import '../editor_v2/inline_image.dart';
import '../editor_v2/table_block.dart';

class PdfExportService {
  Future<pw.Font> _loadSystemFont({bool bold = false}) async {
    final fontFile = File(
      bold
          ? 'C:\\Windows\\Fonts\\malgunbd.ttf'
          : 'C:\\Windows\\Fonts\\malgun.ttf',
    );
    if (fontFile.existsSync()) {
      final bytes = await fontFile.readAsBytes();
      final byteData = ByteData.view(bytes.buffer);
      return pw.Font.ttf(byteData);
    }
    return bold ? pw.Font.helveticaBold() : pw.Font.helvetica();
  }

  Future<void> exportToPdf({
    required List<EditorBlock> blocks,
    required String title,
    required List<String> tags,
  }) async {
    final font = await _loadSystemFont();
    final boldFont = await _loadSystemFont(bold: true);

    final pdf = pw.Document();
    final theme = pw.ThemeData.withFont(base: font, bold: boldFont);

    final List<pw.Widget> pdfWidgets = [];

    // 제목
    pdfWidgets.add(
      pw.Text(
        title.isEmpty ? '제목 없음' : title,
        style: pw.TextStyle(font: boldFont, fontSize: 24),
      ),
    );
    pdfWidgets.add(pw.SizedBox(height: 8));

    // 태그
    if (tags.isNotEmpty) {
      pdfWidgets.add(
        pw.Wrap(
          spacing: 6,
          children: tags.map((tag) {
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
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
      );
      pdfWidgets.add(pw.SizedBox(height: 8));
    }

    pdfWidgets.add(pw.Divider());
    pdfWidgets.add(pw.SizedBox(height: 8));

    // 블록 순회 (번호 목록은 같은 깊이에서 이어지는 동안 번호를 셈)
    final numbers = <int, int>{};
    for (final block in blocks) {
      if (block.type == 'numbered_list') {
        numbers[block.depth] = (numbers[block.depth] ?? 0) + 1;
      }
      numbers.removeWhere(
        (depth, _) =>
            depth > block.depth ||
            (depth == block.depth && block.type != 'numbered_list'),
      );
      final widget = await _blockToWidget(
        block,
        font,
        boldFont,
        number: numbers[block.depth] ?? 1,
      );
      if (widget != null) pdfWidgets.add(widget);
    }

    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pdfWidgets,
      ),
    );

    // 저장 위치 선택
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'PDF 저장',
      fileName: '${title.isEmpty ? '제목없음' : title}.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (outputPath == null) return;

    final file = File(outputPath);
    await file.writeAsBytes(await pdf.save());
  }

  /// 줄 안의 그림은 글 아래에 차례로
  Future<pw.Widget?> _blockToWidget(
    EditorBlock block,
    pw.Font font,
    pw.Font boldFont, {
    int number = 1,
  }) async {
    final body = await _blockBody(block, font, boldFont, number: number);
    if (!block.isText) return body;
    final controller = block.controller;
    final images = <pw.Widget>[];
    for (var i = 0; i < controller.text.length; i++) {
      final marks = controller.marks[i];
      if (controller.isFileAt(i)) {
        images.add(
          _fileChip(marks[fileNameKey] as String? ?? '첨부파일', font, block),
        );
        continue;
      }
      if (!controller.isImageAt(i)) continue;
      final image = await _image(
        marks[imageMarkKey] as String,
        width: (marks[imageWidthKey] as num?)?.toDouble() ?? defaultImageWidth,
        indent: block.depth * 12.0,
      );
      if (image != null) images.add(image);
    }
    if (images.isEmpty) return body;
    final hasText = stripInlineImages(controller.text).trim().isNotEmpty;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [if (hasText && body != null) body, ...images],
    );
  }

  pw.Widget _fileChip(String fileName, pw.Font font, EditorBlock block) =>
      pw.Padding(
        padding: pw.EdgeInsets.only(bottom: 4, left: block.depth * 12.0),
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Text(
            '[첨부파일] $fileName',
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        ),
      );

  Future<pw.Widget?> _image(
    String src, {
    required double width,
    required double indent,
  }) async {
    try {
      final file = File(src);
      if (!await file.exists()) return null;
      return pw.Padding(
        padding: pw.EdgeInsets.only(bottom: 8, left: indent),
        // 화면 너비(px)를 PDF 크기(pt)로 대략 맞춤
        child: pw.Image(
          pw.MemoryImage(await file.readAsBytes()),
          width: width * 0.75,
          fit: pw.BoxFit.contain,
        ),
      );
    } catch (_) {
      return pw.Text(
        '[이미지를 불러올 수 없습니다]',
        style: const pw.TextStyle(color: PdfColors.red),
      );
    }
  }

  Future<pw.Widget?> _blockBody(
    EditorBlock block,
    pw.Font font,
    pw.Font boldFont, {
    int number = 1,
  }) async {
    final type = block.type;
    final attrs = block.raw == null
        ? block.data
        : (block.raw!['data'] as Map?) ?? const {};
    final depth = block.depth;
    final indent = depth * 12.0;

    switch (type) {
      case 'paragraph':
        final text = stripInlineImages(block.controller.text);
        if (text.isEmpty) return pw.SizedBox(height: 8);
        return pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 4, left: indent),
          child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 11)),
        );

      case 'heading':
        final level = block.level;
        final text = stripInlineImages(block.controller.text);
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8, top: 8),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: level == 1
                  ? 20
                  : level == 2
                  ? 16
                  : 14,
            ),
          ),
        );

      case 'todo_list':
        final checked = block.checked;
        final text = stripInlineImages(block.controller.text);
        return pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 4, left: indent),
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
                        child: pw.CustomPaint(
                          size: const PdfPoint(10, 10),
                          painter: (canvas, size) {
                            canvas
                              ..setStrokeColor(PdfColors.white)
                              ..setLineWidth(1.5)
                              ..moveTo(2, 5)
                              ..lineTo(4.5, 7.5)
                              ..lineTo(8, 3)
                              ..strokePath();
                          },
                        ),
                      )
                    : null,
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Text(
                  text,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 11,
                    decoration: checked ? pw.TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'bulleted_list':
        final text = stripInlineImages(block.controller.text);
        return pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 4, left: 12 + indent),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                depth == 0 ? '- ' : '  - ', // • 대신 - 사용
                style: pw.TextStyle(font: font, fontSize: 11),
              ),
              pw.Expanded(
                child: pw.Text(
                  text,
                  style: pw.TextStyle(font: font, fontSize: 11),
                ),
              ),
            ],
          ),
        );

      case 'numbered_list':
        final text = stripInlineImages(block.controller.text);
        return pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 4, left: 12 + indent),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '$number. ',
                style: pw.TextStyle(font: font, fontSize: 11),
              ),
              pw.Expanded(
                child: pw.Text(
                  text,
                  style: pw.TextStyle(font: font, fontSize: 11),
                ),
              ),
            ],
          ),
        );

      case 'quote':
        final text = stripInlineImages(block.controller.text);
        return pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 8, left: 12 + indent),
          child: pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.grey, width: 3),
              ),
            ),
            padding: const pw.EdgeInsets.only(left: 8),
            child: pw.Text(
              text,
              style: pw.TextStyle(
                font: font,
                fontSize: 11,
                color: PdfColors.grey600,
              ),
            ),
          ),
        );

      case 'local_code':
      case 'code':
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
                if (language.isNotEmpty)
                  pw.Text(
                    language,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey,
                    ),
                  ),
                pw.Text(
                  code,
                  style: pw.TextStyle(font: pw.Font.courier(), fontSize: 10),
                ),
              ],
            ),
          ),
        );

      case 'local_image':
        final src = attrs['src'] as String? ?? attrs['url'] as String? ?? '';
        if (src.isEmpty) return null;
        try {
          final file = File(src);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final image = pw.MemoryImage(bytes);
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Image(image, height: 300, fit: pw.BoxFit.contain),
            );
          }
        } catch (e) {
          return pw.Text(
            '[이미지를 불러올 수 없습니다]',
            style: const pw.TextStyle(color: PdfColors.red),
          );
        }
        return null;

      case 'local_file':
        final fileName = attrs['fileName'] as String? ?? '첨부파일';
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              '[첨부파일] $fileName',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
          ),
        );

      case 'local_location':
        final name = attrs['name'] as String? ?? '';
        final lat = (attrs['lat'] as num?)?.toDouble() ?? 0.0;
        final lng = (attrs['lng'] as num?)?.toDouble() ?? 0.0;
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              '[위치] $name ($lat, $lng)',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
          ),
        );

      case localTableType:
        final rows = tableRowsOf(block);
        return pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 8, left: indent),
          child: pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            children: [
              for (var r = 0; r < rows.length; r++)
                pw.TableRow(
                  decoration: r == 0
                      ? const pw.BoxDecoration(color: PdfColors.grey100)
                      : null,
                  children: [
                    for (final cell in rows[r])
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          cell,
                          style: pw.TextStyle(
                            font: r == 0 ? boldFont : font,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );

      case 'divider':
        return pw.Divider(color: PdfColors.grey400);

      default:
        final text = stripInlineImages(block.controller.text);
        if (text.isEmpty) return null;
        return pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 4, left: indent),
          child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 11)),
        );
    }
  }
}
