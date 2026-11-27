/// Writes tables out as CSV or a real Excel workbook (.xlsx), so a budget or the
/// payment history can be opened in Excel, Numbers or Google Sheets (File >
/// Import). Pure Dart: rows in, bytes out. The files read back through
/// `sheet_import.dart`, so an export can be imported again.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// One cell: text, a number (written as a number so sheets can sum it) or empty.
typedef Cell = Object?;

class SheetTable {
  const SheetTable(this.name, this.rows);

  /// Sheet tab name (max 31 chars, no `[]:*?/\`).
  final String name;

  /// First row is the header.
  final List<List<Cell>> rows;
}

String _csvCell(Cell c) {
  final s = c == null ? '' : '$c';
  // A leading = + - @ would run as a formula in a spreadsheet; prefix text cells only.
  final safe = c is String && RegExp(r'^[=+@]').hasMatch(s) ? "'$s" : s;
  return RegExp(r'[",\n\r]').hasMatch(safe)
      ? '"${safe.replaceAll('"', '""')}"'
      : safe;
}

/// UTF-8 CSV with a BOM (Excel then reads it as UTF-8) and CRLF rows.
String buildCsv(List<List<Cell>> rows) =>
    '﻿${rows.map((r) => r.map(_csvCell).join(',')).join('\r\n')}\r\n';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

String _ref(int col, int row) {
  var n = col + 1;
  var s = '';
  while (n > 0) {
    final m = (n - 1) % 26;
    s = String.fromCharCode(65 + m) + s;
    n = (n - 1) ~/ 26;
  }
  return '$s${row + 1}';
}

String _safeName(String n) {
  final t = n.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
  final name = t.isEmpty ? 'Sheet' : t;
  return name.length > 31 ? name.substring(0, 31) : name;
}

String _sheetXml(List<List<Cell>> rows) {
  final b = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
  );
  for (var r = 0; r < rows.length; r++) {
    b.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      final v = rows[r][c];
      if (v == null || (v is String && v.isEmpty)) continue;
      final ref = _ref(c, r);
      if (v is num && v.isFinite) {
        b.write('<c r="$ref"><v>$v</v></c>');
      } else {
        final s = v is String && RegExp(r'^[=+@]').hasMatch(v) ? "'$v" : '$v';
        b.write(
          '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">${_esc(s)}</t></is></c>',
        );
      }
    }
    b.write('</row>');
  }
  b.write('</sheetData></worksheet>');
  return b.toString();
}

/// A minimal, valid .xlsx workbook: one sheet per table.
Uint8List buildXlsx(List<SheetTable> sheets) {
  final tables = sheets.isEmpty ? [const SheetTable('Sheet1', [])] : sheets;
  final names = <String>[];
  for (final t in tables) {
    var n = _safeName(t.name);
    var i = 2;
    while (names.any((x) => x.toLowerCase() == n.toLowerCase())) {
      final base = _safeName(t.name);
      n = '${base.length > 28 ? base.substring(0, 28) : base} $i';
      i++;
    }
    names.add(n);
  }
  final a = Archive();
  void add(String path, String content) {
    final bytes = utf8.encode(content);
    a.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  add(
    '[Content_Types].xml',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '${[for (var i = 0; i < tables.length; i++) '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
        '</Types>',
  );
  add(
    '_rels/.rels',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>',
  );
  add(
    'xl/workbook.xml',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
        '${[for (var i = 0; i < tables.length; i++) '<sheet name="${_esc(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
        '</sheets></workbook>',
  );
  add(
    'xl/_rels/workbook.xml.rels',
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${[for (var i = 0; i < tables.length; i++) '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>'].join()}'
        '</Relationships>',
  );
  for (var i = 0; i < tables.length; i++) {
    add('xl/worksheets/sheet${i + 1}.xml', _sheetXml(tables[i].rows));
  }
  return Uint8List.fromList(ZipEncoder().encode(a));
}
