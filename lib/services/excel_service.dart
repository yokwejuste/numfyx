import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/contact_result.dart';

class ExcelService {
  static String _sanitizeText(String text) {
    return text
        .replaceAll(RegExp(r'[^\x00-\x7F]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Future<String?> exportResults(List<ContactResult> results) async {
    try {
      final pdf = pw.Document();

      final allResults = results.toList();
      final succeededResults = results.where((r) => r.status == 'Updated').toList();
      final failedResults = results.where((r) => r.status.startsWith('Failed')).toList();
      final skippedResults = results.where((r) => r.status.startsWith('Skipped')).toList();

      final summaryData = [
        ['Total Processed', '${results.length}'],
        ['Succeeded', '${succeededResults.length}'],
        ['Failed', '${failedResults.length}'],
        ['Skipped', '${skippedResults.length}'],
      ];

      List<pw.Widget> buildPage(List<ContactResult> pageResults, String title) {
        return [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['Contact', 'Original', 'Final', 'Status'],
            data: pageResults
                .map(
                  (result) => [
                    _sanitizeText(result.contactName),
                    _sanitizeText(result.originalNumber),
                    _sanitizeText(result.finalNumber),
                    _sanitizeText(result.status),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellHeight: 20,
          ),
        ];
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            final widgets = <pw.Widget>[
              pw.Header(
                level: 0,
                child: pw.Text(
                  'NumFyx Contact Processing Report',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Generated: ${DateTime.now().toString().substring(0, 19)}',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 15),
              pw.Text(
                'Summary',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.TableHelper.fromTextArray(
                headers: ['Category', 'Count'],
                data: summaryData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
              ),
              pw.SizedBox(height: 20),
            ];

            if (allResults.isNotEmpty) {
              widgets.addAll(buildPage(allResults, 'All Results'));
              widgets.add(pw.SizedBox(height: 20));
            }

            if (succeededResults.isNotEmpty) {
              widgets.addAll(buildPage(succeededResults, 'Succeeded (Updated)'));
              widgets.add(pw.SizedBox(height: 20));
            }

            if (failedResults.isNotEmpty) {
              widgets.addAll(buildPage(failedResults, 'Failed Numbers'));
              widgets.add(pw.SizedBox(height: 20));
            }

            if (skippedResults.isNotEmpty) {
              widgets.addAll(buildPage(skippedResults, 'Skipped Numbers'));
              widgets.add(pw.SizedBox(height: 20));
            }

            return widgets;
          },
        ),
      );

      Directory? directory;
      if (Platform.isAndroid) {
        try {
          final exDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
          if (exDirs != null && exDirs.isNotEmpty) {
            directory = exDirs.first;
          }
        } catch (_) {}

        directory ??= Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          try {
            directory = await getExternalStorageDirectory();
          } catch (_) {
            directory = null;
          }
        }
      } else {
        try {
          directory = await getDownloadsDirectory();
        } catch (_) {
          directory = null;
        }
      }

      directory ??= await getApplicationDocumentsDirectory();

      try {
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      } catch (e) {
        debugPrint('Could not create directory ${directory.path}: $e');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/numfyx_report_$timestamp.pdf';

      final file = File(filePath);
      try {
        await file.create(recursive: true);
        final bytes = await pdf.save();
        await file.writeAsBytes(bytes, flush: true);
        return filePath;
      } catch (e, st) {
        debugPrint('Failed to write PDF to $filePath: $e');
        debugPrintStack(stackTrace: st);
        try {
          final fallbackDir = await getApplicationDocumentsDirectory();
          final fallbackPath = '${fallbackDir.path}/numfyx_report_$timestamp.pdf';
          final fallbackFile = File(fallbackPath);
          await fallbackFile.create(recursive: true);
          final bytes = await pdf.save();
          await fallbackFile.writeAsBytes(bytes, flush: true);
          debugPrint('Wrote PDF to fallback path $fallbackPath');
          return fallbackPath;
        } catch (e2, st2) {
          debugPrint('Failed to write PDF to fallback location: $e2');
          debugPrintStack(stackTrace: st2);
          return null;
        }
      }
    } catch (e) {
      debugPrint('PDF export error: $e');
      debugPrintStack();
      return null;
    }
  }
}
