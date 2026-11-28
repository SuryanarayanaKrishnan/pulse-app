/// Reads a budget someone already keeps in Excel, Google Sheets or CSV, so
/// none of it is lost on the way in. Pure Dart: bytes or text in, a plan out.
///
/// Three shapes are recognised, and one workbook can hold several:
///  * a monthly grid: a row per item, a column per month, optionally a Type
///    column with Budget / Actual rows;
///  * a ledger: a row per payment with a date and an amount;
///  * a flat list: a category and an amount, taken as the monthly budget.
///
/// Nothing is guessed silently: every label the sheet uses is returned with
/// the Pulse category it maps to (or none), for the user to confirm.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

// ---- CSV ---------------------------------------------------------------------

/// Splits CSV text into rows. Handles quotes, escaped quotes, CRLF, a BOM and
/// a `,` `;` or tab delimiter (picked from the first line).
List<List<String>> parseCsv(String text) {
  var s = text.startsWith('﻿') ? text.substring(1) : text;
  s = s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final firstLine = s.split('\n').first;
  var delim = ',';
  var best = -1;
  for (final d in [',', ';', '\t']) {
    final n = d.allMatches(firstLine).length;
    if (n > best) {
      best = n;
      delim = d;
    }
  }
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < s.length && s[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == delim) {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\n') {
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

// ---- XLSX --------------------------------------------------------------------

/// Sheets of an .xlsx workbook, by name, as text cells. Formulas arrive as
/// their last calculated value. Hidden sheets are skipped. Throws
/// [FormatException] when the bytes are not a workbook.
Map<String, List<List<String>>> readXlsx(Uint8List bytes) {
  final Archive zip;
  try {
    zip = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('That file is not an Excel workbook.');
  }
  String? read(String path) {
    final f = zip.findFile(path);
    if (f == null) return null;
    return utf8.decode(f.content as List<int>, allowMalformed: true);
  }

  final wb = read('xl/workbook.xml');
  if (wb == null)
    throw const FormatException('That file is not an Excel workbook.');
  final rels = read('xl/_rels/workbook.xml.rels');
  final relTarget = <String, String>{};
  if (rels != null) {
    for (final r in XmlDocument.parse(rels).findAllElements('Relationship')) {
      relTarget[r.getAttribute('Id') ?? ''] = r.getAttribute('Target') ?? '';
    }
  }
  final shared = <String>[];
  final ss = read('xl/sharedStrings.xml');
  if (ss != null) {
    for (final si in XmlDocument.parse(ss).findAllElements('si')) {
      shared.add(si.findAllElements('t').map((t) => t.innerText).join());
    }
  }
  final out = <String, List<List<String>>>{};
  var n = 0;
  for (final s in XmlDocument.parse(wb).findAllElements('sheet')) {
    n++;
    if ((s.getAttribute('state') ?? 'visible') != 'visible') continue;
    final name = s.getAttribute('name') ?? 'Sheet$n';
    final rid = s.attributes
        .where((a) => a.name.local == 'id')
        .firstOrNull
        ?.value;
    var target = rid == null ? null : relTarget[rid];
    target ??= 'worksheets/sheet$n.xml';
    target = target.startsWith('/') ? target.substring(1) : 'xl/$target';
    final xml = read(target);
    if (xml == null) continue;
    out[name] = _sheetRows(xml, shared);
  }
  return out;
}

int _colIndex(String ref) {
  var n = 0;
  for (final c in ref.codeUnits) {
    if (c >= 65 && c <= 90) {
      n = n * 26 + (c - 64);
    } else if (c >= 97 && c <= 122) {
      n = n * 26 + (c - 96);
    } else {
      break;
    }
  }
  return n - 1;
}

List<List<String>> _sheetRows(String xml, List<String> shared) {
  final rows = <List<String>>[];
  for (final r in XmlDocument.parse(xml).findAllElements('row')) {
    final idx = int.tryParse(r.getAttribute('r') ?? '');
    final cells = <int, String>{};
    var next = 0;
    for (final c in r.findElements('c')) {
      final ref = c.getAttribute('r');
      final col = ref == null ? next : _colIndex(ref);
      next = col + 1;
      final t = c.getAttribute('t');
      final v = c.getElement('v')?.innerText;
      String text;
      if (t == 's') {
        final k = int.tryParse(v ?? '');
        text = k != null && k < shared.length ? shared[k] : '';
      } else if (t == 'inlineStr') {
        text = c.findAllElements('t').map((e) => e.innerText).join();
      } else {
        text = v ?? '';
      }
      if (text.isNotEmpty) cells[col] = text;
    }
    final width = cells.isEmpty
        ? 0
        : cells.keys.reduce((a, b) => a > b ? a : b) + 1;
    final row = [for (var i = 0; i < width; i++) cells[i] ?? ''];
    if (idx != null) {
      while (rows.length < idx - 1) {
        rows.add(const []);
      }
    }
    rows.add(row);
  }
  return rows;
}

// ---- Parsing cells -------------------------------------------------------------

/// A money cell in fils: "2,200.00", "AED 1,200", "(120)", "-45", "1.234,50".
/// Null when the cell is not a number.
int? parseAmountMinor(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  var neg = false;
  if (s.startsWith('(') && s.endsWith(')')) {
    neg = true;
    s = s.substring(1, s.length - 1);
  }
  s = s
      .replaceAll(RegExp(r'aed|dhs?|د\.إ', caseSensitive: false), '')
      .replaceAll(RegExp(r'[\s\u00A0]'), '');
  if (s.startsWith('-')) {
    neg = true;
    s = s.substring(1);
  }
  if (s.isEmpty || !RegExp(r'^[0-9.,]+$').hasMatch(s)) return null;
  final lastDot = s.lastIndexOf('.'), lastComma = s.lastIndexOf(',');
  if (lastDot >= 0 && lastComma >= 0) {
    // Whichever comes last is the decimal mark.
    if (lastDot > lastComma) {
      s = s.replaceAll(',', '');
    } else {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    }
  } else if (lastComma >= 0) {
    final after = s.length - lastComma - 1;
    final single = s.indexOf(',') == lastComma;
    // "1,234" and "1,234,567" are thousands; "12,50" is a decimal comma.
    s = (!single || (after == 3 && lastComma <= 3))
        ? s.replaceAll(',', '')
        : s.replaceAll(',', '.');
  } else if (lastDot >= 0 && s.indexOf('.') != lastDot) {
    s = s.replaceAll('.', '');
  }
  final d = double.tryParse(s);
  if (d == null) return null;
  final minor = (d * 100).round();
  return neg ? -minor : minor;
}

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'sept': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

int? _monthOfName(String s) {
  final t = s.trim().toLowerCase().replaceAll('.', '');
  if (t.isEmpty) return null;
  final m =
      _months[t.length > 3 ? t.substring(0, t.startsWith('sept') ? 4 : 3) : t];
  if (m == null) return null;
  // Only a month name on its own, or the full name: not "marketing".
  const full = [
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
  ];
  return (t.length <= 4 || full.contains(t)) ? m : null;
}

/// A date cell. [dayFirst] settles 03/04/2026. Understands ISO, d/m/y,
/// "5 Aug 2026", "Aug 5, 2026", a trailing time, and Excel serial numbers.
DateTime? parseDateCell(String raw, {bool dayFirst = true}) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final serial = double.tryParse(s);
  if (serial != null) {
    if (serial < 36526 || serial > 73050) return null; // 2000..2099
    final d = DateTime.utc(1899, 12, 30).add(Duration(days: serial.floor()));
    return DateTime(d.year, d.month, d.day);
  }
  var m = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(s);
  if (m != null)
    return _ymd(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  m = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})').firstMatch(s);
  if (m != null) {
    final a = int.parse(m[1]!), b = int.parse(m[2]!);
    var y = int.parse(m[3]!);
    if (y < 100) y += 2000;
    return dayFirst ? _ymd(y, b, a) : _ymd(y, a, b);
  }
  m = RegExp(r'^(\d{1,2})[\s-]+([A-Za-z]{3,9})\.?,?[\s-]+(\d{2,4})')
      .firstMatch(s);
  if (m != null) {
    final mo = _monthOfName(m[2]!);
    var y = int.parse(m[3]!);
    if (y < 100) y += 2000;
    if (mo != null) return _ymd(y, mo, int.parse(m[1]!));
  }
  m = RegExp(r'^([A-Za-z]{3,9})\.?\s+(\d{1,2}),?\s+(\d{2,4})').firstMatch(s);
  if (m != null) {
    final mo = _monthOfName(m[1]!);
    var y = int.parse(m[3]!);
    if (y < 100) y += 2000;
    if (mo != null) return _ymd(y, mo, int.parse(m[2]!));
  }
  return null;
}

