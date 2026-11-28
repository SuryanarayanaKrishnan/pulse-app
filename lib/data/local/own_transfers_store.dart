import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/engine/own_transfers.dart';
import '../../core/engine/types.dart';
import 'database.dart';

List<String> _tags(TxRow t) => [
  for (final x in jsonDecode(t.tags) as List) '$x',
];

String? _linkOf(List<String> tags) {
  for (final t in tags) {
    if (t.startsWith(linkTagPrefix)) return t.substring(linkTagPrefix.length);
  }
  return null;
}

String _origOf(List<String> tags) {
  for (final t in tags) {
    if (t.startsWith(origCategoryTagPrefix)) {
      return t.substring(origCategoryTagPrefix.length);
    }
  }
  return '';
}

/// True when the stored line has been seen as money moving between own
/// accounts or paying an own card.
bool isOwnTransfer(TxRow t) => _tags(t).contains(ownTransferTag);

/// The category a line should count in for card rewards: a card bill paid from
/// a card through a wallet earns as what it was captured as (Tabby repaid
/// from SIB earns SIB's online rate), everything else as its own category.
String? rewardCategoryId(TxRow t) {
  final tags = _tags(t);
  if (!tags.contains(rewardableTag)) return t.categoryId;
  final o = _origOf(tags);
  return o.isEmpty ? null : o;
}

/// Looks at the stored line [txId] and, when it is money moving between the
/// user's own accounts or paying one of their cards, takes it out of spending
/// and budgets, pairs it with its other leg, and queues it for one-tap review.
///
/// [text] is the full captured text when the caller has it. Returns the
/// verdict, or null when the line is ordinary spending or income.
Future<OwnTransferVerdict?> detectOwnTransfer(
  PulseDatabase db,
  String txId, {
  String? text,
}) async {
  final t = await (db.select(
    db.transactions,
  )..where((x) => x.id.equals(txId))).getSingleOrNull();
  if (t == null || t.deletedAt != null) return null;
  if (_tags(t).contains(ownTransferTag)) return null;

  final accts = await (db.select(
    db.accounts,
  )..where((a) => a.deletedAt.isNull())).get();
  final refs = [
    for (final a in accts)
      OwnAccountRef(
        id: a.id,
        type: a.type,
        institution: a.institution,
        name: a.name,
        last4: a.last4,
      ),
  ];
  final source = refs.where((r) => r.id == t.accountId).firstOrNull;
  if (source == null) return null;
  final direction = Direction.tryParse(t.direction) ?? Direction.debit;

  var verdict = classifyOwnTransfer(
    merchant: t.merchantRaw,
    text: text,
    direction: direction,
    source: source,
    accounts: refs,
  );

  // Nearby lines on other accounts, for pairing.
  final from = t.postedAt.subtract(pairWindow);
  final to = t.postedAt.add(pairWindow);
  final near =
      await (db.select(db.transactions)..where(
            (x) =>
                x.deletedAt.isNull() &
                x.id.equals(t.id).not() &
                x.accountId.equals(t.accountId).not() &
                x.currency.equals(t.currency) &
                x.amountMinor.equals(t.amountMinor) &
                x.postedAt.isBetweenValues(from, to),
          ))
          .get();
  final byId = {for (final n in near) n.id: n};
  TransferLeg legOf(TxRow x) => TransferLeg(
    id: x.id,
    accountId: x.accountId,
    amountMinor: x.amountMinor,
    currency: x.currency,
    direction: Direction.tryParse(x.direction) ?? Direction.debit,
    postedAt: x.postedAt,
    flagged: _tags(x).contains(ownTransferTag),
    linked: _linkOf(_tags(x)) != null,
    accountIsCard: refs.any((r) => r.id == x.accountId && r.isCard),
  );
  final me = legOf(t);

  // A leg that looked ordinary is still the other half of a flagged line.
  TxRow? other;
  if (verdict == null) {
    final hit = findOtherLeg(me, [
      for (final n in near)
        if (_tags(n).contains(ownTransferTag)) legOf(n),
    ]);
    if (hit == null) return null;
    other = byId[hit.id];
    final kind = OwnTransferKind.fromTags(_tags(other!));
    if (kind == null) return null;
    verdict = OwnTransferVerdict(
      kind,
      'Matches a payment between your own accounts',
    );
  } else {
    // Flagged lines pair with another flagged leg, with the account they name,
    // or with a credit into a card (a bill) / a credit on a bank account.
    final named = verdict.counterpartyId;
    final hit = findOtherLeg(me, [
      for (final n in near)
        if (_tags(n).contains(ownTransferTag) ||
            n.accountId == named ||
            (verdict.kind == OwnTransferKind.cardBill &&
                direction == Direction.debit &&
                n.direction == 'credit' &&
                refs.any((r) => r.id == n.accountId && r.isCard)) ||
            (verdict.kind == OwnTransferKind.ownAccount &&
                refs.any((r) => r.id == n.accountId && !r.isCard)))
          legOf(n),
    ]);
    if (hit != null) other = byId[hit.id];
  }

  final cats = await db.select(db.categories).get();
  final bySlug = {
    for (final c in cats)
      if (c.slug != null) c.slug!: c.id,
  };
  final catId = bySlug[verdict.kind.categorySlug];

  Future<void> mark(
    TxRow x, {
    required String? linkTo,
    required bool askAbout,
    required bool rewardable,
  }) {
    final before = _tags(x);
    // A line already seen as a movement keeps what it was before that.
    final orig = before.any((s) => s.startsWith(origCategoryTagPrefix))
        ? _origOf(before)
        : (x.categoryId ?? '');
    final tags = before
      ..removeWhere(
        (s) =>
            s.startsWith(linkTagPrefix) || s.startsWith(origCategoryTagPrefix),
      )
      ..addAll([
        ownTransferTag,
        verdict!.kind.tag,
        if (linkTo != null) '$linkTagPrefix$linkTo',
        '$origCategoryTagPrefix$orig',
        if (rewardable) rewardableTag,
      ]);
    return (db.update(db.transactions)..where((r) => r.id.equals(x.id))).write(
      TransactionsCompanion(
        tags: Value(jsonEncode(tags.toSet().toList())),
        categoryId: Value(catId ?? x.categoryId),
        excludeFromBudget: const Value(true),
        // The debit is the one question; the credit rides along.
        reviewed: Value(!askAbout),
      ),
    );
  }

  bool paidByCard(TxRow x) =>
      x.direction == 'debit' &&
      verdict!.kind == OwnTransferKind.cardBill &&
      refs.any((r) => r.id == x.accountId && r.isCard);

  await db.transaction(() async {
    final iAmDebit = direction == Direction.debit;
    await mark(
      t,
      linkTo: other?.id,
      askAbout: iAmDebit || other == null,
      rewardable: paidByCard(t),
    );
    if (other != null) {
      final otherIsDebit = other.direction == 'debit';
      await mark(
        other,
        linkTo: t.id,
        // Keep an answer the person already gave; otherwise the debit asks.
        askAbout: otherIsDebit && !other.reviewed,
        rewardable: paidByCard(other),
      );
    }
  });
  return verdict;
}

