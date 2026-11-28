import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/engine/catalog.dart';
import '../core/engine/valuation.dart' show notificationIdFor;
import '../core/engine/welcome_offers.dart';
import 'card_combos.dart';
import 'card_upsell_providers.dart';
import 'providers.dart';

/// The catalog the offers are built from: the phone's own copy, else the
/// bundled one (web, demo, tests).
final _offersCatalogProvider = FutureProvider<List<CatalogCard>>((ref) async {
  final stored = await ref.watch(upsellCatalogProvider.future);
  if (stored.isNotEmpty) return stored;
  try {
    return CardCatalog.fromJson(
      jsonDecode(await rootBundle.loadString('assets/catalog/cards.json'))
          as Map<String, Object?>,
    ).cards;
  } on Object {
    return const [];
  }
});

/// Every live welcome offer for a card the person does not hold.
final welcomeOffersProvider = FutureProvider<List<WelcomeOffer>>((ref) async {
  final catalog = await ref.watch(_offersCatalogProvider.future);
  final combos = ref.watch(cardCombosProvider).value ?? const [];
  final mine = ref.watch(myCardsProvider).value ?? const [];
  return welcomeOffers(
    catalog,
    now: DateTime.now(),
    comboCardIds: {for (final c in combos) c.id: c.cardIds},
    heldCatalogIds: {
      for (final k in mine)
        if (k.catalogId != null) k.catalogId!,
    },
  );
});

const _watchKey = 'offers.watch';

/// Offers the person wants a reminder for (catalog card ids). Stored on the
/// phone; each one gets a reminder a week and a day before its deadline.
class WatchedOffers extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final db = ref.watch(localDatabaseProvider);
    final raw = db == null ? null : await db.setting(_watchKey);
    return {...?raw?.split(',').where((s) => s.isNotEmpty)};
  }

  Future<void> toggle(WelcomeOffer offer) async {
    final next = {...?state.value};
    if (!next.remove(offer.card.id)) next.add(offer.card.id);
    state = AsyncData(next);
    await ref
        .read(localDatabaseProvider)
        ?.putSetting(_watchKey, next.join(','));
    await reschedule(offers: await ref.read(welcomeOffersProvider.future));
  }

  /// Re-registers every reminder; safe to call often (each call replaces the
  /// last). A card no longer on offer has its reminders cancelled.
  Future<void> reschedule({required List<WelcomeOffer> offers}) async {
    final reminders = ref.read(remindersProvider);
    final watched = state.value ?? await future;
    final now = DateTime.now();
    for (final o in offers) {
      final ids = [
        for (var i = 0; i < 2; i++)
          notificationIdFor('welcome-offer:${o.card.id}:$i'),
      ];
      for (final id in ids) {
        await reminders.cancel(id);
      }
      final until = o.validUntil;
      if (until == null || !watched.contains(o.card.id)) continue;
      for (final t in offerReminderTimes(until, now)) {
        final lastDay = t.daysBefore == 1;
        await reminders.schedule(
          id: ids[lastDay ? 1 : 0],
          title: lastDay
              ? 'Ends tomorrow: ${o.card.issuer} ${o.card.name}'
              : 'A week left to apply: ${o.card.issuer} ${o.card.name}',
          body:
              'The welcome offer ends on ${until.day}/${until.month}/${until.year}. Open Pulse to see the terms.',
          at: t.at,
        );
      }
    }
  }
}

final watchedOffersProvider = AsyncNotifierProvider<WatchedOffers, Set<String>>(
  WatchedOffers.new,
);
