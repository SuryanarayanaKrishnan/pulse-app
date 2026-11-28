/// Super-apps: one merchant name on a bank SMS, several kinds of spend.
///
/// "NOON.COM" can be a phone, a grocery run or dinner; "CAREEM" a ride, a meal
/// or a quick shop. A bank text never says which. This file holds what is
/// known about each of them, as plain rules (no model, no network):
///
/// * [superAppFor] says whether a descriptor belongs to a super-app family.
/// * [SuperApp.candidates] are the categories worth offering as one-tap chips.
/// * [hintFrom] reads an explicit sub-service in the text ("Noon Food",
///   "Careem Quik") that settles the category outright.
/// * `habit_model.dart` learns "Careem under AED 30 is a ride" per person.
/// * [sameFamily] lets "NOON.COM" and "Noon Food" count as one merchant when
///   the same purchase arrives through two channels.
///
/// Pure Dart.
library;

import 'merchants.dart';

/// Tag on a transaction whose category is only a best guess.
const guessTag = 'guess_category';

class SuperApp {
  const SuperApp(
    this.key,
    this.name,
    this.candidates,
    this._pattern,
    this.hints,
  );

  /// Stable lower-case family key ("noon").
  final String key;
  final String name;

  /// Category slugs worth offering, most likely first.
  final List<String> candidates;
  final String _pattern;

  /// Explicit sub-services: pattern -> (category slug, specific name).
  final List<(String, String, String)> hints;

  RegExp get pattern => RegExp(_pattern);
}

const _noon = SuperApp(
  'noon',
  'Noon',
  ['shopping', 'groceries', 'dining'],
  r'(?<![A-Z0-9])NOON(?![A-Z0-9])',
  [
    (r'NOON\s*FOOD|NOONFOOD', 'dining', 'Noon Food'),
    (r'NOON\s*MINUTES|NOON\s*SUPERMALL|SUPERMALL', 'groceries', 'Noon Minutes'),
  ],
);

const _careem = SuperApp(
  'careem',
  'Careem',
  ['transport', 'dining', 'groceries'],
  r'(?<![A-Z0-9])CAREEM(?![A-Z0-9])',
  [
    (r'CAREEM\s*FOOD|CAREEM\s*NOW', 'dining', 'Careem Food'),
    (r'CAREEM\s*QUIK|QUIK', 'groceries', 'Careem Quik'),
    (
      r'CAREEM\s*RIDES?|CAREEM\s*BIKE|CAREEM\s*PAY',
      'transport',
      'Careem Rides',
    ),
  ],
);

const _amazon = SuperApp(
  'amazon',
  'Amazon',
  ['shopping', 'groceries', 'dining'],
  r'(?<![A-Z0-9])(?:AMAZON|AMZN)(?![A-Z0-9])',
  [
    (
      r'PRIME\s*VIDEO|AMAZON\s*PRIME|PRIME\s*MEMBERSHIP',
      'fixed_expenses',
      'Amazon Prime',
    ),
    (r'AMAZON\s*FRESH|AMAZON\s*GROCER', 'groceries', 'Amazon Fresh'),
  ],
);

const _smiles = SuperApp(
  'smiles',
  'Smiles',
  ['dining', 'shopping', 'groceries'],
  r'(?<![A-Z0-9])SMILES(?![A-Z0-9])',
  [],
);

const _talabat = SuperApp(
  'talabat',
  'Talabat',
  ['dining', 'groceries'],
  r'(?<![A-Z0-9])TALABAT(?![A-Z0-9])',
  [(r'TALABAT\s*MART|DMART', 'groceries', 'Talabat Mart')],
);

const _uber = SuperApp(
  'uber',
  'Uber',
  ['transport', 'dining'],
  r'(?<![A-Z0-9])UBER(?![A-Z0-9])',
  [(r'UBER\s*\*?\s*EATS|UBEREATS', 'dining', 'Uber Eats')],
);

const superApps = [_noon, _careem, _amazon, _smiles, _talabat, _uber];

String _upper(String raw) => raw.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

/// The family a descriptor belongs to, or null.
SuperApp? superAppFor(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final s = _upper(raw);
  final c = cleanDescriptor(raw);
  for (final a in superApps) {
    final p = a.pattern;
    if (p.hasMatch(s) || p.hasMatch(c)) return a;
  }
  return null;
}

/// A sub-service named in the text, which settles the category.
({String category, String name})? hintFrom(String? raw) {
  final a = superAppFor(raw);
  if (a == null) return null;
  final s = _upper(raw!);
  for (final (pattern, category, name) in a.hints) {
    if (RegExp(pattern).hasMatch(s)) return (category: category, name: name);
  }
  return null;
}

/// Whether the text alone cannot tell what was bought: a super-app with no
/// sub-service named.
bool isAmbiguous(String? raw) =>
    superAppFor(raw) != null && hintFrom(raw) == null;

/// Two descriptors of the same super-app family ("NOON.COM", "Noon Food").
bool sameFamily(String? a, String? b) {
  final fa = superAppFor(a);
  return fa != null && identical(fa, superAppFor(b));
}

/// The category chips to offer, this person's most likely choices first.
List<String> chipsFor(String? raw, {List<String> ranked = const []}) {
  final a = superAppFor(raw);
  if (a == null) return const [];
  return [
        for (final c in ranked)
          if (a.candidates.contains(c)) c,
        ...a.candidates,
      ]
      .fold<List<String>>(<String>[], (l, c) => l.contains(c) ? l : [...l, c])
      .take(3)
      .toList();
}

/// What a second source teaches an existing row.
class MergeUpgrade {
  const MergeUpgrade({this.merchantName, this.categorySlug});

  /// A more specific merchant name to show, or null to keep the current one.
  final String? merchantName;

  /// A category to apply, or null to keep the current one.
  final String? categorySlug;

  bool get isEmpty => merchantName == null && categorySlug == null;
}

/// When the same purchase is seen again through [incomingMerchant], does it
/// know more than the row we already have? Only a named sub-service
/// ("Noon Food") counts, and only while the row is still unconfirmed: a
/// category the person chose is never overridden.
MergeUpgrade mergeUpgrade({
  required String? existingMerchant,
  required String? incomingMerchant,
  required bool existingReviewed,
}) {
  final inHint = hintFrom(incomingMerchant);
  if (inHint == null || existingReviewed) return const MergeUpgrade();
  if (hintFrom(existingMerchant) != null) return const MergeUpgrade();
  return MergeUpgrade(merchantName: inHint.name, categorySlug: inHint.category);
}