/// "Yes, it is a transfer": the person has looked. Confirms the other leg too.
Future<void> confirmOwnTransfer(PulseDatabase db, String txId) async {
  final t = await (db.select(
    db.transactions,
  )..where((x) => x.id.equals(txId))).getSingleOrNull();
  if (t == null) return;
  final ids = [txId, ?_linkOf(_tags(t))];
  await (db.update(db.transactions)..where((x) => x.id.isIn(ids))).write(
    const TransactionsCompanion(reviewed: Value(true)),
  );
}

/// "No, that was spending": puts the line (and its other leg) back as they
/// were captured, counted again in budgets, and marks them reviewed.
Future<void> revertOwnTransfer(PulseDatabase db, String txId) async {
  final t = await (db.select(
    db.transactions,
  )..where((x) => x.id.equals(txId))).getSingleOrNull();
  if (t == null) return;
  final ids = [txId, ?_linkOf(_tags(t))];
  final rows = await (db.select(
    db.transactions,
  )..where((x) => x.id.isIn(ids))).get();
  await db.transaction(() async {
    for (final x in rows) {
      final tags = _tags(x);
      if (!tags.contains(ownTransferTag)) continue;
      final orig = _origOf(tags);
      tags.removeWhere(
        (s) =>
            s == ownTransferTag ||
            s == cardBillTag ||
            s == ownAccountTag ||
            s == rewardableTag ||
            s.startsWith(linkTagPrefix) ||
            s.startsWith(origCategoryTagPrefix),
      );
      await (db.update(db.transactions)..where((r) => r.id.equals(x.id))).write(
        TransactionsCompanion(
          tags: Value(jsonEncode(tags)),
          categoryId: Value(orig.isEmpty ? null : orig),
          excludeFromBudget: const Value(false),
          reviewed: const Value(true),
        ),
      );
    }
  });
}
