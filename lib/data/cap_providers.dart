import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capture/providers.dart' show kvStoreProvider;
import '../core/household/household_models.dart' show Owner;
import '../household/household_providers.dart' show householdServiceProvider;
import 'local/card_cycles.dart' show PartnerSpend, partnerSpendSource;
import '../core/engine/cap_tracker.dart';
import '../core/engine/dates.dart';
import '../core/engine/next_best.dart';
import '../core/engine/rewards.dart' show nearCapPct;
import 'cap_snapshot.dart';
import 'card_combos.dart';
import 'card_upsell_providers.dart';
import 'models.dart';
import 'providers.dart';

/// Wires a household partner's spend on the same card product into the cap
/// maths (Partnership mode). Read lazily, so nothing runs without a household.
/// Kept out of [repositoryProvider] to avoid a provider cycle.
final partnerSpendWiringProvider = Provider<void>((ref) {
  partnerSpendSource = (catalogId) async {
    final joint = await ref.read(householdServiceProvider).joint();
    if (joint == null) return const [];
    return [
      for (final t in joint.txs)
        if (t.owner != joint.me &&
            t.owner != Owner.shared &&
            t.isDebit &&
            !t.excluded &&
            t.currency == 'AED' &&
            t.cardCatalogId == catalogId)
          PartnerSpend(
            at: t.postedAt,
            amountMinor: t.amountMinor,
            categoryId: t.categoryId,
            merchant: t.merchant,
          ),
    ];
  };
});

/// Cap state of every owned card. On-device it comes from the ledger; for the
/// demo repository it is read from the display model's per-category caps.
final capSnapshotProvider = FutureProvider<CapSnapshot>((ref) async {
  ref.watch(partnerSpendWiringProvider);
  final repo = ref.watch(repositoryProvider);
  ref.watch(transactionsProvider);
  if (repo is CapSource) return (repo as CapSource).capSnapshot();
  final cards = await ref.watch(myCardsProvider.future);
  final now = DateTime.now();
  final today = CalDate(now.year, now.month, now.day);
  final (start, end) = (
    CalDate(today.year, today.month, 1),
    CalDate(today.year, today.month, 28),
  );
  return CapSnapshot(
    today: today,
    cards: [for (final c in cards) _fromModel(c, start, end)],
  );
});

CardCapStatus _fromModel(CreditCard c, CalDate start, CalDate end) {
  final seen = <double>{};
  final meters = <CapMeter>[];
  for (final e in c.caps.entries) {
    // Categories of one rule share a cap: one meter for each distinct cap.
    if (!seen.add(e.value.limit * 1000 + e.value.used)) continue;
    meters.add(
      CapMeter(
        id: e.key.id,
        label: e.key.label,
        isTotal: false,
        capAed: e.value.limit,
        earnedAed: e.value.used,
        rate: (c.categoryRates[e.key] ?? 0) > 0
            ? c.categoryRates[e.key]! / 100
            : null,
        spentAed: 0,
        categories: {e.key.id},
        approxSpend: false,
        isCashback: true,
      ),
    );
  }
  return CardCapStatus(
    cardId: c.id,
    catalogId: c.catalogId,
    title: '${c.issuer} ${c.name}',
    cycleStart: start,
    cycleEnd: end,
    basis: CycleBasis.calendarAssumed,
    spendAed: 0,
    earnedAed: c.rewardValueAed,
    meters: meters,
  );
}

/// Catalog products whose cap sharing the user turned off. Empty by default:
/// a primary and its supplementary card pool one cap.
final separateCapCatalogsProvider = FutureProvider<Set<String>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  if (repo is CapShareSettings) {
    return repo.separateCapCatalogs();
  }
  return <String>{};
});

Future<void> setCapShared(WidgetRef ref, String catalogId, bool shared) async {
  final repo = ref.read(repositoryProvider);
  if (repo is! CapShareSettings) return;
  await repo.setCapShared(catalogId, shared);
  ref.invalidate(separateCapCatalogsProvider);
  ref.invalidate(capSnapshotProvider);
}

