/// The global merchant map: a versioned list of common merchants and the
/// default category each one belongs to. Public knowledge only; it holds no
/// user data and is shipped with the app (`assets/merchant_map.json`).
///
/// Precedence when a payment is categorised (see `CategoryResolver`):
///
///  1. the person's own rules (always win),
///  2. the built-in merchant dictionary,
///  3. this map,
///  4. nothing (the generic fallback: uncategorised, shown in Review).
///
/// Updating: the file carries an integer `version`. A newer copy (for
/// example fetched from the catalog distribution endpoint, see
/// `docs/LEARNING.md`) replaces the bundled one only when its version is
/// higher, and only after it passes the same validation as the bundled file.
library;

import 'dart:convert';

import '../analytics/event_schema.dart';
import '../engine/merchants.dart' show merchantKey, normalizeMerchant;

/// Category keys the map may point at: the default categories, never
/// `custom` (a person's own category cannot be known to a shared map).
final Set<String> mapCategoryKeys = {
  for (final c in AnalyticsSchema.categories)
    if (c != 'custom') c,
};

class GlobalMerchantMap {
  GlobalMerchantMap({
    required this.version,
    required Map<String, String> entries,
    this.updated,
  }) : entries = Map.unmodifiable(entries);

  /// No entries; lookups always miss. Version 0 loses to any real map.
  static final empty = GlobalMerchantMap(version: 0, entries: const {});

  final int version;
  final String? updated;

  /// Normalised merchant key -> default category key.
  final Map<String, String> entries;

  int get length => entries.length;

  /// Parses and validates. Throws [FormatException] for a file that is not a
  /// map at all; silently skips entries with an unknown category or an
  /// unusable key so one bad line cannot disable the rest.
  factory GlobalMerchantMap.fromJson(Object? json) {
    if (json is! Map)
      throw const FormatException('merchant map is not an object');
    final version = json['version'];
    if (version is! int || version < 1) {
      throw const FormatException('merchant map has no valid version');
    }
    final raw = json['entries'];
    if (raw is! Map) throw const FormatException('merchant map has no entries');
    final out = <String, String>{};
    for (final e in raw.entries) {
      final k = e.key;
      final v = e.value;
      if (k is! String || v is! String) continue;
      final key = merchantKey(k);
      if (key == null || key != k || !mapCategoryKeys.contains(v)) continue;
      out[key] = v;
    }
    final updated = json['updated'];
    return GlobalMerchantMap(
      version: version,
      entries: out,
      updated: updated is String ? updated : null,
    );
  }

  factory GlobalMerchantMap.parse(String source) =>
      GlobalMerchantMap.fromJson(jsonDecode(source));

  /// True if [key] (already normalised) is exactly an entry.
  bool containsKey(String key) => entries.containsKey(key);

  /// The default category key for a merchant name (raw or normalised), or
  /// null. An exact key wins; otherwise the longest entry that is a whole-word
  /// prefix of the name (so "carrefour city centre" finds "carrefour"). Prefix
  /// matches need an entry of at least 5 characters, to keep short words from
  /// matching everything.
  String? lookup(String? merchant) {
    if (entries.isEmpty || merchant == null) return null;
    final key =
        merchantKey(normalizeMerchant(merchant)) ?? merchantKey(merchant);
    if (key == null) return null;
    final exact = entries[key];
    if (exact != null) return exact;
    final words = key.split(' ');
    for (var n = words.length - 1; n >= 1; n--) {
      final prefix = words.take(n).join(' ');
      if (prefix.length < 5) break;
      final hit = entries[prefix];
      if (hit != null) return hit;
    }
    return null;
  }

  /// A map with every entry of [base] and [overlay]; on a clash [overlay]
  /// wins. The version is the higher of the two.
  static GlobalMerchantMap merge(
    GlobalMerchantMap base,
    GlobalMerchantMap overlay,
  ) => GlobalMerchantMap(
    version: base.version > overlay.version ? base.version : overlay.version,
    entries: {...base.entries, ...overlay.entries},
    updated: overlay.updated ?? base.updated,
  );

  /// The newer of two maps by version (a tie keeps [a]); never mixes them.
  static GlobalMerchantMap newer(GlobalMerchantMap a, GlobalMerchantMap b) =>
      b.version > a.version ? b : a;
}
