/// What may leave the phone when "Help improve categories" is on, and how it
/// is prepared. Pure Dart; nothing here touches the network.
///
/// A contribution is a list of `(merchant key, category key, count)`. That is
/// all: no amounts, dates, accounts, user or install ids, transaction ids or
/// raw text. See `docs/LEARNING.md`.
library;

import 'dart:convert';
import 'dart:math';

import '../../capture/kv_store.dart';
import 'privacy_filter.dart';

/// One confirmed (merchant, category) pair with how many payments back it.
class PairCount {
  const PairCount(this.key, this.category, this.count);
  final String key;
  final String category;
  final int count;

  Map<String, Object> toJson() => {'k': key, 'c': category, 'n': count};

  @override
  bool operator ==(Object other) =>
      other is PairCount &&
      other.key == key &&
      other.category == category &&
      other.count == count;

  @override
  int get hashCode => Object.hash(key, category, count);

  @override
  String toString() => 'PairCount($key, $category, $count)';
}

/// The exact payload of one upload.
class ContributionBatch {
  const ContributionBatch({required this.mapVersion, required this.pairs});

  /// Payload format version.
  static const format = 1;

  /// Version of the global map the app had (so the server can tell which
  /// entries were already known).
  final int mapVersion;
  final List<PairCount> pairs;

  bool get isEmpty => pairs.isEmpty;

  /// The whole body. Only these four fields exist; a test pins it.
  Map<String, Object> toJson() => {
    'format': format,
    'map_version': mapVersion,
    'pairs': [for (final p in pairs) p.toJson()],
  };
}

/// Categories that are never contributed, even if confirmed: they point at
/// people, an employer, a landlord or a lender rather than a shop.
const nonContributableCategories = {
  'salary', 'family', 'savings', 'cc_payment', 'car_loan', 'home_loan',
  'rent', 'other', 'custom', //
};

/// Confirmed pairs waiting to be sent, kept on the phone.
///
/// A payment counts once per (merchant, category): confirming it again does
/// not add to the count, and confirming it into a different category moves it.
/// Only a key that passes [MerchantKeyFilter] is ever stored.
class ContributionQueue {
  ContributionQueue(this._kv, this.filter);

  final KvStore _kv;
  final MerchantKeyFilter filter;

  static const storageKey = 'learning.queue';
  static const maxKeys = 300;
  static const maxIdsPerPair = 12;

  /// key -> category -> distinct payment ids that confirmed it.
  final _data = <String, Map<String, Set<String>>>{};

  Future<void> load() async {
    _data.clear();
    try {
      final raw = await _kv.read(storageKey);
      if (raw == null) return;
      final json = jsonDecode(raw);
      if (json is! Map) return;
      for (final e in json.entries) {
        final key = e.key;
        final cats = e.value;
        if (key is! String || cats is! Map || !filter.accepts(key)) continue;
        for (final c in cats.entries) {
          final ids = c.value;
          if (c.key is! String || ids is! List) continue;
          if (nonContributableCategories.contains(c.key)) continue;
          (_data[key] ??= {})[c.key as String] = {
            for (final id in ids)
              if (id is String) id,
          };
        }
      }
    } on Object {
      _data.clear();
    }
  }

  Future<void> _save() async {
    if (_data.isEmpty) {
      await _kv.remove(storageKey);
      return;
    }
    await _kv.write(
      storageKey,
      jsonEncode({
        for (final e in _data.entries)
          e.key: {for (final c in e.value.entries) c.key: c.value.toList()},
      }),
    );
  }

  /// Records that [paymentId] was confirmed as [category] for [key].
  /// Returns false (and stores nothing) if the key or category may not be
  /// contributed.
  Future<bool> confirm(String paymentId, String key, String category) async {
    if (nonContributableCategories.contains(category)) return false;
    if (!filter.accepts(key)) return false;
    // A payment confirmed again into another category leaves the old one.
    for (final e in _data.entries) {
      for (final c in e.value.entries) {
        if (e.key != key || c.key != category) c.value.remove(paymentId);
      }
    }
    final ids = (_data[key] ??= {})[category] ??= <String>{};
    if (ids.length < maxIdsPerPair) ids.add(paymentId);
    _prune();
    while (_data.length > maxKeys) {
      _data.remove(_data.keys.first);
    }
    await _save();
    return true;
  }

