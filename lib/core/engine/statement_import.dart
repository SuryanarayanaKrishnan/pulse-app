/// Reading a statement file on the phone: what kind of file it is, why it
/// cannot be read when it cannot, and a table reader for CSV and Excel
/// exports (with a column-mapping fallback for layouts it does not know).
/// Pure Dart. PDF text is read by the statement service and then goes through
/// `statement_parser.dart`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'dates.dart';
import 'sheet_import.dart';
import 'statement_parser.dart';
import 'types.dart';

// ---- file kind ----------------------------------------------------------------

enum StatementFormat { pdf, xlsx, xls, csv, text, image, unknown }

/// What [bytes] really are. The first bytes win over the file name, because
/// iOS hands over whatever the user picked (a renamed file, a share-sheet
/// export without an extension).
StatementFormat sniffFormat(Uint8List bytes, String filename) {
  if (bytes.isEmpty) return StatementFormat.unknown;
  bool starts(List<int> sig, [int at = 0]) {
    if (bytes.length < at + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (bytes[at + i] != sig[i]) return false;
    }
    return true;
  }

  // "%PDF" anywhere in the first KB (some exports put a few bytes before it).
  final head = bytes.length > 1024 ? bytes.sublist(0, 1024) : bytes;
  for (var i = 0; i + 4 <= head.length; i++) {
    if (head[i] == 0x25 &&
        head[i + 1] == 0x50 &&
        head[i + 2] == 0x44 &&
        head[i + 3] == 0x46) {
      return StatementFormat.pdf;
    }
  }
  if (starts(const [0x50, 0x4B, 0x03, 0x04])) return StatementFormat.xlsx;
  if (starts(const [0xD0, 0xCF, 0x11, 0xE0])) return StatementFormat.xls;
  if (starts(const [0x89, 0x50, 0x4E, 0x47]) || // PNG
      starts(const [0xFF, 0xD8, 0xFF]) || // JPEG
      starts(const [0x47, 0x49, 0x46, 0x38]) || // GIF
      starts(const [0x66, 0x74, 0x79, 0x70], 4)) {
    // "ftyp": HEIC and friends
    return StatementFormat.image;
  }
  final utf16 = starts(const [0xFF, 0xFE]) || starts(const [0xFE, 0xFF]);
  if (!utf16) {
    final n = bytes.length < 2048 ? bytes.length : 2048;
    for (var i = 0; i < n; i++) {
      if (bytes[i] == 0) return StatementFormat.unknown; // binary
    }
  }
  final ext = filename.contains('.')
      ? filename.split('.').last.toLowerCase()
      : '';
  if (ext == 'csv' || ext == 'tsv') return StatementFormat.csv;
  if (ext == 'txt') return StatementFormat.text;
  final lines = decodeText(bytes).split('\n').take(12);
  final delimited = lines.where(
    (l) => [',', ';', '\t'].any((d) => d.allMatches(l).length >= 2),
  );
  return delimited.length >= 3 ? StatementFormat.csv : StatementFormat.text;
}

/// UTF-8 (with or without a BOM) or UTF-16 (Excel's "Unicode text").
String decodeText(Uint8List b) {
  if (b.length >= 2 &&
      ((b[0] == 0xFF && b[1] == 0xFE) || (b[0] == 0xFE && b[1] == 0xFF))) {
    final le = b[0] == 0xFF;
    final units = <int>[];
    for (var i = 2; i + 1 < b.length; i += 2) {
      units.add(le ? b[i] | (b[i + 1] << 8) : (b[i] << 8) | b[i + 1]);
    }
    return String.fromCharCodes(units);
  }
  return utf8.decode(b, allowMalformed: true);
}

/// True for PDF text that is too thin to be a statement: a scan or photo
/// saved as PDF has pages but no text layer.
bool looksScanned(String text) =>
    text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length < 40;

// ---- why a file could not be read ------------------------------------------

enum StatementProblem {
  emptyFile,
  wrongFormat,
  legacyExcel,
  passwordNeeded,
  wrongPassword,
  scannedPdf,
  unsupportedBank,
  unrecognisedLayout,
  damaged,
  couldNotOpen,
}

