/// What this person has told Pulse about merchants, kept on this phone.
///
/// Every time you confirm or fix a category, the merchant's normalised key
/// ("carrefour", whatever the card statement spelled it as) gets a vote for
/// that category. Later captures from the same merchant, or a near-identical
/// spelling, start in the category you chose. Nothing here leaves the
/// device: it is a private cache next to your rules, not a contribution.
///
/// Confidence grows with repeated agreement and drops when you contradict
/// yourself, so a merchant that sells everything (a hypermarket, a marketplace)
/// stops guessing instead of guessing wrong. Explicit rules always win over
/// this memory; this memory wins over the built-in dictionary.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../capture/kv_store.dart';
import '../engine/fuzzy.dart' as fuzzy;
import '../engine/habit_model.dart';
import '../engine/merchants.dart' show merchantKey, normalizeMerchant;

/// Memory is used from this confidence up (two agreeing confirmations, or one
/// deliberate fix, are enough).
const memoryApplyAt = 0.6;

/// A vote strength: a deliberate fix counts double a "yes, that is right".
const confirmWeight = 1.0;
const fixWeight = 2.0;

/// A near-match on a different spelling needs at least this similarity (0..100).
const _fuzzyAt = 92.0;
const _fuzzyMinLength = 8;
const _maxEntries = 600;

class MemoryEntry {
  MemoryEntry(this.votes, this.updatedAt);

  /// Category slug -> decayed vote weight.
  final Map<String, double> votes;
  DateTime updatedAt;

  double get total => votes.values.fold(0.0, (a, b) => a + b);

  /// The winning category and how sure the memory is of it (0 to 1).
  ({String category, double confidence})? get best {
    if (votes.isEmpty) return null;
    final top = votes.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return (category: top.key, confidence: top.value / (total + 1));
  }

  Map<String, Object?> toJson() => {
    'v': votes,
    't': updatedAt.toUtc().toIso8601String(),
  };

