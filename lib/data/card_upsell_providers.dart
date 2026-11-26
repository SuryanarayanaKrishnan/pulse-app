import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capture/kv_store.dart';
import '../core/engine/card_upsell.dart';
import '../core/engine/catalog.dart';
import 'card_suggestions.dart';
import 'models.dart';
import 'providers.dart';

/// Cards the user said "Not interested" to, kept on this phone only.
class UpsellPrefs {
  UpsellPrefs(this._kv);
  final KvStore _kv;
  static const dismissedKey = 'upsell.dismissed';

  Future<Set<String>> dismissed() async {
    try {
      final raw = await _kv.read(dismissedKey);
      if (raw == null) return {};
      return {for (final x in jsonDecode(raw) as List) '$x'};
    } on Object {
      return {};
    }
  }

  Future<void> save(Set<String> ids) => ids.isEmpty
      ? _kv.remove(dismissedKey)
      : _kv.write(dismissedKey, jsonEncode(ids.toList()..sort()));
}

final upsellPrefsProvider = Provider<UpsellPrefs>(
  (ref) => UpsellPrefs(SharedPrefsKvStore()),
);

class DismissedUpsells extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() => ref.read(upsellPrefsProvider).dismissed();

  Future<void> dismiss(String id) => _set({...?state.value, id});
  Future<void> restore(String id) => _set({...?state.value}..remove(id));

  Future<void> _set(Set<String> next) async {
    state = AsyncData(next);
    await ref.read(upsellPrefsProvider).save(next);
  }
}

final dismissedUpsellsProvider =
    AsyncNotifierProvider<DismissedUpsells, Set<String>>(DismissedUpsells.new);

/// The engine's view of the catalog (needs min salary and raw rules, which
/// the display model drops). Empty when there is no on-device catalog.
final upsellCatalogProvider = FutureProvider<List<CatalogCard>>((ref) async {
  final service = ref.watch(catalogServiceProvider);
  return service == null ? const [] : service.cards();
});

/// Issuers we must not promote right now (remote config param, offline-safe;
/// empty by default).
final upsellUnavailableIssuersProvider = Provider<Set<String>>((ref) {
  try {
    final v = ref
        .watch(remoteConfigProvider)
        .param<List<Object?>>('card_upsell_unavailable_issuers', const []);
    return {for (final x in v) '$x'};
  } on Object {
    return {};
  }
});

/// Biggest salary credited in any of the last three 30-day windows, in fils;
/// null when no salary was seen.
int? estimateSalaryMinor(List<Transaction> txs, DateTime now) {
  final buckets = List.filled(3, 0.0);
  for (final t in txs) {
    if (!t.isIncome || t.excluded || t.category != SpendCategory.salary)
      continue;
    final days = now.difference(t.date).inDays;
    if (days < 0 || days >= 90) continue;
    buckets[days ~/ 30] += t.amount;
  }
  final best = buckets.reduce((a, b) => a > b ? a : b);
  return best <= 0 ? null : (best * 100).round();
}

/// What the "You'd earn more with..." row needs.
class UpsellView {
  const UpsellView({
    required this.upsell,
    required this.display,
    required this.typicalSpend,
  });
  final CardUpsell upsell;

  /// The catalog card as the app draws it (art, name, rates).
  final CreditCard display;

  /// The spend behind the figure is a typical month, not the user's own.
  final bool typicalSpend;
}

/// The one suggestion for [categoryId] (a spend category id), or null.
final cardUpsellProvider = FutureProvider.autoDispose
    .family<UpsellView?, String>((ref, categoryId) async {
      final entries = await ref.watch(upsellCatalogProvider.future);
      if (entries.isEmpty) return null;
      final mine = await ref.watch(myCardsProvider.future);
      final display = await ref.watch(catalogProvider.future);
      final dismissed = await ref.watch(dismissedUpsellsProvider.future);
      final txs =
          ref.watch(transactionsProvider).value ?? const <Transaction>[];
      final unavailable = ref.watch(upsellUnavailableIssuersProvider);

      // Every held card must be known to the catalog, or "best you hold" is a guess.
      final owned = <CatalogCard>[];
      final ownedIds = <String>{};
      for (final c in mine) {
        final id = c.catalogId;
        if (id != null) ownedIds.add(id);
        final entry = id == null
            ? null
            : entries.where((e) => e.id == id).firstOrNull;
        if (entry == null) return null;
        owned.add(entry);
      }

      final cat = SpendCategory.byId(categoryId);
      if (cat == null) return null;
      final now = DateTime.now();
      final learned = learnedMonthlySpend(txs, now)?[cat];
      final spendMinor = learned != null && learned > 0
          ? (learned * 100).round()
          : typicalMonthlySpendMinor(categoryId);
      final upsell = suggestUnownedCard(
        catalog: entries,
        owned: owned,
        ownedIds: ownedIds,
        dismissedIds: dismissed,
        unavailableIssuers: unavailable,
        category: categoryId,
        monthlySpendMinor: spendMinor,
        salaryMinor: estimateSalaryMinor(txs, now),
      );
      if (upsell == null) return null;
      final shown = display
          .where((d) => d.catalogId == upsell.card.id)
          .firstOrNull;
      if (shown == null) return null;
      return UpsellView(
        upsell: upsell,
        display: shown,
        typicalSpend: learned == null || learned <= 0,
      );
    });
