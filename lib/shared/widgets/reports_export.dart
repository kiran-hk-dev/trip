import 'dart:typed_data';

import 'package:csv/csv.dart' show CsvEncoder;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// CSV and PDF export that works on Android, iOS and web.
///
/// On mobile `Printing.sharePdf` writes the bytes to a temporary file and
/// opens the platform share sheet, so the user can save it, email it or send
/// it to themselves. On web it triggers a browser download.
abstract final class ExportService {
  /// Exports rows as CSV. The BOM is included so spreadsheet apps detect UTF-8.
  static Future<void> shareCsv(String filename, List<List<String>> rows) async {
    final String csv = csvWithBom(rows);
    await Printing.sharePdf(
      bytes: Uint8List.fromList(csv.codeUnits),
      filename: filename,
    );
  }

  static Future<void> sharePdf(String filename, pw.Document document) async {
    await Printing.sharePdf(bytes: await document.save(), filename: filename);
  }

  /// Renders a document to bytes without offering the share sheet — used when
  /// previewing or when the caller wants to upload the file.
  static Future<Uint8List> renderPdf(pw.Document document) async =>
      Uint8List.fromList(await document.save());

  /// Encodes rows as CSV with a leading UTF-8 BOM, so spreadsheet apps open
  /// non-ASCII currency symbols and names correctly.
  static String csvWithBom(List<List<String>> rows) {
    final List<List<dynamic>> data = <List<dynamic>>[
      for (final List<String> row in rows) row,
    ];
    final String csv = const CsvEncoder().convert(data);
    return '${String.fromCharCode(0xFEFF)}$csv';
  }

  /// Opens the platform print dialog with a prepared document.
  static Future<void> printDocument(String jobName, pw.Document document) =>
      Printing.layoutPdf(onLayout: (_) async => document.save(), name: jobName);

  // ---------------------------------------------------------------------
  // Shared PDF styling so every report looks the same.
  // ---------------------------------------------------------------------

  static pw.Document buildDocument(String title) =>
      pw.Document(title: title, author: 'TripSplit World');

  static pw.Widget reportHeader(String title, String subtitle) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: <pw.Widget>[
      pw.Text(
        'TripSplit World',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        title,
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        subtitle,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
      pw.SizedBox(height: 8),
    ],
  );

  static pw.Widget heading(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
    ),
  );

  static pw.Widget note(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
    ),
  );

  static pw.Widget table(List<List<String>> rows) => pw.Table(
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
    ),
    columnWidths: <int, pw.TableColumnWidth>{
      for (int i = 0; i < (rows.isEmpty ? 1 : rows.first.length); i++)
        i: pw.FlexColumnWidth(),
    },
    children: <pw.TableRow>[
      for (int r = 0; r < rows.length; r++)
        pw.TableRow(
          children: <pw.Widget>[
            for (int c = 0; c < rows[r].length; c++)
              pw.Text(
                c < rows[r].length ? rows[r][c] : '',
                style: r == 0
                    ? pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: PdfColors.grey800,
                      )
                    : const pw.TextStyle(fontSize: 9),
              ),
          ],
        ),
    ],
  );
}
