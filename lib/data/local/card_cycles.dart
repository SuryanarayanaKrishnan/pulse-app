import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/engine/cap_tracker.dart';
import '../../core/engine/dates.dart';
import '../../core/engine/merchants.dart';
import '../../core/engine/next_best.dart' show LedgerSpend;
import '../../core/engine/rewards.dart';
import 'database.dart';
import 'own_transfers_store.dart';

/// A card the user owns: the wallet entry, its account and the catalog
/// product whose reward rules apply.
class OwnedCard {
  OwnedCard(this.user, this.account, this.catalog, this.spec, this.order);
  final UserCardRow user;
  final AccountRow account;
  final CatalogCardRow catalog;
  final CardSpec spec;
  final int order;

  String get title => '${catalog.issuer} ${catalog.name}';
}

/// Category slug used by reward rules for [categoryId] (custom ids count as
/// `other`).
String rewardSlug(String? categoryId) =>
    (categoryId == null || categoryId.startsWith('c_')) ? 'other' : categoryId;

/// Every non-deleted user card with a usable catalog entry, oldest first.
Future<List<OwnedCard>> loadOwnedCards(PulseDatabase db) async {
  final users =
      await (db.select(db.userCards)
            ..where((u) => u.deletedAt.isNull() & u.accountId.isNotNull())
            ..orderBy([
              (u) => OrderingTerm.asc(u.createdAt),
              (u) => OrderingTerm.asc(u.id),
            ]))
          .get();
  final out = <OwnedCard>[];
  for (final u in users) {
    final acct =
        await (db.select(db.accounts)
              ..where((a) => a.id.equals(u.accountId!) & a.deletedAt.isNull()))
            .getSingleOrNull();
    final cat = await (db.select(
      db.catalogCards,
    )..where((c) => c.id.equals(u.catalogCardId))).getSingleOrNull();
    if (acct == null || cat == null) continue;
    try {
      final spec = parseStructure(
        Map<String, Object?>.from(jsonDecode(cat.rewardStructure) as Map),
      );
      out.add(OwnedCard(u, acct, cat, spec, out.length));
    } on Object {
      continue;
    }
  }
  return out;
}

/// Setting key: JSON list of catalog card ids whose caps are NOT shared
/// between cards of the same product in the wallet.
const capSeparateKey = 'caps.separate_catalogs';

Future<Set<String>> separateCapCatalogs(PulseDatabase db) async {
  try {
    final raw = await db.setting(capSeparateKey);
    if (raw == null) return {};
    return {for (final x in jsonDecode(raw) as List) '$x'};
  } on Object {
    return {};
  }
}

Future<void> setCapShared(
  PulseDatabase db,
  String catalogId,
  bool shared,
) async {
  final cur = await separateCapCatalogs(db);
  shared ? cur.remove(catalogId) : cur.add(catalogId);
  await db.putSetting(capSeparateKey, jsonEncode(cur.toList()..sort()));
}

/// Setting key: JSON list of catalog card ids the user's household partner
/// holds a supplementary card of (their spend on it joins this card's cap).
const capPartnerKey = 'caps.partner_catalogs';

Future<Set<String>> partnerCapCatalogs(PulseDatabase db) async {
  try {
    final raw = await db.setting(capPartnerKey);
    if (raw == null) return {};
    return {for (final x in jsonDecode(raw) as List) '$x'};
  } on Object {
    return {};
  }
}

Future<void> setPartnerHolds(
  PulseDatabase db,
  String catalogId,
  bool holds,
) async {
  final cur = await partnerCapCatalogs(db);
  holds ? cur.add(catalogId) : cur.remove(catalogId);
  await db.putSetting(capPartnerKey, jsonEncode(cur.toList()..sort()));
}

/// A household partner's card spend on one product, as the household log
/// shares it (category and merchant, never card digits).
class PartnerSpend {
  const PartnerSpend({
    required this.at,
    required this.amountMinor,
    this.categoryId,
    this.merchant = '',
  });
  final DateTime at;
  final int amountMinor;
  final String? categoryId;
  final String merchant;
}

/// Where partner spend comes from; set once at app start from the household.
/// Null (the default, and in tests) means no partner spend.
typedef PartnerSpendSource = Future<List<PartnerSpend>> Function(
  String catalogId,
);
PartnerSpendSource? partnerSpendSource;

/// Accounts whose spend counts toward [card]'s caps. Partnership mode: a
/// primary card and its supplementary card are two wallet entries of the same
/// catalog product; the issuer pays one cap to the primary's account, so
/// their spend is pooled unless the user turned sharing off for that product.
/// Always contains the card's own account.
Future<Set<String>> capAccountIds(PulseDatabase db, OwnedCard card) async {
  final own = card.account.id;
  if ((await separateCapCatalogs(db)).contains(card.catalog.id)) return {own};
  final rows =
      await (db.select(db.userCards)..where(
            (u) =>
                u.catalogCardId.equals(card.catalog.id) &
                u.deletedAt.isNull() &
                u.accountId.isNotNull(),
          ))
          .get();
  final ids = {for (final r in rows) r.accountId!};
  if (ids.length < 2) return {own};
  final live = await (db.select(
    db.accounts,
  )..where((a) => a.id.isIn(ids.toList()) & a.deletedAt.isNull())).get();
  return {own, for (final a in live) a.id};
}

