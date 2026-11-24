/// Merchant normalisation and the curated UAE merchant dictionary.
///
/// Everything here is deterministic and offline: raw card/SMS descriptors such
/// as "CARREFOUR MOE DUBAI AE 0123" are cleaned and matched against the
/// dictionary (first match wins). Port of `app/services/merchants.py`; the
/// dictionary itself is generated from the Python source of truth
/// (`merchant_dictionary.dart`).
library;

import 'merchant_dictionary.dart';
import 'types.dart';

final _ws = RegExp(r'\s+');
final _leadingNoise = RegExp(
  r'^(?:(?:POS|PUR|PURCHASE|ECOM|E-COM|ONLINE|CARD|DEBIT|VISA|MASTERCARD|MC|RECURRING|CONTACTLESS|NFC)'
  r'(?:\s+(?:PURCHASE|PAYMENT|TXN|TRANSACTION))?[\s:*\-]+)+',
);
final _gatewayPrefix = RegExp(
  r'^(?:PAYFORT|PAYPAL|SQ|SQU|TST|CKO|CHECKOUT\.COM|STRIPE|PAY\.GOV|WWW|HTTPS?://)[\s*:\-/]+',
);
const _cities =
    r'DUBAI|ABU\s?DHABI|SHARJAH|AJMAN|RAS\s?AL\s?KHAIMAH|RAK|FUJAIRAH|AL\s?AIN|UMM\s?AL\s?QUWAIN|UAQ|'
    r'DXB|AUH|SHJ|LONDON|NEW\s?YORK|SINGAPORE|MUMBAI|DOHA|RIYADH';
const _countries =
    r'AE|ARE|UAE|UNITED\s?ARAB\s?EMIRATES|US|USA|GB|GBR|UK|IN|IND|SG|SGP|QA|SA';
final _trailingLocation = RegExp(
  '(?:[\\s,\\-]+(?:$_cities|$_countries))+\$',
);
final _trailingRef = RegExp(r'[\s#*\-]*\d{3,}$');
final _trailingCcy = RegExp(r'\s+(?:AED|USD|EUR|GBP)\s*[\d.,]*$');

class MerchantEntry {
  MerchantEntry(this.name, this.category, this.pattern, this.direction);
  final String name;

  /// Slug of a default category.
  final String category;
  final RegExp pattern;
  final Direction? direction;
}

final List<MerchantEntry> merchantDictionary = [
  for (final (name, category, pattern, direction) in rawMerchantDictionary)
    MerchantEntry(name, category, RegExp(pattern), direction),
];

String _stripSet(String s, String chars) {
  var a = 0, b = s.length;
  while (a < b && chars.contains(s[a])) {
    a++;
  }
  while (b > a && chars.contains(s[b - 1])) {
    b--;
  }
  return s.substring(a, b);
}

/// Upper-cases the descriptor and strips POS/gateway prefixes, trailing
/// city/country and reference numbers.
String cleanDescriptor(String raw) {
  var s = raw.toUpperCase().replaceAll(' ', ' ').replaceAll(_ws, ' ').trim();
  for (var i = 0; i < 2; i++) {
    s = s.replaceFirst(_leadingNoise, '');
    s = s.replaceFirst(_gatewayPrefix, '');
  }
  String? prev;
  while (prev != s) {
    prev = s;
    s = s.replaceFirst(_trailingLocation, '');
    s = s.replaceFirst(_trailingCcy, '');
    s = s.replaceFirst(_trailingRef, '');
    s = _stripSet(s, ' -*#,.');
  }
  return s;
}

MerchantEntry? matchEntry(String? raw, [Direction? direction]) {
  if (raw == null || raw.isEmpty) return null;
  final cleaned = cleanDescriptor(raw);
  final full = raw.toUpperCase().replaceAll(_ws, ' ');
  for (final e in merchantDictionary) {
    if (e.direction != null && direction != null && e.direction != direction) {
      continue;
    }
    if (e.pattern.hasMatch(cleaned) || e.pattern.hasMatch(full)) return e;
  }
  return null;
}

/// Python's `str.title()`: first letter of every run of letters upper-case,
/// the rest lower-case.
String pythonTitle(String s) {
  final b = StringBuffer();
  var prevLetter = false;
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final isLetter = ch.toLowerCase() != ch.toUpperCase();
    if (isLetter) {
      b.write(prevLetter ? ch.toLowerCase() : ch.toUpperCase());
    } else {
      b.write(ch);
    }
    prevLetter = isLetter;
  }
  return b.toString();
}

/// Canonical merchant name: dictionary hit, else the cleaned descriptor in
/// title case.
String? normalizeMerchant(String? raw, [Direction? direction]) {
  if (raw == null || raw.trim().isEmpty) return null;
  final entry = matchEntry(raw, direction);
  if (entry != null) return entry.name;
  final cleaned = pythonTitle(cleanDescriptor(raw));
  final cut = cleaned.length > 160 ? cleaned.substring(0, 160) : cleaned;
  return cut.isEmpty ? null : cut;
}

String? guessCategorySlug(String? raw, [Direction? direction]) =>
    matchEntry(raw, direction)?.category;

/// Rule key: case/whitespace-insensitive normalised merchant.
String? merchantKey(String? normalized) {
  if (normalized == null || normalized.trim().isEmpty) return null;
  final k = normalized.trim().toLowerCase().replaceAll(_ws, ' ');
  return k.length > 160 ? k.substring(0, 160) : k;
}