DateTime? _ymd(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31 || y < 2000 || y > 2100) return null;
  final t = DateTime(y, m, d);
  return t.month == m ? t : null;
}

/// True when most ambiguous dates in [cells] read as day/month. Looks for a
/// first part above 12 (day first) or a second part above 12 (month first);
/// day first when nothing decides, which is the UAE norm.
bool detectDayFirst(Iterable<String> cells) {
  var dayFirst = 0, monthFirst = 0;
  final re = RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})');
  for (final c in cells) {
    final m = re.firstMatch(c.trim());
    if (m == null) continue;
    final a = int.parse(m[1]!), b = int.parse(m[2]!);
    if (a > 12 && b <= 12) dayFirst++;
    if (b > 12 && a <= 12) monthFirst++;
  }
  return monthFirst <= dayFirst;
}

// ---- Matching labels to Pulse categories ------------------------------------------

/// Pulse default category id → words that mean it. Whole-word, lower case.
const _aliases = <String, List<String>>{
  'salary': ['salary', 'wages', 'paycheck', 'payroll', 'income'],
  'other_income': [
    'bonus',
    'freelance',
    'side income',
    'commission',
    'other income',
    'rental income',
    'interest',
  ],
  'groceries': [
    'groceries',
    'grocery',
    'supermarket',
    'carrefour',
    'lulu',
    'spinneys',
    'waitrose',
    'kibsons',
    'food shopping',
  ],
  'dining': [
    'restaurants',
    'restaurant',
    'dining',
    'eating out',
    'takeaway',
    'delivery',
    'talabat',
    'deliveroo',
    'cafe',
    'coffee',
    'food',
  ],
  'transport': [
    'transport',
    'fuel',
    'petrol',
    'gas station',
    'salik',
    'parking',
    'taxi',
    'uber',
    'careem',
    'nol',
    'metro',
    'charging',
    'ev charging',
    'car maintenance',
    'car wash',
    'cleaning',
    'service',
  ],
  'car_loan': [
    'car loan',
    'auto loan',
    'car finance',
    'car emi',
    'vehicle loan',
    'car installment',
    'car insurance',
  ],
  'home_loan': ['mortgage', 'home loan', 'housing loan'],
  'rent': [
    'rent',
    'housing',
    'ejari',
    'accommodation',
    'maintenance fee',
    'service charge',
  ],
  'utilities': [
    'utilities',
    'dewa',
    'sewa',
    'addc',
    'aadc',
    'electricity',
    'water',
    'gas',
    'empower',
    'district cooling',
    'chiller',
  ],
  'telecom': [
    'telecom',
    'internet',
    'wifi',
    'etisalat',
    'e&',
    'du',
    'cell phone',
    'mobile',
    'phone',
    'recharge',
    'recharges',
    'mis recharges',
  ],
  'fixed_expenses': [
    'subscriptions',
    'subscription',
    'gym',
    'membership',
    'insurance',
    'netflix',
    'spotify',
    'fixed',
  ],
  'education': [
    'education',
    'school',
    'tuition',
    'nursery',
    'university',
    'school fees',
    'courses',
  ],
  'health': [
    'health',
    'medical',
    'doctor',
    'pharmacy',
    'dental',
    'clinic',
    'hospital',
    'protein',
    'supplements',
    'haircut',
    'salon',
    'grooming',
  ],
  'shopping': [
    'shopping',
    'clothes',
    'clothing',
    'amazon',
    'noon',
    'gifts',
    'gift',
    'electronics',
    'home goods',
    'furniture',
  ],
  'travel': [
    'travel',
    'trips',
    'trip',
    'flights',
    'holiday',
    'vacation',
    'hotel',
    'airfare',
  ],
  'entertainment': [
    'entertainment',
    'fun',
    'movies',
    'cinema',
    'activities',
    'overall fun',
    'leisure',
    'hobbies',
    'outings',
  ],
  'family': [
    'family',
    'remittance',
    'remittances',
    'parents',
    'money home',
    'support',
  ],
  'savings': [
    'savings',
    'investing',
    'investments',
    'investment',
    'sip',
    'emergency fund',
  ],
  'fees': ['fees', 'bank charges', 'charges', 'fines', 'interest charges'],
  'other': [
    'other',
    'misc',
    'miscellaneous',
    'others',
    'uncategorised',
    'uncategorized',
  ],
};