  static MemoryEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final v = j['v'];
    if (v is! Map) return null;
    final votes = <String, double>{
      for (final e in v.entries)
        if (e.key is String && e.value is num && (e.value as num) > 0)
          e.key as String: (e.value as num).toDouble(),
    };
    if (votes.isEmpty) return null;
    return MemoryEntry(
      votes,
      DateTime.tryParse('${j['t']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  MemoryEntry copy() => MemoryEntry(Map.of(votes), updatedAt);
}

/// A category the memory would apply, with how sure it is and how it matched.
class MemoryHit {
  const MemoryHit(this.category, this.confidence, {this.exact = true});
  final String category;
  final double confidence;

  /// False when matched on a near-identical spelling rather than the same key.
  final bool exact;
}

class MerchantMemory extends ChangeNotifier {
  MerchantMemory(this._kv, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const storageKey = 'learning.merchant_memory';

  final KvStore _kv;
  final DateTime Function() _clock;
  final Map<String, MemoryEntry> _entries = {};

  int get length => _entries.length;

  /// Reads what was saved. A damaged value is dropped, never thrown.
  Future<void> load() async {
    try {
      habits.load(await _kv.read(habitsKey));
      stats.load(await _kv.read(statsKey));
      final raw = await _kv.read(storageKey);
      _entries.clear();
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw);
        if (j is Map) {
          for (final e in j.entries) {
            final m = MemoryEntry.fromJson(e.value);
            if (e.key is String && m != null) _entries[e.key as String] = m;
          }
        }
      }
    } on Object catch (e) {
      debugPrint('Merchant memory unreadable, starting empty: $e');
      _entries.clear();
    }
    notifyListeners();
  }

  /// The key a payment's merchant is remembered under, or null.
  static String? keyFor(String? merchant) =>
      merchantKey(normalizeMerchant(merchant));

  /// A vote that [merchant] belongs in [category] (a slug). Opposing votes are
  /// halved first, so a change of mind outweighs old habit within a couple of
  /// confirmations but one stray fix does not erase a long history.
  Future<void> confirm(
    String? merchant,
    String category, {
    double weight = confirmWeight,
  }) async {
    final key = keyFor(merchant);
    if (key == null || weight <= 0) return;
    final e = _entries.putIfAbsent(key, () => MemoryEntry({}, _clock()));
    for (final k in e.votes.keys.toList()) {
      if (k != category) {
        e.votes[k] = e.votes[k]! / 2;
        if (e.votes[k]! < 0.2) e.votes.remove(k);
      }
    }
    e.votes[category] = (e.votes[category] ?? 0) + weight;
    // Past a point more votes add nothing; keep the number tidy.
    if (e.votes[category]! > 12) e.votes[category] = 12;
    e.updatedAt = _clock();
    _trim();
    await _save();
  }

  /// How this person uses super-apps (Noon, Careem...), by payment size and
  /// time of day. Saved next to the merchant votes, on this phone only.
  final HabitModel habits = HabitModel();

  static const habitsKey = 'learning.super_app_habits';
  static const statsKey = 'learning.super_app_stats';

  /// Counts of chips shown, tapped and corrected, for retuning from real use.
  final HabitStats stats = HabitStats();

  /// Adds to a counter and saves. Never throws.
  Future<void> bump({
    int chipsShown = 0,
    int chipTaps = 0,
    int topChipTaps = 0,
    int autoApplied = 0,
    int autoCorrected = 0,
  }) async {
    stats.chipsShown += chipsShown;
    stats.chipTaps += chipTaps;
    stats.topChipTaps += topChipTaps;
    stats.autoApplied += autoApplied;
    stats.autoCorrected += autoCorrected;
    try {
      await _kv.write(statsKey, stats.encode());
    } on Object catch (e) {
      debugPrint('Habit stats not saved: $e');
    }
  }

  /// The person confirmed [category] for a payment at a super-app. [weight]
  /// is 1 for a tap on a chip, 2 for a deliberate fix.
  Future<void> confirmHabit(
    String app,
    int amountMinor,
    DateTime when,
    String category, {
    double weight = 1,
  }) async {
    habits.confirm(app, amountMinor, dubaiHour(when), category, weight: weight);
    try {
      await _kv.write(habitsKey, habits.encode());
    } on Object catch (e) {
      debugPrint('Habits not saved: $e');
    }
  }

  /// The entry as stored, for undo. A copy.
  MemoryEntry? snapshot(String? merchant) => _entries[keyFor(merchant)]?.copy();

  /// Puts back a [snapshot] (null removes the entry).
  Future<void> restore(String? merchant, MemoryEntry? entry) async {
    final key = keyFor(merchant);
    if (key == null) return;
    if (entry == null) {
      _entries.remove(key);
    } else {
      _entries[key] = entry;
    }
    await _save();
  }

  Future<void> forget(String? merchant) => restore(merchant, null);

  Future<void> clear() async {
    _entries.clear();
    habits.clear();
    try {
      await _kv.write(habitsKey, '');
    } on Object {
      // ignore
    }
    await _save();
  }

  /// Whether anything is remembered for this merchant, applied or not.
  bool knows(String? merchant) => _entries.containsKey(keyFor(merchant));

  /// What to apply for [normalizedMerchant], or null when memory is not sure.
  MemoryHit? lookup(String? normalizedMerchant) {
    final key = merchantKey(normalizedMerchant);
    if (key == null || _entries.isEmpty) return null;
    final exact = _entries[key]?.best;
    if (exact != null) {
      return exact.confidence >= memoryApplyAt
          ? MemoryHit(exact.category, exact.confidence)
          : null;
    }
    if (key.length < _fuzzyMinLength) return null;
    // A near-identical spelling: only when exactly one remembered merchant is
    // that close, so two similar names cannot trade places.
    String? hitKey;
    var count = 0;
    for (final k in _entries.keys) {
      if (k.length < _fuzzyMinLength) continue;
      if ((k.length - key.length).abs() > 3) continue;
      if (fuzzy.ratio(k, key) >= _fuzzyAt) {
        hitKey = k;
        count++;
      }
    }
    if (count != 1) return null;
    final b = _entries[hitKey]!.best;
    if (b == null) return null;
    final c = b.confidence * 0.9;
    return c >= memoryApplyAt ? MemoryHit(b.category, c, exact: false) : null;
  }

  void _trim() {
    if (_entries.length <= _maxEntries) return;
    final byAge = _entries.entries.toList()
      ..sort((a, b) => a.value.updatedAt.compareTo(b.value.updatedAt));
    for (final e in byAge.take(_entries.length - _maxEntries)) {
      _entries.remove(e.key);
    }
  }

  Future<void> _save() async {
    try {
      await _kv.write(
        storageKey,
        jsonEncode({for (final e in _entries.entries) e.key: e.value.toJson()}),
      );
    } on Object catch (e) {
      debugPrint('Merchant memory not saved: $e');
    }
    notifyListeners();
  }
}
