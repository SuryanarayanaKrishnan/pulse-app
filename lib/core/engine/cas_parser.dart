/// Reads the text of a CAMS / KFintech consolidated account statement (CAS)
/// into folios, schemes, units, NAV, valuation and transactions. Pure Dart,
/// no I/O: the PDF is opened and its text extracted elsewhere, on the phone.
///
/// Layout handled (the "detailed" statement, as the PDF text comes out):
///
///     Consolidated Account Statement
///     01-Apr-2023 To 26-Nov-2026
///     Folio No: 1234567 / 89     PAN: ABCDE1234F   KYC: OK  PAN: OK
///     Example Mutual Fund
///     EXFC-Example Flexi Cap Fund - Direct Plan - Growth (Advisor: DIRECT) ISIN: INF000A01AB1 (Demat) Registrar : CAMS
///     Opening Unit Balance: 0.000
///     05-Jan-2024 Systematic Investment Purchase 5,000.00 25.123 199.0160 25.123
///     10-Mar-2024 Redemption (2,000.00) (9.500) 210.5263 40.423
///     Closing Unit Balance: 40.423 NAV on 31-Mar-2024: INR 215.1000 Total Cost Value: 8,000.00 Market Value on 31-Mar-2024: INR 8,695.19
///
/// Privacy: the PAN, email, name and address printed on the statement are
/// never read into the result. Anything that does not fit the layout is
/// skipped and reported in [CasStatement.warnings] instead of being guessed.
library;

enum CasTxnKind {
  purchase,
  sip,
  redemption,
  switchIn,
  switchOut,
  dividendReinvest,
  dividendPayout,
  other,
}

class CasTxn {
  const CasTxn({
    required this.date,
    required this.kind,
    required this.description,
    required this.amountMinor,
    required this.units,
    this.nav,
    this.balance,
  });

  /// `yyyy-MM-dd`.
  final String date;
  final CasTxnKind kind;
  final String description;

  /// Rupees as paise; negative for money coming back to the investor.
  final int amountMinor;

  /// Negative for redemptions and switch-outs.
  final double units;
  final double? nav, balance;
}

class CasScheme {
  CasScheme({
    required this.folio,
    this.amc,
    required this.name,
    this.isin,
    this.registrar,
    this.openingUnits,
    this.closingUnits,
    this.nav,
    this.navDate,
    this.costMinor,
    this.valueMinor,
    List<CasTxn>? txns,
  }) : txns = txns ?? [];

  final String folio, name;
  final String? amc, isin, registrar;
  double? openingUnits, closingUnits, nav;

  /// `yyyy-MM-dd` of [nav].
  String? navDate;

  /// Total cost value and market value printed on the statement, in paise.
  int? costMinor, valueMinor;
  final List<CasTxn> txns;

  /// Units held: the printed closing balance, else opening plus transactions.
  double get units =>
      closingUnits ??
      ((openingUnits ?? 0) + txns.fold<double>(0, (a, t) => a + t.units));

  /// Units came from adding transactions up, or opening + transactions does
  /// not reach the closing balance (a partial statement).
  bool get unitsApproximate {
    final c = closingUnits;
    if (c == null) return true;
    final o = openingUnits;
    if (o == null) return false;
    return ((o + txns.fold<double>(0, (a, t) => a + t.units)) - c).abs() > 0.01;
  }

  double? get avgCostNav {
    final c = costMinor, u = units;
    return c == null || c <= 0 || u <= 0 ? null : c / 100 / u;
  }
}

class CasStatement {
  const CasStatement({
    required this.schemes,
    this.periodFrom,
    this.periodTo,
    this.warnings = const [],
    this.kind = CasKind.mutualFund,
  });
  final List<CasScheme> schemes;
  final String? periodFrom, periodTo;
  final List<String> warnings;
  final CasKind kind;
  bool get isEmpty => schemes.isEmpty;
}

/// What the text turned out to be.
enum CasKind { mutualFund, demat, unknown }

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
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

const _num = r'\(?-?[\d,]+(?:\.\d+)?\)?';
const _date = r'\d{1,2}-[A-Za-z]{3}-\d{4}';
final _txnRe = RegExp(
  '^($_date)\\s+(.+?)\\s+($_num)\\s+($_num)\\s+($_num)\\s+($_num)\\s*\$',
);
final _folioRe = RegExp(
  r'Folio\s*No\s*:\s*([A-Za-z0-9/ ]+?)(?:\s+PAN\b|\s+KYC\b|\s{2,}|$)',
  caseSensitive: false,
);
final _isinRe = RegExp(r'ISIN\s*:\s*(INF[A-Z0-9]{9})', caseSensitive: false);
final _closingRe = RegExp(
  r'Closing\s+Unit\s+Balance\s*:\s*([\d,]+(?:\.\d+)?)',
  caseSensitive: false,
);
final _openingRe = RegExp(
  r'Opening\s+Unit\s+Balance\s*:\s*([\d,]+(?:\.\d+)?)',
  caseSensitive: false,
);
final _navRe = RegExp(
  'NAV\\s+on\\s+($_date)\\s*:\\s*(?:INR|Rs\\.?)?\\s*([\\d,]+(?:\\.\\d+)?)',
  caseSensitive: false,
);
final _costRe = RegExp(
  r'Total\s+Cost\s+Value\s*:\s*(?:INR|Rs\.?)?\s*([\d,]+(?:\.\d+)?)',
  caseSensitive: false,
);
final _valueRe = RegExp(
  'Market\\s+Value\\s+on\\s+$_date\\s*:\\s*(?:INR|Rs\\.?)?\\s*([\\d,]+(?:\\.\\d+)?)',
  caseSensitive: false,
);
final _periodRe = RegExp('($_date)\\s+To\\s+($_date)', caseSensitive: false);
final _schemeStartRe = RegExp(r'^[A-Za-z0-9]{2,12}\s*-\s*\S');