/// One card's spends in the reward cycle around [today], oldest first, with
/// the cycle's dates and basis (calendar or statement, see [resolveCycle]).
Future<({List<Spend> spends, CalDate start, CalDate end, CycleBasis basis})>
cycleSpends(
  PulseDatabase db,
  OwnedCard card,
  CalDate today, {
  String? excludeTxId,
}) async {
  final (from, to, basis) = resolveCycle(
    card.spec,
    today,
    card.account.statementDay,
  );
  final start = atDate(from).subtract(const Duration(hours: 12));
  final end = atDate(to).add(const Duration(hours: 12));
  final accounts = (await capAccountIds(db, card)).toList();
  final rows =
      await (db.select(db.transactions)
            ..where(
              (t) =>
                  t.accountId.isIn(accounts) &
                  t.deletedAt.isNull() &
                  t.direction.equals('debit') &
                  t.currency.equals('AED') &
                  t.postedAt.isBiggerOrEqualValue(start) &
                  t.postedAt.isSmallerThanValue(end),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.postedAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
          .get();
  final dated = <(DateTime, Spend)>[
    for (final t in rows)
      if (t.id != excludeTxId)
        (
          t.postedAt,
          Spend(
            t.amountMinor,
            rewardSlug(rewardCategoryId(t)),
            merchantKey(t.merchantNormalized ?? t.merchantRaw),
          ),
        ),
  ];
  // Partnership mode: the partner's supplementary card, from the household.
  final src = partnerSpendSource;
  if (src != null && (await partnerCapCatalogs(db)).contains(card.catalog.id)) {
    try {
      for (final p in await src(card.catalog.id)) {
        if (p.amountMinor <= 0 || p.at.isBefore(start) || !p.at.isBefore(end)) {
          continue;
        }
        dated.add((
          p.at,
          Spend(
            p.amountMinor,
            rewardSlug(p.categoryId),
            merchantKey(p.merchant),
          ),
        ));
      }
      dated.sort((a, b) => a.$1.compareTo(b.$1));
    } on Object {
      // Household unavailable: the card's own spend still counts.
    }
  }
  return (
    spends: [for (final d in dated) d.$2],
    start: from,
    end: to,
    basis: basis,
  );
}

/// Reward cycle state of [card]: spends of the cycle around [today], in
/// chronological order. [excludeTxId] leaves one transaction out ("before").
Future<CycleResult> cycleState(
  PulseDatabase db,
  OwnedCard card,
  CalDate today, {
  String? excludeTxId,
}) async => computeCycle(
  card.spec,
  (await cycleSpends(db, card, today, excludeTxId: excludeTxId)).spends,
);

/// Cap status of every owned card for the cycle around [today].
Future<List<CardCapStatus>> capStatuses(
  PulseDatabase db,
  List<OwnedCard> cards,
  CalDate today,
) async => [
  for (final c in cards)
    await () async {
      final cy = await cycleSpends(db, c, today);
      final group = (await capAccountIds(db, c)).toList()..sort();
      return cardCapStatus(
        sharedWith: group.length > 1 ? group : const [],
        withPartner:
            partnerSpendSource != null &&
            (await partnerCapCatalogs(db)).contains(c.catalog.id),
        cardId: c.account.id,
        catalogId: c.catalog.id,
        title: c.title,
        spec: c.spec,
        spends: cy.spends,
        cycleStart: cy.start,
        cycleEnd: cy.end,
        basis: cy.basis,
      );
    }(),
];

/// Every AED expense of the last [months] months, any account, as the
/// forecast's history. Transfers, card payments and fees are not spend.
Future<List<LedgerSpend>> spendHistory(
  PulseDatabase db,
  CalDate today, {
  int months = 7,
}) async {
  final since = atDate(
    CalDate(today.year, today.month, 1).addDays(-31 * months),
  );
  final rows =
      await (db.select(db.transactions)..where(
            (t) =>
                t.deletedAt.isNull() &
                t.direction.equals('debit') &
                t.currency.equals('AED') &
                t.excludeFromBudget.equals(false) &
                t.postedAt.isBiggerOrEqualValue(since),
          ))
          .get();
  const notSpend = {'cc_payment', 'transfer', 'fees', 'savings', 'family'};
  return [
    for (final t in rows)
      if (!notSpend.contains(rewardSlug(t.categoryId)))
        LedgerSpend(
          toDubaiDate(t.postedAt),
          t.amountMinor,
          rewardSlug(t.categoryId),
        ),
  ];
}

/// All owned cards with their current cycle, ready to rank. With
/// [excludeTxId] that transaction is left out ("before this payment").
Future<List<RankableCard>> rankablesFor(
  PulseDatabase db,
  List<OwnedCard> cards,
  CalDate today, {
  String? excludeTxId,
}) async => [
  for (final c in cards)
    RankableCard(
      id: c.account.id,
      title: c.title,
      spec: c.spec,
      state: await cycleState(db, c, today, excludeTxId: excludeTxId),
      createdOrder: c.order,
    ),
];

Future<List<RankableCard>> rankables(
  PulseDatabase db,
  List<OwnedCard> cards,
  CalDate today,
) => rankablesFor(db, cards, today);