  void _prune() {
    for (final cats in _data.values) {
      cats.removeWhere((_, ids) => ids.isEmpty);
    }
    _data.removeWhere((_, cats) => cats.isEmpty);
  }

  /// All pairs with their counts, re-checked against the filter.
  List<PairCount> all() => [
    for (final e in _data.entries)
      if (filter.accepts(e.key))
        for (final c in e.value.entries)
          if (!nonContributableCategories.contains(c.key))
            PairCount(e.key, c.key, c.value.length),
  ];

  /// Pairs confirmed on at least [min] payments.
  List<PairCount> eligible({int min = 2}) => [
    for (final p in all())
      if (p.count >= min) p,
  ];

  /// Removes the given pairs (after they were sent or deliberately skipped).
  Future<void> remove(Iterable<PairCount> pairs) async {
    for (final p in pairs) {
      _data[p.key]?.remove(p.category);
    }
    _prune();
    await _save();
  }

  /// Forgets everything queued (opting out).
  Future<void> clear() async {
    _data.clear();
    await _kv.remove(storageKey);
  }

  bool get isEmpty => _data.isEmpty;
}

/// Turns the eligible pairs into a batch, with noise.
///
/// * Threshold: only pairs confirmed at least [minConfirmations] times.
/// * Randomised inclusion: each pair is left out with probability
///   [dropProbability], independently, so the server can never be sure a
///   given install confirmed a given pair (it corrects for this in aggregate).
/// * Counts are capped at [maxCount] so one person cannot outweigh others.
/// * Order is shuffled, so it reveals nothing about when pairs were confirmed.
class ContributionBatcher {
  ContributionBatcher({
    required this.filter,
    this.minConfirmations = 2,
    this.dropProbability = 0.25,
    this.maxCount = 3,
    Random? random,
  }) : _random = random ?? Random.secure();

  final MerchantKeyFilter filter;
  final int minConfirmations;
  final double dropProbability;
  final int maxCount;
  final Random _random;

  /// Pairs that could be sent now, before the random leave-out. This is what
  /// the preview screen shows.
  List<PairCount> candidates(List<PairCount> queued) => [
    for (final p in queued)
      if (p.count >= minConfirmations &&
          !nonContributableCategories.contains(p.category) &&
          filter.accepts(p.key))
        PairCount(p.key, p.category, min(p.count, maxCount)),
  ];

  ContributionBatch build(List<PairCount> queued, {required int mapVersion}) {
    final kept = [
      for (final p in candidates(queued))
        if (_random.nextDouble() >= dropProbability) p,
    ]..shuffle(_random);
    return ContributionBatch(mapVersion: mapVersion, pairs: kept);
  }
}

/// What the "See what would be shared" screen shows.
class ContributionPreview {
  const ContributionPreview({
    required this.items,
    required this.waiting,
    required this.dropPercent,
    required this.nextSend,
  });

  /// Pairs that would be eligible for the next upload.
  final List<PairCount> items;

  /// Confirmed pairs that are not eligible yet (confirmed fewer than twice).
  /// Only the number is shown; they are not part of any upload.
  final int waiting;

  /// Share of eligible pairs left out at random, in percent.
  final int dropPercent;

  /// When the next weekly upload may happen, or null if nothing is queued or
  /// uploads are not configured.
  final DateTime? nextSend;

  /// The exact JSON an upload would contain if nothing were left out.
  String exampleJson(int mapVersion) => const JsonEncoder.withIndent(
    '  ',
  ).convert(ContributionBatch(mapVersion: mapVersion, pairs: items).toJson());
}