String? _iso(String raw) {
  final m = RegExp(r'^(\d{1,2})-([A-Za-z]{3})-(\d{4})$').firstMatch(raw.trim());
  final mo = m == null ? null : _months[m[2]!.toLowerCase()];
  if (m == null || mo == null) return null;
  return '${m[3]}-${mo.toString().padLeft(2, '0')}-${int.parse(m[1]!).toString().padLeft(2, '0')}';
}

double _n(String raw) {
  final neg = raw.startsWith('(') || raw.startsWith('-');
  final v = double.parse(raw.replaceAll(RegExp(r'[()\-,]'), ''));
  return neg ? -v : v;
}

int _paise(double rupees) => (rupees * 100).round();

CasTxnKind classifyCasTxn(String description) {
  final d = description.toLowerCase();
  if (d.contains('switch'))
    return d.contains('out') ? CasTxnKind.switchOut : CasTxnKind.switchIn;
  if (d.contains('redemption') || d.contains('redeem'))
    return CasTxnKind.redemption;
  if (d.contains('dividend') || d.contains('idcw')) {
    return d.contains('reinvest')
        ? CasTxnKind.dividendReinvest
        : CasTxnKind.dividendPayout;
  }
  if (d.contains('sip') || d.contains('systematic')) return CasTxnKind.sip;
  if (d.contains('purchase') || d.contains('subscription'))
    return CasTxnKind.purchase;
  return CasTxnKind.other;
}

String _cleanName(String line) {
  var n = line.split(RegExp(r'ISIN\s*:', caseSensitive: false)).first;
  n = n.replaceAll(
    RegExp(r'\(\s*Advisor\s*:[^)]*\)', caseSensitive: false),
    '',
  );
  n = n.replaceFirst(RegExp(r'^\s*[A-Za-z0-9]{2,12}\s*-(?=\S)'), '');
  return n
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'^-+|-+$'), '')
      .trim();
}

/// True for the lines that look like a scheme heading (code, name, ISIN).
bool _isSchemeLine(String l) => _isinRe.hasMatch(l);

