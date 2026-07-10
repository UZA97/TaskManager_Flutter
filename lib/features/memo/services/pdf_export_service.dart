import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:appflowy_editor/appflowy_editor.dart';

class PdfExportService {
  Future<pw.Font> _loadSystemFont({bool bold = false}) async {
    final fontFile = File(
      bold
          ? 'C:\\Windows\\Fonts\\malgunbd.ttf'
          : 'C:\\Windows\\Fonts\\malgun.ttf',
    );
    if (fontFile.existsSync()) {
      final bytes = await fontFile.readAsBytes();
      return pw.Font.ttf(bytes.buffer.asByteData());
    }
    return bold ? pw.Font.helveticaBold() : pw.Font.helvetica();
  }

  Future<void> exportToPdf({
    required EditorState editorState,
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

    // 블록 순회
    await _processNodes(
      editorState.document.root.children.toList(),
      pdfWidgets,
      font,
      boldFont,
    );

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

  Future<void> _processNodes(
    List<Node> nodes,
    List<pw.Widget> pdfWidgets,
    pw.Font font,
    pw.Font boldFont, {
    int depth = 0,
  }) async {
    for (final node in nodes) {
      final widget = await _nodeToWidget(node, font, boldFont, depth: depth);
      if (widget != null) pdfWidgets.add(widget);

      if (node.children.isNotEmpty) {
        await _processNodes(
          node.children.toList(),
          pdfWidgets,
          font,
          boldFont,
          depth: depth + 1,
        );
      }
    }
  }

  Future<pw.Widget?> _nodeToWidget(
    Node node,
    pw.Font font,
    pw.Font boldFont, {
    int depth = 0,
  }) async {
    final type = node.type;
    final attrs = node.attributes;
    final indent = depth * 12.0;

    switch (type) {
      case 'paragraph':
        final text = node.delta?.toPlainText() ?? '';
        if (text.isEmpty) return pw.SizedBox(height: 8);
        return pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 4, left: indent),
          child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 11)),
        );

      case 'heading':
        final level = attrs['level'] as int? ?? 1;
        final text = node.delta?.toPlainText() ?? '';
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
        final checked = attrs['checked'] as bool? ?? false;
        final text = node.delta?.toPlainText() ?? '';
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
        final text = node.delta?.toPlainText() ?? '';
        return pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 4, left: 12 + indent),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                depth == 0 ? '• ' : '◦ ',
                style: pw.TextStyle(font: font),
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
        final text = node.delta?.toPlainText() ?? '';
        return pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 4, left: 12 + indent),
          child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 11)),
        );

      case 'quote':
        final text = node.delta?.toPlainText() ?? '';
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
        final code =
            attrs['code'] as String? ?? node.delta?.toPlainText() ?? '';
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
              '📎 $fileName',
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
              '📍 $name ($lat, $lng)',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
          ),
        );

      default:
        final text = node.delta?.toPlainText() ?? '';
        if (text.isEmpty) return null;
        return pw.Padding(
          padding: pw.EdgeInsets.only(bottom: 4, left: indent),
          child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 11)),
        );
    }
  }
}
