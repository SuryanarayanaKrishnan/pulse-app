/// Opens a budget file picked from Files: Excel (.xlsx) or CSV/text, on the
/// phone and without any sign-in. Says specifically what is wrong when the
/// file is something else. Pure Dart.
library;

import 'dart:typed_data';

import 'sheet_import.dart';
import 'statement_import.dart' show StatementFormat, decodeText, sniffFormat;

/// Sheets of [bytes] by name. Throws [FormatException] whose message is safe
/// to show: what the file is, and what to do instead.
Map<String, List<List<String>>> readBudgetFile(
  Uint8List bytes,
  String filename,
) {
  if (bytes.isEmpty) {
    throw const FormatException(
      'That file is empty. If it is in iCloud Drive, open it in Files first '
      'so it downloads, then choose it again.',
    );
  }
  final ext = filename.contains('.')
      ? filename.split('.').last.toLowerCase()
      : '';
  switch (sniffFormat(bytes, filename)) {
    case StatementFormat.xlsx:
      if (ext == 'numbers') {
        throw const FormatException(
          'Numbers files cannot be read directly. In Numbers choose File > '
          'Export To > Excel or CSV, then choose the exported file.',
        );
      }
      try {
        return readXlsx(bytes);
      } on FormatException {
        throw const FormatException(
          'That file is not an Excel workbook. Choose an .xlsx or CSV file.',
        );
      }
    case StatementFormat.xls:
      throw const FormatException(
        'That is an old Excel file (.xls). In Excel choose Save As and pick '
        'Excel Workbook (.xlsx) or CSV, then choose the new file.',
      );
    case StatementFormat.pdf:
      throw const FormatException(
        'That is a PDF. Export your budget from Excel or Sheets as .xlsx or '
        'CSV. Bank statements go in Monthly close.',
      );
    case StatementFormat.image:
      throw const FormatException(
        'That is a picture. Export your budget from Excel or Sheets as .xlsx or CSV.',
      );
    case StatementFormat.unknown:
      throw const FormatException(
        'Pulse reads Excel (.xlsx) and CSV files. That file is neither.',
      );
    case StatementFormat.csv:
    case StatementFormat.text:
      final text = decodeText(bytes);
      if (text.trim().isEmpty) {
        throw const FormatException('That file is empty.');
      }
      return {'Sheet1': parseCsv(text)};
  }
}
