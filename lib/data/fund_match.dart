import 'wealth_models.dart';

/// Matching a fund name read off a screenshot to a scheme in the free AMFI
/// list (through mfapi.in). Pure functions; the search itself is in the
/// service.

const _noise = {
  'fund',
  'plan',
  'option',
  'scheme',
  'the',
  'and',
  'of',
  'a',
  'mutual',
  'direct',
  'regular',
  'growth',
  'idcw',
  'dividend',
  'payout',
  'reinvestment',
  'reinvest',
  'fof',
  'india',
  'indian',
};

List<String> _tokens(String s) => [
  for (final w in s.toLowerCase().split(RegExp(r'[^a-z0-9]+')))
    if (w.isNotEmpty) w,
];

/// Words that identify the fund (not the plan or option).
List<String> fundKeywords(String name) => [
  for (final w in _tokens(name))
    if (!_noise.contains(w)) w,
];

/// Search phrases to try, longest first: the full cleaned name, then fewer
/// words, because mfapi matches the scheme name as written.
List<String> searchQueries(String name) {
  final w = fundKeywords(name);
  if (w.isEmpty) return const [];
  final out = <String>[];
  for (
    var n = w.length < 5 ? w.length : 5;
    n >= 2 || (n == 1 && w.length == 1);
    n--
  ) {
    out.add(w.take(n).join(' '));
    if (n == 1) break;
  }
  return out;
}

/// The scheme that best fits [name], or null when none is close enough.
/// Prefers the Direct/Regular and Growth/IDCW the screenshot shows; with
/// nothing said, Direct Growth, the usual choice for an app that shows NAVs.
FundScheme? pickScheme(String name, Iterable<FundScheme> candidates) {
  final want = fundKeywords(name);
  if (want.isEmpty) return null;
  final lower = name.toLowerCase();
  final wantDirect = lower.contains('direct');
  final wantRegular = lower.contains('regular');
  final wantIdcw = lower.contains('idcw') || lower.contains('dividend');
  FundScheme? best;
  var bestScore = 0.0;
  for (final c in candidates) {
    final cl = c.name.toLowerCase();
    final have = fundKeywords(c.name).toSet();
    final hit = want.where(have.contains).length;
    if (hit == 0) continue;
    // How much of the screenshot name is covered, minus extra words in the
    // scheme so "Flexi Cap" does not pick "Flexi Cap Overseas".
    var score = hit / want.length - (have.length - hit) * 0.03;
    final isDirect = cl.contains('direct');
    final isIdcw = cl.contains('idcw') || cl.contains('dividend');
    if (wantDirect || wantRegular) {
      score += (wantDirect == isDirect) ? 0.1 : -0.1;
    } else if (isDirect) {
      score += 0.04;
    }
    score += (wantIdcw == isIdcw) ? 0.1 : -0.2;
    if (score > bestScore) {
      bestScore = score;
      best = c;
    }
  }
  return bestScore >= 0.6 ? best : null;
}