/// Pulse default ids and their display names, for matching a label that is
/// already called what Pulse calls it ("Dining & Delivery").
const _defaultNames = <String, String>{
  'salary': 'Salary',
  'other_income': 'Other Income',
  'groceries': 'Groceries',
  'dining': 'Dining & Delivery',
  'transport': 'Transport & Fuel',
  'car_loan': 'Car Loan',
  'home_loan': 'Home Loan / Mortgage',
  'rent': 'Rent & Housing',
  'utilities': 'Utilities',
  'telecom': 'Telecom & Internet',
  'fixed_expenses': 'Fixed Expenses',
  'education': 'Education Fees',
  'health': 'Health',
  'shopping': 'Shopping',
  'travel': 'Travel',
  'entertainment': 'Entertainment',
  'family': 'Family & Remittances',
  'savings': 'Savings & Investments',
  'fees': 'Fees & Charges',
  'other': 'Other',
};

String _norm(String s) => s
    .toLowerCase()
    .replaceAll('&', ' and ')
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

class CategoryMatch {
  const CategoryMatch(this.id, {required this.exact});
  final String id;

  /// The label is the category's own name or a listed alias, as opposed to
  /// containing one of its words.
  final bool exact;
}

/// The default category a sheet label most likely means; null when none does.
/// The longest matching alias wins, so "Car loan" is not Transport.
CategoryMatch? matchCategory(String label, {bool income = false}) {
  final m = _match(label);
  if (m == null)
    return income ? const CategoryMatch('other_income', exact: false) : null;
  // Money coming in never lands in an expense category.
  if (income && m.id != 'salary' && m.id != 'other_income')
    return const CategoryMatch('other_income', exact: false);
  return m;
}

