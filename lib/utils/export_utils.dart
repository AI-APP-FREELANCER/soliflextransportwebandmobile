// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ExportUtils {
  ExportUtils._();

  /// Downloads [rows] as a UTF-8 BOM CSV file named [filename].
  /// The BOM ensures Excel opens the file with correct encoding.
  static void downloadCsv(String filename, List<List<dynamic>> rows) {
    final buffer = StringBuffer();
    buffer.write('﻿'); // UTF-8 BOM for Excel
    for (final row in rows) {
      buffer.writeln(row.map(_escapeCsvCell).join(','));
    }

    final bytes = buffer.toString();
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static String _escapeCsvCell(dynamic value) {
    final s = value?.toString() ?? '';
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