/// A specific reason with a plain next step. [rows] is set when a table was
/// read but its columns were not recognised, so the screen can offer column
/// mapping. [statementId] is set when a locked statement was kept and is
/// waiting for its password.
class StatementImportException implements Exception {
  const StatementImportException(
    this.problem,
    this.message, {
    this.nextStep = '',
    this.rows,
    this.statementId,
    this.institution,
    this.filename,
  });
  final StatementProblem problem;
  final String message;
  final String nextStep;
  final List<List<String>>? rows;
  final String? statementId;
  final String? institution;
  final String? filename;

  /// Offer "send us a sample" (through the bug report flow).
  bool get canSendSample =>
      problem == StatementProblem.unsupportedBank ||
      problem == StatementProblem.unrecognisedLayout;

  /// Offer to map the columns by hand.
  bool get canMapColumns =>
      rows != null && problem == StatementProblem.unrecognisedLayout;

  StatementImportException copyWith({String? statementId, String? filename}) =>
      StatementImportException(
        problem,
        message,
        nextStep: nextStep,
        rows: rows,
        statementId: statementId ?? this.statementId,
        institution: institution,
        filename: filename ?? this.filename,
      );

  @override
  String toString() => 'StatementImportException($problem): $message';

  static const empty = StatementImportException(
    StatementProblem.emptyFile,
    'That file is empty.',
    nextStep:
        'It may not have finished downloading from iCloud or your email. '
        'Open it in Files to download it, then choose it again.',
  );

  static StatementImportException wrongFormat(StatementFormat f) => switch (f) {
    StatementFormat.xls => const StatementImportException(
      StatementProblem.legacyExcel,
      'This is an old Excel file (.xls).',
      nextStep:
          'In Excel choose Save As and pick Excel Workbook (.xlsx) or CSV, '
          'then choose the new file.',
    ),
    StatementFormat.image => const StatementImportException(
      StatementProblem.wrongFormat,
      'This is a picture, not a statement file.',
      nextStep:
          'Use screenshot capture to read it, or download the statement as a '
          'PDF or CSV from your bank app.',
    ),
    _ => const StatementImportException(
      StatementProblem.wrongFormat,
      'Pulse reads PDF, CSV, Excel (.xlsx) and text statements. This file is '
      'none of those.',
      nextStep: 'Download the statement again from your bank as a PDF or CSV.',
    ),
  };

  static const scanned = StatementImportException(
    StatementProblem.scannedPdf,
    'This PDF is a scan or photo, so there is no text to read.',
    nextStep:
        'Use screenshot capture on the transactions, or download the CSV '
        'version from your bank.',
  );

  static const damaged = StatementImportException(
    StatementProblem.damaged,
    'This PDF is damaged or incomplete.',
    nextStep:
        'Download it again from your bank or email and choose the new copy.',
  );

  static const couldNotOpen = StatementImportException(
    StatementProblem.couldNotOpen,
    'Pulse could not open that file from Files.',
    nextStep:
        'If it is in iCloud Drive or another cloud folder, open it in Files '
        'first so it downloads to this phone, then choose it again.',
  );

  static StatementImportException unsupported({String? institution}) =>
      StatementImportException(
        StatementProblem.unsupportedBank,
        institution == null
            ? 'Pulse does not recognise this bank or layout yet.'
            : 'Pulse found the bank but not the transaction rows in this '
                  'layout.',
        nextStep:
            'Send us a sample (with the numbers blanked out if you like) and '
            'we will add it. A CSV from the same bank works today.',
        institution: institution,
      );
}

// ---- tables (CSV, Excel) ----------------------------------------------------

/// Which column holds what. Indexes are zero-based; [firstRow] is the first
/// transaction row (the row after the header).
class StatementColumns {
  const StatementColumns({
    required this.date,
    required this.description,
    this.amount,
    this.debit,
    this.credit,
    this.balance,
    this.type,
    this.currency,
    this.firstRow = 1,
    this.positiveIsDebit,
    this.dayFirst,
  });
  final int date, description;
  final int? amount, debit, credit, balance, type, currency;
  final int firstRow;

  /// With one signed amount column and no Dr/Cr column: are positive amounts
  /// spending? Null decides from the data (spending when nothing is negative).
  final bool? positiveIsDebit;

  /// Null decides from the dates.
  final bool? dayFirst;

  bool get hasAmounts => amount != null || (debit != null || credit != null);
}