CategoryMatch? _match(String label) {
  final n = _norm(label);
  if (n.isEmpty) return null;
  for (final e in _defaultNames.entries) {
    if (_norm(e.value) == n) return CategoryMatch(e.key, exact: true);
  }
  String? bestId;
  var bestLen = 0;
  var exact = false;
  _aliases.forEach((id, words) {
    for (final w in words) {
      final a = _norm(w);
      if (a.isEmpty) continue;
      final isExact = a == n;
      final contained =
          isExact || RegExp('(^| )${RegExp.escape(a)}( |\$)').hasMatch(n);
      if (!contained) continue;
      final score = a.length + (isExact ? 100 : 0);
      if (score > bestLen) {
        bestLen = score;
        bestId = id;
        exact = isExact;
      }
    }
  });
  if (bestId == null) return null;
  return CategoryMatch(bestId!, exact: exact);
}

// ---- Analysis --------------------------------------------------------------------

enum SheetKind { monthlyGrid, ledger, flatList, unknown }

/// One line item the sheet uses, with what it said about it.
class SheetLabel {
  SheetLabel(this.label, {this.group = '', this.isIncome = false});
  final String label;

  /// The sheet's own heading it sat under (FIXED, PERSONAL...).
  String group;
  bool isIncome;

  /// Budget per month, `yyyy-MM-01` → fils.
  final Map<String, int> budget = {};

  /// Spend per month from the sheet's Actual rows, same keys.
  final Map<String, int> actual = {};
  int txCount = 0;
  int txTotalMinor = 0;
}

class SheetTx {
  const SheetTx({
    required this.date,
    required this.label,
    required this.note,
    required this.minor,
    required this.isIncome,
  });
  final DateTime date;
  final String label;
  final String note;
  final int minor;
  final bool isIncome;
}

class SheetAnalysis {
  SheetAnalysis();
  final Map<String, SheetLabel> labels = {};
  final List<SheetTx> transactions = [];
  final List<String> warnings = [];
  final List<String> sheetsRead = [];
  final Set<SheetKind> kinds = {};

  /// Months of dated history found (ledger or Actual rows).
  int get historyMonths {
    final m = <String>{};
    for (final t in transactions) {
      m.add('${t.date.year}-${t.date.month}');
    }
    if (m.isEmpty) {
      for (final l in labels.values) {
        m.addAll(l.actual.keys.where((k) => (l.actual[k] ?? 0) > 0));
      }
    }
    return m.length;
  }

  bool get isEmpty => labels.isEmpty && transactions.isEmpty;
  List<SheetLabel> get orderedLabels => labels.values.toList();
}

String monthKey(int y, int m) =>
    '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-01';