/// Catalog products a household partner holds a supplementary card of.
final partnerCapCatalogsProvider = FutureProvider<Set<String>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  if (repo is CapShareSettings) {
    return repo.partnerCapCatalogs();
  }
  return <String>{};
});

Future<void> setPartnerHolds(WidgetRef ref, String catalogId, bool holds) async {
  final repo = ref.read(repositoryProvider);
  if (repo is! CapShareSettings) return;
  await repo.setPartnerHolds(catalogId, holds);
  ref.invalidate(partnerCapCatalogsProvider);
  ref.invalidate(capSnapshotProvider);
}

/// Combos the user holds at least two cards of, with their legs' caps added.
final capStacksProvider = FutureProvider<List<(String, StackCapStatus)>>((
  ref,
) async {
  final snap = await ref.watch(capSnapshotProvider.future);
  final combos = ref.watch(cardCombosProvider).value ?? const <CardCombo>[];
  final byCatalog = {
    for (final c in snap.cards)
      if (c.catalogId != null) c.catalogId!: c,
  };
  final out = <(String, StackCapStatus)>[];
  for (final combo in combos) {
    if (combo.isWarning) continue;
    final legs = [
      for (final id in combo.cardIds)
        if (byCatalog[id] != null) byCatalog[id]!,
    ];
    if (legs.length < 2) continue;
    final label = stackLabel([for (final l in legs) l.title.split(' ').first]);
    out.add((combo.id, stackCapStatus(label, legs)));
  }
  return out;
});

/// What the user told us about cap alerts, kept on this phone: cards muted for
/// good, alerts dismissed for this month, and notifications already sent.
class CapAlertPrefsState {
  const CapAlertPrefsState({
    this.muted = const {},
    this.dismissed = const {},
    this.sent = const {},
  });
  final Set<String> muted;
  final Set<String> dismissed;
  final Set<String> sent;
}

const capPrefsKey = 'caps.prefs';

class CapAlertPrefs extends AsyncNotifier<CapAlertPrefsState> {
  @override
  Future<CapAlertPrefsState> build() async {
    try {
      final raw = await ref.read(kvStoreProvider).read(capPrefsKey);
      if (raw == null) return const CapAlertPrefsState();
      final j = jsonDecode(raw) as Map<String, dynamic>;
      Set<String> set(String k) => {
        for (final x in (j[k] as List? ?? const [])) '$x',
      };
      return CapAlertPrefsState(
        muted: set('muted'),
        dismissed: set('dismissed'),
        sent: set('sent'),
      );
    } on Object {
      return const CapAlertPrefsState();
    }
  }

  CapAlertPrefsState get _cur => state.value ?? const CapAlertPrefsState();

  Future<void> _save(CapAlertPrefsState s) async {
    state = AsyncData(s);
    try {
      await ref
          .read(kvStoreProvider)
          .write(
            capPrefsKey,
            jsonEncode({
              'muted': s.muted.toList()..sort(),
              // Only this month's keys matter; keep the lists short.
              'dismissed': s.dismissed.toList()..sort(),
              'sent': (s.sent.toList()..sort()).reversed.take(60).toList(),
            }),
          );
    } on Object {
      // Preferences are a convenience; the in-memory state still applies.
    }
  }

  Future<void> mute(String cardId) => _save(
    CapAlertPrefsState(
      muted: {..._cur.muted, cardId},
      dismissed: _cur.dismissed,
      sent: _cur.sent,
    ),
  );
  Future<void> unmute(String cardId) => _save(
    CapAlertPrefsState(
      muted: {..._cur.muted}..remove(cardId),
      dismissed: _cur.dismissed,
      sent: _cur.sent,
    ),
  );
  Future<void> dismiss(String key) => _save(
    CapAlertPrefsState(
      muted: _cur.muted,
      dismissed: {..._cur.dismissed, key},
      sent: _cur.sent,
    ),
  );
  Future<void> markSent(Iterable<String> keys) => _save(
    CapAlertPrefsState(
      muted: _cur.muted,
      dismissed: _cur.dismissed,
      sent: {..._cur.sent, ...keys},
    ),
  );
}

