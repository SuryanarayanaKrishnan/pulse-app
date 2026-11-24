/// Which things in the app belong in the vault, and how complete it feels.
/// Pure: no database, no UI.
library;

import 'vault_models.dart';

/// Something the app already knows about, in vault terms.
class VaultSource {
  const VaultSource({
    required this.ref,
    required this.type,
    required this.institution,
    this.title = '',
    this.valueMinor,
  });

  /// Stable id of the thing: `account:<id>`, `card:<id>`, `asset:<id>`,
  /// `liability:<id>`, `fund:<id>`, `recurring:<key>`, `goal:<id>`.
  final String ref;
  final VaultType type;
  final String institution;
  final String title;
  final int? valueMinor;
}

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

/// Sources not already in the vault, one per ref, in a calm order (types as
/// listed, then name). A source is "already there" when an entry carries its
/// ref, or has the same type and institution and title.
List<VaultSource> suggestEntries(
  List<VaultSource> sources,
  List<VaultEntry> existing,
) {
  final haveRefs = {
    for (final e in existing)
      if (e.sourceRef != null) e.sourceRef!,
  };
  final haveKeys = {
    for (final e in existing)
      '${e.type.key}|${_norm(e.institution)}|${_norm(e.title)}',
  };
  final seen = <String>{};
  final out = <VaultSource>[];
  for (final s in sources) {
    if (s.institution.trim().isEmpty) continue;
    if (haveRefs.contains(s.ref) || !seen.add(s.ref)) continue;
    if (haveKeys.contains(
      '${s.type.key}|${_norm(s.institution)}|${_norm(s.title)}',
    ))
      continue;
    out.add(s);
  }
  out.sort((a, b) {
    final t = a.type.index.compareTo(b.type.index);
    return t != 0 ? t : _norm(a.institution).compareTo(_norm(b.institution));
  });
  return out;
}

/// Insurance, loan and subscription hints from a recurring payment's
/// merchant name. Null when it is none of those.
VaultType? typeFromRecurringMerchant(
  String merchant, {
  required bool isSubscription,
}) {
  final m = _norm(merchant);
  if (RegExp(
    r'\b(insurance|takaful|assurance|daman|sukoon|axa|orient|adnic|oman insurance|policy)\b',
  ).hasMatch(m))
    return VaultType.insurance;
  if (RegExp(r'\b(loan|emi|mortgage|finance|installment|instalment)\b')
      .hasMatch(m))
    return VaultType.loan;
  if (isSubscription) return VaultType.subscription;
  return null;
}

class Completeness {
  const Completeness({
    required this.found,
    required this.expected,
    required this.missing,
  });

  /// Things the family could find, capped per type at what is expected.
  final int found;
  final int expected;

  /// Types with fewer entries than expected, with how many are missing.
  final Map<VaultType, int> missing;

  double get fraction => expected == 0 ? 0 : found / expected;

  /// "Your family could find 7 of ~12 typical things."
  String get headline =>
      'Your family could find $found of ~$expected typical things.';
}

/// [tracked] is how many of each type the app already knows about (accounts,
/// loans...), which can raise the expectation above the typical number, by at most two per type.
Completeness completeness(
  List<VaultEntry> entries, {
  Map<VaultType, int> tracked = const {},
}) {
  var found = 0;
  var expected = 0;
  final missing = <VaultType, int>{};
  for (final t in VaultType.values) {
    // The app's own data can raise the bar a little (two more than typical),
    // so one busy category never makes the score feel out of reach.
    final typical = typicalPerType[t] ?? 0;
    final seen = tracked[t] ?? 0;
    final exp = seen > typical
        ? (seen < typical + 2 ? seen : typical + 2)
        : typical;
    final have = entries.where((e) => e.type == t).length;
    final counted = have < exp ? have : exp;
    found += counted;
    expected += exp;
    if (counted < exp) missing[t] = exp - counted;
  }
  return Completeness(found: found, expected: expected, missing: missing);
}