bool _isIncomeText(String s) => RegExp(
  r'\b(income|salary|salaries|earnings?|wages?|bonus)\b',
  caseSensitive: false,
).hasMatch(s);

final _totalRow = RegExp(
  r'^(grand\s+)?(total|sub\s?total|net|balance|surplus|deficit|difference|remaining|left)\b',
  caseSensitive: false,
);

/// Reads every sheet of [sheets] and merges what it finds. [year] fills in
/// grids that do not say which year they are for.
SheetAnalysis analyzeSheets(
  Map<String, List<List<String>>> sheets, {
  int? year,
}) {
  final out = SheetAnalysis();
  final fallbackYear = year ?? DateTime.now().year;
  // Read ledgers first: their payments take precedence over a grid's Actual
  // rows, which are usually just the ledger summed.
  final results = <String, (SheetKind, Object?)>{};
  sheets.forEach((name, rows) {
    final ledger = _readLedger(rows);
    if (ledger != null) {
      results[name] = (SheetKind.ledger, ledger);
      return;
    }
    final grid = _readGrid(rows, fallbackYear);
    if (grid != null) {
      results[name] = (SheetKind.monthlyGrid, grid);
      return;
    }
    final flat = _readFlat(rows);
    if (flat != null) results[name] = (SheetKind.flatList, flat);
  });
  final hasLedger = results.values.any((r) => r.$1 == SheetKind.ledger);
  results.forEach((name, r) {
    out.kinds.add(r.$1);
    out.sheetsRead.add(name);
    switch (r.$1) {
      case SheetKind.ledger:
        for (final t in (r.$2 as _Ledger).txs) {
          final l = out.labels.putIfAbsent(
            _key(t.label),
            () => SheetLabel(t.label, isIncome: t.isIncome),
          );
          l.txCount++;
          l.txTotalMinor += t.minor;
          out.transactions.add(t);
        }
        out.warnings.addAll((r.$2 as _Ledger).warnings);
      case SheetKind.monthlyGrid:
        final g = r.$2 as _Grid;
        for (final it in g.items) {
          final l = out.labels.putIfAbsent(
            _key(it.label),
            () => SheetLabel(it.label, group: it.group, isIncome: it.isIncome),
          );
          if (l.group.isEmpty) l.group = it.group;
          l.isIncome = l.isIncome || it.isIncome;
          it.budget.forEach((k, v) => l.budget[k] = v);
          if (!hasLedger) it.actual.forEach((k, v) => l.actual[k] = v);
        }
      case SheetKind.flatList:
        final now = DateTime.now();
        for (final it in (r.$2 as _Flat).items) {
          final l = out.labels.putIfAbsent(
            _key(it.label),
            () => SheetLabel(it.label, group: it.group, isIncome: it.isIncome),
          );
          l.budget[monthKey(now.year, now.month)] = it.minor;
        }
      case SheetKind.unknown:
        break;
    }
  });
  if (out.isEmpty) {
    out.warnings.add(
      'We could not find a budget or a list of payments in that file.',
    );
  }
  // An item the ledger knows by a different case/spacing than the grid's
  // label is the same item: merged above through _key.
  return out;
}

String _key(String label) => _norm(label);

/// Convenience for a single CSV: one sheet.
SheetAnalysis analyzeCsv(String text, {int? year}) =>
    analyzeSheets({'Sheet1': parseCsv(text)}, year: year);

// ---- Monthly grid -----------------------------------------------------------------

class _GridItem {
  _GridItem(this.label, this.group, this.isIncome);
  final String label, group;
  final bool isIncome;
  final Map<String, int> budget = {}, actual = {};
}

class _Grid {
  _Grid(this.items);
  final List<_GridItem> items;
}

bool _isBudgetWord(String s) => RegExp(
  r'^(budget|budgeted|planned|plan|target|limit)\b',
  caseSensitive: false,
).hasMatch(s.trim());
bool _isActualWord(String s) => RegExp(
  r'^(actual|actuals|spent|spend|real)\b',
  caseSensitive: false,
).hasMatch(s.trim());

