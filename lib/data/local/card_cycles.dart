import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/engine/dates.dart';
import '../../core/engine/merchants.dart';
import '../../core/engine/rewards.dart';
import 'database.dart';

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
  final users = await (db.select(db.userCards)
        ..where((u) => u.deletedAt.isNull() & u.accountId.isNotNull())
        ..orderBy([(u) => OrderingTerm.asc(u.createdAt), (u) => OrderingTerm.asc(u.id)]))
      .get();
  final out = <OwnedCard>[];
  for (final u in users) {
    final acct = await (db.select(db.accounts)
          ..where((a) => a.id.equals(u.accountId!) & a.deletedAt.isNull()))
        .getSingleOrNull();
    final cat = await (db.select(db.catalogCards)..where((c) => c.id.equals(u.catalogCardId))).getSingleOrNull();
    if (acct == null || cat == null) continue;
    try {
      final spec = parseStructure(Map<String, Object?>.from(jsonDecode(cat.rewardStructure) as Map));
      out.add(OwnedCard(u, acct, cat, spec, out.length));
    } on Object {
      continue;
    }
  }
  return out;
}

/// Reward cycle state of [card]: spends of the cycle around [today], in
/// chronological order. [excludeTxId] leaves one transaction out ("before").
Future<CycleResult> cycleState(
  PulseDatabase db,
  OwnedCard card,
  CalDate today, {
  String? excludeTxId,
}) async {
  final (from, to) = cycleBounds(today, card.account.statementDay);
  final start = atDate(from).subtract(const Duration(hours: 12));
  final end = atDate(to).add(const Duration(hours: 12));
  final rows = await (db.select(db.transactions)
        ..where(
          (t) =>
              t.accountId.equals(card.account.id) &
              t.deletedAt.isNull() &
              t.direction.equals('debit') &
              t.currency.equals('AED') &
              t.postedAt.isBiggerOrEqualValue(start) &
              t.postedAt.isSmallerThanValue(end),
        )
        ..orderBy([(t) => OrderingTerm.asc(t.postedAt), (t) => OrderingTerm.asc(t.id)]))
      .get();
  return computeCycle(card.spec, [
    for (final t in rows)
      if (t.id != excludeTxId)
        Spend(t.amountMinor, rewardSlug(t.categoryId), merchantKey(t.merchantNormalized ?? t.merchantRaw)),
  ]);
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

Future<List<RankableCard>> rankables(PulseDatabase db, List<OwnedCard> cards, CalDate today) =>
    rankablesFor(db, cards, today);
