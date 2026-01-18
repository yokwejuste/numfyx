import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../models/contact_result.dart';

class CsvExportService {
  static Future<String?> exportToCsv(
    List<ContactResult> results, {
    bool autoOpen = true,
  }) async {
    try {
      final csvContent = _generateCsvContent(results);
      if (csvContent.isEmpty) {
        debugPrint('CsvExportService: No content to export');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'numfyx_report_$timestamp.csv';

      final appDocDir = await getApplicationDocumentsDirectory();
      final appDocPath = '${appDocDir.path}/$fileName';

      final saved = await _writeAndVerify(appDocPath, csvContent);
      if (!saved) {
        debugPrint('CsvExportService: Failed to save to app documents');
        return null;
      }

      final publicPath = await _tryCopyToDownloads(appDocPath, fileName);
      final finalPath = publicPath ?? appDocPath;

      debugPrint('CsvExportService: File saved to: $finalPath');

      if (autoOpen) {
        try {
          final result = await OpenFilex.open(finalPath);
          debugPrint('CsvExportService: OpenFilex result: ${result.type} - ${result.message}');
        } catch (e) {
          debugPrint('CsvExportService: Failed to open file: $e');
        }
      }

      return finalPath;
    } catch (e, st) {
      debugPrint('CsvExportService: Export failed: $e');
      debugPrintStack(stackTrace: st);
      return null;
    }
  }

  static String _generateCsvContent(List<ContactResult> results) {
    final sb = StringBuffer();
    sb.writeln('Contact,Original,Final,Status');

    for (final r in results) {
      final contact = _escapeCsv(r.contactName);
      final original = _escapeCsv(r.originalNumber);
      final final_ = _escapeCsv(r.finalNumber);
      final status = _escapeCsv(r.status);
      sb.writeln('$contact,$original,$final_,$status');
    }

    return sb.toString();
  }

  static String _escapeCsv(String value) {
    var clean = value
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (clean.contains(',') || clean.contains('"') || clean.contains('\n')) {
      clean = clean.replaceAll('"', '""');
      return '"$clean"';
    }

    return clean;
  }

  static Future<bool> _writeAndVerify(String path, String content) async {
    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(content, flush: true);

      if (!await file.exists()) {
        debugPrint('CsvExportService: File does not exist after write: $path');
        return false;
      }

      final written = await file.readAsString();
      if (written.length != content.length) {
        debugPrint('CsvExportService: Size mismatch - expected ${content.length}, got ${written.length}');
        return false;
      }

      debugPrint('CsvExportService: Verified write to $path (${content.length} chars)');
      return true;
    } catch (e) {
      debugPrint('CsvExportService: Write failed: $e');
      return false;
    }
  }

  static Future<String?> _tryCopyToDownloads(String sourcePath, String fileName) async {
    if (!Platform.isAndroid) return null;

    try {
      String? downloadsPath;

      try {
        final exDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (exDirs != null && exDirs.isNotEmpty) {
          downloadsPath = exDirs.first.path;
        }
      } catch (_) {}

      downloadsPath ??= '/storage/emulated/0/Download';

      final downloadsDir = Directory(downloadsPath);
      if (!await downloadsDir.exists()) {
        debugPrint('CsvExportService: Downloads dir does not exist');
        return null;
      }

      final destPath = '$downloadsPath/$fileName';

      if (sourcePath.startsWith(downloadsPath)) {
        return sourcePath;
      }

      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        debugPrint('CsvExportService: Source file not found for copy');
        return null;
      }

      await sourceFile.copy(destPath);

      final destFile = File(destPath);
      if (!await destFile.exists()) {
        debugPrint('CsvExportService: Copy verification failed');
        return null;
      }

      return destPath;
    } catch (e) {
      debugPrint('CsvExportService: Copy to downloads failed: $e');
      return null;
    }
  }
}