_Grid? _readGrid(List<List<String>> rows, int fallbackYear) {
  // Header: the first of the top rows with three or more month names.
  int? hdr;
  final monthCols = <int, int>{};
  for (var r = 0; r < rows.length && r < 12; r++) {
    final found = <int, int>{};
    for (var c = 0; c < rows[r].length; c++) {
      final m = _monthOfName(rows[r][c]);
      if (m != null) found[c] = m;
    }
    if (found.length >= 3) {
      hdr = r;
      monthCols.addAll(found);
      break;
    }
  }
  if (hdr == null) return null;
  var year = fallbackYear;
  for (var r = 0; r <= hdr; r++) {
    for (final cell in rows[r]) {
      final m = RegExp(r'^\s*(20\d\d)\s*$').firstMatch(cell);
      if (m != null) year = int.parse(m[1]!);
    }
  }
  final firstMonthCol = monthCols.keys.reduce((a, b) => a < b ? a : b);
  // The Type column: left of the months, mostly Budget / Actual.
  int? typeCol;
  for (var c = 0; c < firstMonthCol; c++) {
    var hits = 0, filled = 0;
    for (var r = hdr + 1; r < rows.length; r++) {
      final v = c < rows[r].length ? rows[r][c].trim() : '';
      if (v.isEmpty) continue;
      filled++;
      if (_isBudgetWord(v) || _isActualWord(v)) hits++;
    }
    if (filled > 0 && hits / filled >= 0.6) {
      typeCol = c;
      break;
    }
  }
  final labelCols = [
    for (var c = 0; c < firstMonthCol; c++)
      if (c != typeCol) c,
  ];
  if (labelCols.isEmpty) return null;
  final itemCol = labelCols.last;
  final groupCol = labelCols.length > 1 ? labelCols.first : null;

  String cell(List<String> row, int c) => c < row.length ? row[c].trim() : '';
  final items = <String, _GridItem>{};
  var group = '';
  _GridItem? current;
  for (var r = hdr + 1; r < rows.length; r++) {
    final row = rows[r];
    if (row.every((c) => c.trim().isEmpty)) continue;
    if (groupCol != null && cell(row, groupCol).isNotEmpty)
      group = cell(row, groupCol);
    var label = cell(row, itemCol);
    final type = typeCol == null ? 'budget' : cell(row, typeCol);
    final hasNumbers = monthCols.keys.any(
      (c) => parseAmountMinor(cell(row, c)) != null,
    );
    if (label.isEmpty) {
      // Actual row under a Budget row: same item.
      if (typeCol == null || current == null) continue;
    } else {
      if (_totalRow.hasMatch(label)) {
        current = null;
        continue;
      }
      if (!hasNumbers && typeCol == null && groupCol == null) {
        // A heading row in a one-column layout.
        group = label;
        current = null;
        continue;
      }
      final key = _key(label);
      current = items.putIfAbsent(
        key,
        () => _GridItem(
          label,
          group,
          _isIncomeText(group) || (_isIncomeText(label) && group.isEmpty),
        ),
      );
    }
    final item = current;
    final isActual = typeCol != null && _isActualWord(type);
    final isBudget = typeCol == null || _isBudgetWord(type);
    if (!isActual && !isBudget) continue;
    monthCols.forEach((c, m) {
      final v = parseAmountMinor(cell(row, c));
      if (v == null) return;
      (isActual ? item.actual : item.budget)[monthKey(year, m)] = v.abs();
    });
  }
  final used = items.values
      .where(
        (i) =>
            i.budget.values.any((v) => v > 0) ||
            i.actual.values.any((v) => v > 0),
      )
      .toList();
  return used.isEmpty ? null : _Grid(used);
}

// ---- Ledger -------------------------------------------------------------------------

class _Ledger {
  _Ledger(this.txs, this.warnings);
  final List<SheetTx> txs;
  final List<String> warnings;
}

bool _has(String h, List<String> words) =>
    words.any((w) => RegExp('(^|[^a-z])$w([^a-z]|\$)').hasMatch(h));