final capAlertPrefsProvider =
    AsyncNotifierProvider<CapAlertPrefs, CapAlertPrefsState>(CapAlertPrefs.new);

/// Alerts to show in the app: near and hit, minus muted cards and ones the
/// user dismissed.
final capAlertsProvider = FutureProvider<List<CapAlert>>((ref) async {
  final snap = await ref.watch(capSnapshotProvider.future);
  final stacks = await ref.watch(capStacksProvider.future);
  final prefs = await ref.watch(capAlertPrefsProvider.future);
  final all = capAlerts(snap.cards, stacks: stacks, muted: prefs.muted);
  return [
    for (final a in all)
      if (!prefs.dismissed.contains(a.key)) a,
  ];
});

/// Sends a local notification for each alert not sent before, once. Called
/// whenever the alerts change.
Future<void> dispatchCapNotifications(Ref ref, List<CapAlert> alerts) async {
  final prefs = await ref.read(capAlertPrefsProvider.future);
  final fresh = unsentAlerts(alerts, prefs.sent);
  if (fresh.isEmpty) return;
  final reminders = ref.read(remindersProvider);
  for (final a in fresh) {
    try {
      await reminders.schedule(
        id: 0x2000000 + (a.key.hashCode & 0xFFFFFF),
        title: a.level == CapLevel.hit
            ? 'Cashback cap reached'
            : 'Nearly at a cashback cap',
        body: '${a.message}. Open Pulse for the next best card.',
        at: DateTime.now().add(const Duration(seconds: 3)),
      );
    } on Object {
      // No permission or no plugin: the in-app status still shows.
    }
  }
  await ref
      .read(capAlertPrefsProvider.notifier)
      .markSent(fresh.map((a) => a.key));
}

/// The forecast-based next-best plan: what the user holds against the cards
/// they do not, on the spend still to come this month. Null when there is
/// nothing to rank against.
final nextBestProvider = FutureProvider<NextBestPlan?>((ref) async {
  final entries = await ref.watch(upsellCatalogProvider.future);
  if (entries.isEmpty) return null;
  final snap = await ref.watch(capSnapshotProvider.future);
  if (snap.held.isEmpty) return null;
  final dismissed = await ref.watch(dismissedUpsellsProvider.future);
  final txs = ref.watch(transactionsProvider).value ?? const <Transaction>[];
  var budget = <String, int>{};
  try {
    final rows = (await ref.watch(budgetPlanProvider.future)).rows;
    budget = {for (final r in rows) r.id: r.line.plannedMinor};
  } on Object {
    budget = {};
  }
  final forecast = forecastRemainingSpend(
    history: snap.history,
    today: snap.today,
    budgetMinor: budget,
  );
  final afterCap = snap.cards.any((c) => c.level == CapLevel.hit);
  return rankNextBest(
    forecast: forecast,
    held: snap.held,
    catalog: entries,
    heldCatalogIds: snap.heldCatalogIds,
    dismissedIds: dismissed,
    unavailableIssuers: ref.watch(upsellUnavailableIssuersProvider),
    salaryMinor: estimateSalaryMinor(txs, DateTime.now()),
    afterCap: afterCap,
  );
});

/// Cards at or past [nearCapPct] of a cap, worst first: what Home and the
/// Cards tab headline.
final capWatchProvider = FutureProvider<List<CardCapStatus>>((ref) async {
  final snap = await ref.watch(capSnapshotProvider.future);
  final out = [
    for (final c in snap.cards)
      if (c.level != CapLevel.ok) c,
  ]..sort((a, b) => b.worst!.pct.compareTo(a.worst!.pct));
  return out;
});

/// Watching this sends any new near/hit alerts as local notifications (once
/// each). Home watches it, so alerts go out whenever the app opens or the
/// ledger changes.
final capNotifyProvider = FutureProvider<void>((ref) async {
  final alerts = await ref.watch(capAlertsProvider.future);
  await dispatchCapNotifications(ref, alerts);
});