final _hDate = RegExp(r'date|\bdt\b', caseSensitive: false);
final _hNoDate = RegExp(
  r'due|birth|expiry|maturity|statement date',
  caseSensitive: false,
);
const _descWords = [
  'description',
  'narration',
  'narrative',
  'details',
  'particulars',
  'merchant',
  'payee',
  'memo',
  'reference',
  'transaction',
];

String _h(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9/ ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Finds the header row and the columns, or null when the table is not a
/// recognisable statement export.
StatementColumns? detectColumns(List<List<String>> rows) {
  final limit = rows.length < 40 ? rows.length : 40;
  for (var r = 0; r < limit; r++) {
    final cells = [for (final c in rows[r]) _h(c)];
    int? date;
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].isNotEmpty &&
          cells[i].length < 30 &&
          _hDate.hasMatch(cells[i]) &&
          !_hNoDate.hasMatch(cells[i])) {
        date = i;
        break;
      }
    }
    if (date == null) continue;
    int? desc;
    for (final w in _descWords) {
      final i = cells.indexWhere((c) => c.contains(w));
      if (i >= 0 && i != date) {
        desc = i;
        break;
      }
    }
    if (desc == null) continue;
    int? find(RegExp re) {
      final i = cells.indexWhere((c) => c.isNotEmpty && re.hasMatch(c));
      return i < 0 ? null : i;
    }

    final debit = find(
      RegExp(r'^(debit|debits|withdrawal|withdrawals|paid out|money out|dr)\b'),
    );
    final credit = find(
      RegExp(r'^(credit|credits|deposit|deposits|paid in|money in|cr)\b'),
    );
    final amount = find(RegExp(r'^(amount|amt|transaction amount|value)\b'));
    if (amount == null && debit == null && credit == null) continue;
    return StatementColumns(
      date: date,
      description: desc,
      amount: amount,
      debit: debit,
      credit: credit,
      balance: find(RegExp(r'balance')),
      type: find(
        RegExp(
          r'^(type|dr/cr|cr/dr|debit/credit|credit/debit|indicator|dr cr)$',
        ),
      ),
      currency: find(RegExp(r'^(currency|ccy)$')),
      firstRow: r + 1,
    );
  }
  return null;
}

final _suffixDrCr = RegExp(r'\s*(cr|dr)\.?$', caseSensitive: false);