CasStatement parseCas(String text) {
  final warnings = <String>[];
  final schemes = <CasScheme>[];
  String? folio, amc, from, to;
  CasScheme? cur;
  String? pending; // a scheme name that wrapped onto a second line
  var sawDemat = false;

  final lines = text.split(RegExp(r'\r?\n'));
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (from == null) {
      final p = _periodRe.firstMatch(line);
      if (p != null) {
        from = _iso(p[1]!);
        to = _iso(p[2]!);
      }
    }
    if (RegExp(r'ISIN\s*:\s*INE', caseSensitive: false).hasMatch(line) ||
        RegExp(r'\b(NSDL|CDSL)\b').hasMatch(line) &&
            RegExp(r'Demat|BO ID|DP ID', caseSensitive: false).hasMatch(line)) {
      sawDemat = true;
    }
    final fm = _folioRe.firstMatch(line);
    if (fm != null) {
      folio = fm[1]!.replaceAll(RegExp(r'\s+'), '');
      cur = null;
      pending = null;
      continue;
    }
    if (folio == null) continue;
    if (RegExp(r'mutual fund\s*$', caseSensitive: false).hasMatch(line) &&
        !_isSchemeLine(line)) {
      amc = line;
      continue;
    }
    String? schemeLine;
    if (_isSchemeLine(line)) {
      schemeLine = pending == null ? line : '$pending $line';
      pending = null;
    } else if (pending != null) {
      pending = '$pending $line';
      if (pending.length > 300) pending = null;
      continue;
    } else if (_schemeStartRe.hasMatch(line) &&
        !RegExp('^$_date').hasMatch(line) &&
        (!line.contains(':') || line.contains('Advisor'))) {
      pending = line; // wrapped heading: the ISIN comes on the next line
      continue;
    }
    if (schemeLine != null) {
      cur = CasScheme(
        folio: folio,
        amc: amc,
        name: _cleanName(schemeLine),
        isin: _isinRe.firstMatch(schemeLine)![1]!.toUpperCase(),
        registrar: RegExp(
          r'Registrar\s*:\s*(\w+)',
          caseSensitive: false,
        ).firstMatch(schemeLine)?[1]?.toUpperCase(),
      );
      schemes.add(cur);
      continue;
    }
    final s = cur;
    if (s == null) continue;
    final tm = _txnRe.firstMatch(line);
    if (tm != null) {
      try {
        final kind = classifyCasTxn(tm[2]!);
        var amount = _n(tm[3]!), units = _n(tm[4]!);
        if (kind == CasTxnKind.redemption || kind == CasTxnKind.switchOut) {
          amount = -amount.abs();
          units = -units.abs();
        }
        s.txns.add(
          CasTxn(
            date: _iso(tm[1]!)!,
            kind: kind,
            description: tm[2]!.trim(),
            amountMinor: _paise(amount),
            units: units,
            nav: _n(tm[5]!),
            balance: _n(tm[6]!),
          ),
        );
      } on Object {
        warnings.add('Skipped an unreadable line in ${s.name}');
      }
      continue;
    }
    // Stamp duty, address changes and other date lines carry no units.
    if (RegExp('^$_date\\b').hasMatch(line)) {
      if (!RegExp(
        r'stamp duty|\*\*\*|address|nominee|kyc|updated',
        caseSensitive: false,
      ).hasMatch(line)) {
        warnings.add(
          'Skipped a line in ${s.name} that did not fit the statement layout',
        );
      }
      continue;
    }
    final o = _openingRe.firstMatch(line);
    if (o != null) s.openingUnits = _n(o[1]!);
    final c = _closingRe.firstMatch(line);
    if (c != null) s.closingUnits = _n(c[1]!);
    final nv = _navRe.firstMatch(line);
    if (nv != null) {
      s.navDate = _iso(nv[1]!);
      s.nav = _n(nv[2]!);
    }
    final co = _costRe.firstMatch(line);
    if (co != null) s.costMinor = _paise(_n(co[1]!));
    final mv = _valueRe.firstMatch(line);
    if (mv != null) s.valueMinor = _paise(_n(mv[1]!));
  }

  for (final s in schemes) {
    if (s.closingUnits == null)
      warnings.add(
        'No closing balance for ${s.name}: units were added up from the transactions',
      );
  }
  final kind = schemes.isNotEmpty
      ? CasKind.mutualFund
      : sawDemat
      ? CasKind.demat
      : CasKind.unknown;
  if (schemes.isEmpty) {
    warnings.add(
      sawDemat
          ? 'This looks like a demat (NSDL/CDSL) statement, not a mutual fund CAS'
          : 'No schemes recognised: is this a detailed CAMS/KFintech CAS?',
    );
  }
  return CasStatement(
    schemes: schemes,
    periodFrom: from,
    periodTo: to,
    warnings: warnings,
    kind: kind,
  );
}

// ---- SIP hints ------------------------------------------------------------------

class SipHint {
  const SipHint({
    required this.amountMinor,
    required this.day,
    required this.count,
    required this.labelled,
  });

  /// Monthly instalment in paise.
  final int amountMinor;

  /// Usual debit day of the month.
  final int day;

  /// Instalments seen on the statement.
  final int count;

  /// The statement itself calls them SIP purchases; otherwise inferred from a
  /// monthly pattern, so approximate.
  final bool labelled;
  bool get approximate => !labelled;
}

/// A running SIP: at least [minInstalments] similar purchases roughly a month
/// apart, the latest within 45 days of the statement's end. A hint, never a
/// fact: the UI asks before saving it.
SipHint? detectSip(CasScheme s, {String? asOf, int minInstalments = 3}) {
  if (s.units <= 0) return null;
  final labelled = s.txns
      .where((t) => t.kind == CasTxnKind.sip && t.units > 0)
      .toList();
  final buys = s.txns
      .where(
        (t) =>
            (t.kind == CasTxnKind.sip || t.kind == CasTxnKind.purchase) &&
            t.units > 0,
      )
      .toList();
  final isLabelled = labelled.length >= 2;
  final pool = isLabelled ? labelled : buys;
  if (pool.length < (isLabelled ? 2 : minInstalments)) return null;
  pool.sort((a, b) => a.date.compareTo(b.date));
  final last = pool.last;
  final run = <CasTxn>[last];
  for (var i = pool.length - 2; i >= 0; i--) {
    final t = pool[i];
    final gap = DateTime.parse(run.last.date)
        .difference(DateTime.parse(t.date))
        .inDays;
    final sameAmt =
        (t.amountMinor - last.amountMinor).abs() <= last.amountMinor * 0.01;
    if (gap < 24 || gap > 38 || !sameAmt) break;
    run.add(t);
  }
  if (run.length < (isLabelled ? 2 : minInstalments)) return null;
  final end = asOf ?? s.navDate ?? last.date;
  if (DateTime.parse(end).difference(DateTime.parse(last.date)).inDays > 45)
    return null;
  final days = [for (final t in run) int.parse(t.date.substring(8))]..sort();
  return SipHint(
    amountMinor: last.amountMinor,
    day: days[days.length ~/ 2],
    count: run.length,
    labelled: isLabelled,
  );
}
