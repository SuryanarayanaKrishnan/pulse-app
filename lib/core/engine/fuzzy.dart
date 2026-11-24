/// Fuzzy string scores compatible with rapidfuzz's `fuzz.ratio`,
/// `fuzz.partial_ratio` and `fuzz.token_set_ratio` for the short merchant
/// strings the app deals with. Pure Dart.
library;

import 'dart:math' as math;

int _lcs(List<int> a, List<int> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  var prev = List<int>.filled(b.length + 1, 0);
  var cur = List<int>.filled(b.length + 1, 0);
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      cur[j] = a[i - 1] == b[j - 1]
          ? prev[j - 1] + 1
          : math.max(prev[j], cur[j - 1]);
    }
    final t = prev;
    prev = cur;
    cur = t;
  }
  return prev[b.length];
}

int _indel(List<int> a, List<int> b) => a.length + b.length - 2 * _lcs(a, b);

double _normSim(int dist, int lensum) =>
    (1.0 - (lensum == 0 ? 0.0 : dist / lensum)) * 100;

/// Normalised Indel similarity, 0..100.
double ratio(String a, String b) {
  final x = a.runes.toList(), y = b.runes.toList();
  return _normSim(_indel(x, y), x.length + y.length);
}

/// Best alignment of the shorter string inside the longer one, 0..100.
double partialRatio(String a, String b) {
  var s1 = a.runes.toList(), s2 = b.runes.toList();
  if (s1.length > s2.length) {
    final t = s1;
    s1 = s2;
    s2 = t;
  }
  if (s1.isEmpty && s2.isEmpty) return 100;
  if (s1.isEmpty) return 0;
  var best = 0.0;
  double score(List<int> window) =>
      _normSim(_indel(s1, window), s1.length + window.length);
  final n = s1.length, m = s2.length;
  for (var i = 1; i < n; i++) {
    best = math.max(best, score(s2.sublist(0, i)));
  }
  for (var i = 0; i + n <= m; i++) {
    best = math.max(best, score(s2.sublist(i, i + n)));
    if (best >= 100) return 100;
  }
  for (var i = m - n + 1; i < m; i++) {
    if (i < 0) continue;
    best = math.max(best, score(s2.sublist(i)));
  }
  return best;
}

List<String> _tokens(String s) =>
    s.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

/// Order- and duplicate-insensitive token comparison, 0..100.
double tokenSetRatio(String a, String b) {
  final ta = _tokens(a).toSet(), tb = _tokens(b).toSet();
  if (ta.isEmpty || tb.isEmpty) return 0;
  final inter = ta.intersection(tb);
  final dab = ta.difference(tb), dba = tb.difference(ta);
  if (inter.isNotEmpty && (dab.isEmpty || dba.isEmpty)) return 100;
  String join(Set<String> s) => (s.toList()..sort()).join(' ');
  final sect = join(inter), ab = join(dab), ba = join(dba);
  final sectLen = sect.length, abLen = ab.length, baLen = ba.length;
  final sectAb = sectLen + (sectLen != 0 ? 1 : 0) + abLen;
  final sectBa = sectLen + (sectLen != 0 ? 1 : 0) + baLen;
  final dist = _indel(ab.runes.toList(), ba.runes.toList());
  var result = _normSim(dist, sectAb + sectBa);
  if (sectLen == 0) return result;
  final abRatio = _normSim((sectLen != 0 ? 1 : 0) + abLen, sectLen + sectAb);
  final baRatio = _normSim((sectLen != 0 ? 1 : 0) + baLen, sectLen + sectBa);
  return math.max(result, math.max(abRatio, baRatio));
}