/// Reads [rows] with [columns]. Returns null when no transaction row parsed.
ParsedStatement? parseStatementTable(
  List<List<String>> rows,
  StatementColumns columns, {
  String? institution,
}) {
  String cell(List<String> r, int? i) =>
      i == null || i >= r.length ? '' : r[i].trim();

  final pre = StringBuffer();
  for (var r = 0; r < columns.firstRow - 1 && r < rows.length; r++) {
    pre.writeln(rows[r].join(' '));
  }
  final kind = detectKind(pre.toString());

  final data = rows.skip(columns.firstRow).toList();
  final dayFirst =
      columns.dayFirst ??
      detectDayFirst([for (final r in data) cell(r, columns.date)]);
  final signedOnly =
      columns.amount != null &&
      columns.debit == null &&
      columns.credit == null &&
      columns.type == null;
  var anyNegative = false;
  if (signedOnly) {
    for (final r in data) {
      final m = parseAmountMinor(
        cell(r, columns.amount).replaceAll(_suffixDrCr, ''),
      );
      if (m != null && m < 0) {
        anyNegative = true;
        break;
      }
    }
  }
  final positiveIsDebit = columns.positiveIsDebit ?? !anyNegative;

  final stmt = ParsedStatement(kind)..institution = institution;
  final signed = <int>[]; // +credit / -debit, in file order
  final balances = <int?>[];
  var skipped = 0;
  for (final r in data) {
    if (r.every((c) => c.trim().isEmpty)) continue;
    final d = parseDateCell(cell(r, columns.date), dayFirst: dayFirst);
    if (d == null) {
      skipped++;
      continue;
    }
    final desc = cell(r, columns.description);
    if (RegExp(
      r'^(opening|closing|brought forward|carried forward|total)\b',
      caseSensitive: false,
    ).hasMatch(desc)) {
      continue;
    }
    int? minor;
    Direction? dir;
    final dr = columns.debit == null
        ? null
        : parseAmountMinor(cell(r, columns.debit));
    final cr = columns.credit == null
        ? null
        : parseAmountMinor(cell(r, columns.credit));
    if (dr != null && dr != 0) {
      minor = dr.abs();
      dir = Direction.debit;
    } else if (cr != null && cr != 0) {
      minor = cr.abs();
      dir = Direction.credit;
    } else if (columns.amount != null) {
      var raw = cell(r, columns.amount);
      final suffix = _suffixDrCr.firstMatch(raw)?.group(1)?.toLowerCase();
      raw = raw.replaceAll(_suffixDrCr, '');
      final a = parseAmountMinor(raw);
      if (a != null && a != 0) {
        minor = a.abs();
        final t = cell(r, columns.type).toLowerCase();
        if (suffix != null) {
          dir = suffix == 'dr' ? Direction.debit : Direction.credit;
        } else if (RegExp(r'^(dr|debit|d|withdrawal)$').hasMatch(t)) {
          dir = Direction.debit;
        } else if (RegExp(r'^(cr|credit|c|deposit)$').hasMatch(t)) {
          dir = Direction.credit;
        } else if (a < 0) {
          dir = positiveIsDebit ? Direction.credit : Direction.debit;
        } else {
          dir = positiveIsDebit ? Direction.debit : Direction.credit;
        }
      }
    }
    if (minor == null || dir == null) {
      skipped++;
      continue;
    }
    final ccy = cell(r, columns.currency).toUpperCase();
    if (RegExp(r'^[A-Z]{3}$').hasMatch(ccy) && stmt.lines.isEmpty)
      stmt.currency = ccy;
    stmt.lines.add(
      StatementLine(
        postedOn: CalDate(d.year, d.month, d.day),
        description: desc.isEmpty ? 'Transaction' : desc,
        amountMinor: minor,
        direction: dir,
      ),
    );
    signed.add(dir == Direction.credit ? minor : -minor);
    final b = columns.balance == null
        ? null
        : parseAmountMinor(cell(r, columns.balance));
    balances.add(b);
  }
  if (stmt.lines.isEmpty) return null;
  if (skipped > 0)
    stmt.warnings.add(
      '$skipped row${skipped == 1 ? '' : 's'} without a date or amount were skipped',
    );

  final dates = [for (final l in stmt.lines) l.postedOn]..sort();
  stmt.periodStart = dates.first;
  stmt.periodEnd = dates.last;
  stmt.parser = '${institution ?? 'generic'}:table';

  // Balances: only for accounts, where the running balance chains line to line.
  if (kind == StatementKind.bankAccount &&
      balances.every((b) => b != null) &&
      balances.length > 1) {
    bool chains(bool newestFirst) {
      var ok = 0;
      for (var i = 1; i < balances.length; i++) {
        final cur = newestFirst ? i - 1 : i;
        final prev = newestFirst ? i : i - 1;
        if (balances[prev]! + signed[cur] == balances[cur]) ok++;
      }
      return ok >= (balances.length - 1) * 0.8;
    }

    if (chains(false)) {
      stmt.openingMinor = balances.first! - signed.first;
      stmt.closingMinor = balances.last;
    } else if (chains(true)) {
      stmt.openingMinor = balances.last! - signed.last;
      stmt.closingMinor = balances.first;
    }
  }
  return stmt;
}

/// Reads a CSV/Excel table: columns found from the header row. Throws
/// [StatementImportException] (unrecognisedLayout, with the rows) when they
/// cannot be found, or when the rows hold no transactions.
ParsedStatement readStatementTable(
  List<List<String>> rows, {
  String? institution,
}) {
  final nonEmpty = rows
      .where((r) => r.any((c) => c.trim().isNotEmpty))
      .toList();
  if (nonEmpty.isEmpty) throw StatementImportException.empty;
  final cols = detectColumns(rows);
  final parsed = cols == null
      ? null
      : parseStatementTable(rows, cols, institution: institution);
  if (parsed != null) return parsed;
  throw StatementImportException(
    StatementProblem.unrecognisedLayout,
    'Pulse could not tell which columns hold the date, description and '
    'amount.',
    nextStep: 'Pick them yourself once and Pulse reads the rest.',
    rows: rows,
    institution: institution,
  );
}

/// First rows of a table for the column-mapping sheet (cells clipped).
List<List<String>> previewRows(List<List<String>> rows, {int max = 6}) => [
  for (final r
      in rows.where((r) => r.any((c) => c.trim().isNotEmpty)).take(max))
    [for (final c in r) c.length > 24 ? '${c.substring(0, 24)}…' : c],
];
