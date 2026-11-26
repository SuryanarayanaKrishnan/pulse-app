/// AMFI's public NAV file (`NAVAll.txt`) parsed on the phone. Pure Dart.
///
/// Layout (semicolon separated, with AMC and category heading lines between
/// the rows):
///
///     Scheme Code;ISIN Div Payout/ ISIN Growth;ISIN Div Reinvestment;Scheme Name;Net Asset Value;Date
///     Open Ended Schemes(Equity Scheme - Flexi Cap Fund)
///     Example Mutual Fund
///     100001;INF000A01AB1;-;Example Flexi Cap Fund - Direct Plan - Growth;215.1000;25-Nov-2026
library;

import '../../data/fund_match.dart';
import '../../data/wealth_models.dart';

class AmfiScheme {
  const AmfiScheme({
    required this.code,
    this.isinGrowth,
    this.isinReinvest,
    required this.name,
    required this.nav,
    required this.date,
  });
  final String code, name;

  /// First ISIN column (growth, or dividend payout).
  final String? isinGrowth;
  final String? isinReinvest;
  final double nav;

  /// The NAV date as `yyyy-MM-dd`.
  final String date;

  FundScheme get asScheme => FundScheme(code, name);
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
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

/// `25-Nov-2026` -> `2026-11-25`; null for anything else.
String? parseAmfiDate(String raw) {
  final m = RegExp(r'^(\d{1,2})-([A-Za-z]{3})-(\d{4})$').firstMatch(raw.trim());
  if (m == null) return null;
  final mo = _months[m[2]!.toLowerCase()];
  if (mo == null) return null;
  final d = int.parse(m[1]!), y = int.parse(m[3]!);
  if (d < 1 || d > 31) return null;
  return '${y.toString().padLeft(4, '0')}-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
}

String? _isin(String s) {
  final t = s.trim().toUpperCase();
  return RegExp(r'^INF[A-Z0-9]{9}$').hasMatch(t) ? t : null;
}

class AmfiBook {
  AmfiBook(this.schemes, {this.skipped = 0, this.fetchedAt}) {
    for (final s in schemes) {
      _byCode[s.code] = s;
      if (s.isinGrowth != null) _byIsin[s.isinGrowth!] = s;
      if (s.isinReinvest != null) _byIsin[s.isinReinvest!] = s;
    }
  }

  final List<AmfiScheme> schemes;

  /// Data rows that were unreadable or had no NAV ("N.A.").
  final int skipped;

  /// When this file was downloaded, if known.
  final DateTime? fetchedAt;

  final _byCode = <String, AmfiScheme>{};
  final _byIsin = <String, AmfiScheme>{};

  bool get isEmpty => schemes.isEmpty;

  AmfiScheme? byCode(String code) => _byCode[code.trim()];
  AmfiScheme? byIsin(String isin) => _byIsin[isin.trim().toUpperCase()];

  /// Newest NAV date in the file (`yyyy-MM-dd`), the file's "as of".
  String? get asOf {
    String? best;
    for (final s in schemes) {
      if (best == null || s.date.compareTo(best) > 0) best = s.date;
    }
    return best;
  }

  /// The scheme for a statement line: the ISIN is exact, so it wins; else the
  /// name is matched conservatively (null rather than a wrong fund).
  AmfiScheme? match({String? isin, required String name}) {
    if (isin != null) {
      final hit = byIsin(isin);
      if (hit != null) return hit;
    }
    final picked = pickScheme(name, schemes.map((s) => s.asScheme));
    if (picked == null) return null;
    // Money is at stake: every identifying word of the statement's name must
    // be in the scheme's name, or it is a different fund ("Liquid" is not
    // "Short Term").
    final have = fundKeywords(picked.name).toSet();
    if (!fundKeywords(name).every(have.contains)) return null;
    return byCode(picked.code);
  }
}

/// Parses `NAVAll.txt`. Heading lines, blank lines and rows without a NAV are
/// skipped; nothing throws.
AmfiBook parseAmfiNavAll(String text, {DateTime? fetchedAt}) {
  final out = <AmfiScheme>[];
  var skipped = 0;
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || !line.contains(';')) continue;
    final f = line.split(';');
    if (f.length < 6) continue;
    final code = f[0].trim();
    if (!RegExp(r'^\d+$').hasMatch(code)) continue; // the header row
    final nav = double.tryParse(f[4].trim().replaceAll(',', ''));
    final date = parseAmfiDate(f[5]);
    if (nav == null || nav <= 0 || date == null) {
      skipped++;
      continue;
    }
    out.add(
      AmfiScheme(
        code: code,
        isinGrowth: _isin(f[1]),
        isinReinvest: _isin(f[2]),
        name: f[3].trim(),
        nav: nav,
        date: date,
      ),
    );
  }
  return AmfiBook(out, skipped: skipped, fetchedAt: fetchedAt);
}