_Ledger? _readLedger(List<List<String>> rows) {
  int? hdr;
  var dateCol = -1, amountCol = -1, debitCol = -1, creditCol = -1;
  var itemCol = -1, groupCol = -1, noteCol = -1, typeCol = -1;
  for (var r = 0; r < rows.length && r < 8; r++) {
    final h = [for (final c in rows[r]) c.trim().toLowerCase()];
    int find(List<String> words, {int skip = -1}) {
      for (var i = 0; i < h.length; i++) {
        if (i != skip && _has(h[i], words)) return i;
      }
      return -1;
    }

    final d = find(['date', 'when', 'day', 'posted']);
    final a = find(['amount', 'amt', 'value', 'cost', 'aed', 'price', 'total']);
    final db = find(['debit', 'withdrawal', 'withdrawals', 'paid out']);
    final cr = find(['credit', 'deposit', 'deposits', 'paid in']);
    if (d >= 0 && (a >= 0 || db >= 0 || cr >= 0)) {
      hdr = r;
      dateCol = d;
      amountCol = a;
      debitCol = db;
      creditCol = cr;
      itemCol = find([
        'item',
        'category',
        'description',
        'merchant',
        'payee',
        'name',
        'details',
        'narration',
        'particulars',
      ], skip: d);
      groupCol = find(['group', 'bucket', 'section'], skip: itemCol);
      noteCol = find([
        'comment',
        'comments',
        'note',
        'notes',
        'memo',
        'remarks',
      ], skip: itemCol);
      typeCol = find(['type', 'kind', 'direction']);
      break;
    }
  }
  if (hdr == null || itemCol < 0) return null;
  String cell(List<String> row, int c) =>
      c >= 0 && c < row.length ? row[c].trim() : '';
  final dateCells = [
    for (var r = hdr + 1; r < rows.length; r++) cell(rows[r], dateCol),
  ];
  final dayFirst = detectDayFirst(dateCells);
  final txs = <SheetTx>[];
  var skipped = 0;
  for (var r = hdr + 1; r < rows.length; r++) {
    final row = rows[r];
    final date = parseDateCell(cell(row, dateCol), dayFirst: dayFirst);
    int? minor;
    var income = false;
    if (amountCol >= 0) {
      minor = parseAmountMinor(cell(row, amountCol));
      if (minor != null && minor < 0) minor = -minor;
    }
    if (minor == null || minor == 0) {
      final dv = debitCol >= 0 ? parseAmountMinor(cell(row, debitCol)) : null;
      final cv = creditCol >= 0 ? parseAmountMinor(cell(row, creditCol)) : null;
      if (dv != null && dv != 0) {
        minor = dv.abs();
      } else if (cv != null && cv != 0) {
        minor = cv.abs();
        income = true;
      }
    }
    if (typeCol >= 0 &&
        RegExp(
          r'income|credit|deposit',
          caseSensitive: false,
        ).hasMatch(cell(row, typeCol)))
      income = true;
    final label = cell(row, itemCol);
    if (date == null || minor == null || minor == 0 || label.isEmpty) {
      if (row.any((c) => c.trim().isNotEmpty)) skipped++;
      continue;
    }
    final group = cell(row, groupCol);
    if (_isIncomeText(group)) income = true;
    txs.add(
      SheetTx(
        date: date,
        label: label,
        note: cell(row, noteCol),
        minor: minor,
        isIncome: income,
      ),
    );
  }
  if (txs.isEmpty) return null;
  return _Ledger(txs, [
    if (skipped > 0) '$skipped rows had no date or amount and were left out.',
  ]);
}

// ---- Flat list -------------------------------------------------------------------------

class _FlatItem {
  _FlatItem(this.label, this.group, this.minor, this.isIncome);
  final String label, group;
  final int minor;
  final bool isIncome;
}

class _Flat {
  _Flat(this.items);
  final List<_FlatItem> items;
}

_Flat? _readFlat(List<List<String>> rows) {
  for (var r = 0; r < rows.length && r < 8; r++) {
    final h = [for (final c in rows[r]) c.trim().toLowerCase()];
    final amt = h.indexWhere(
      (x) => _has(x, [
        'budget',
        'amount',
        'monthly',
        'limit',
        'planned',
        'aed',
        'per month',
      ]),
    );
    final cat = h.indexWhere(
      (x) => _has(x, ['category', 'item', 'name', 'expense', 'description']),
    );
    if (amt < 0 || cat < 0 || amt == cat) continue;
    final grp = h.indexWhere((x) => _has(x, ['group', 'type', 'section']));
    final items = <_FlatItem>[];
    for (var i = r + 1; i < rows.length; i++) {
      String cell(int c) =>
          c >= 0 && c < rows[i].length ? rows[i][c].trim() : '';
      final label = cell(cat);
      final v = parseAmountMinor(cell(amt));
      if (label.isEmpty || v == null || v <= 0 || _totalRow.hasMatch(label))
        continue;
      final g = cell(grp);
      items.add(
        _FlatItem(label, g, v, _isIncomeText(g) || _isIncomeText(label)),
      );
    }
    if (items.length >= 2) return _Flat(items);
  }
  return null;
}
