import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/engine/card_value.dart';
import '../../core/engine/dates.dart';
import '../../core/engine/merchants.dart';
import '../../core/engine/rewards.dart';
import 'card_cycles.dart';
import 'database.dart';

/// Per-card extras for the detail page.
class CardExtras {
  const CardExtras({
    required this.accountId,
    this.feeWaiver,
    this.welcome,
    this.benefits = const [],
    this.hints = const [],
    this.estimated = true,
  });
  final String accountId;
  final MilestoneRing? feeWaiver, welcome;
  final List<Benefit> benefits;
  final List<CardHint> hints;

  /// Built on catalog figures that were not verified against issuer terms.
  final bool estimated;
}

/// Everything the cards pages need, computed on the device.
class CardValueReport {
  const CardValueReport({this.ranking = const [], this.extras = const {}});
  final List<CardNetValue> ranking;
  final Map<String, CardExtras> extras;
  bool get isEmpty => ranking.isEmpty;
}

Map<String, Object?> _json(String raw) {
  try {
    return Map<String, Object?>.from(jsonDecode(raw) as Map);
  } on Object {
    return const {};
  }
}

/// Builds the report for every owned card as of [today].
Future<CardValueReport> buildCardValueReport(
  PulseDatabase db,
  CalDate today,
) async {
  final cards = await loadOwnedCards(db);
  if (cards.isEmpty) return const CardValueReport();
  final yearStart = today.addDays(-364);
  final rankables = await rankablesFor(db, cards, today);
  final inputs = <CardValueInput>[];
  final extras = <String, CardExtras>{};
  for (final (i, c) in cards.indexed) {
    final perks = _json(c.catalog.perks);
    final benefits = parseBenefits(perks);
    final rows =
        await (db.select(db.transactions)
              ..where(
                (t) =>
                    t.accountId.equals(c.account.id) &
                    t.deletedAt.isNull() &
                    t.direction.equals('debit') &
                    t.currency.equals('AED') &
                    t.postedAt.isBiggerOrEqualValue(
                      atDate(yearStart).subtract(const Duration(hours: 12)),
                    ),
              )
              ..orderBy([
                (t) => OrderingTerm.asc(t.postedAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final dated = [
      for (final t in rows)
        DatedSpend(
          toDubaiDate(t.postedAt),
          Spend(
            t.amountMinor,
            rewardSlug(t.categoryId),
            merchantKey(t.merchantNormalized ?? t.merchantRaw),
          ),
        ),
    ];
    final rankStart = cycleBounds(
      today.addDays(-(rankWindowDays - 1)),
      c.account.statementDay,
    ).$1;
    final fee = c.catalog.annualFeeMinor;
    final unverified = c.catalog.verifiedOn == null;
    inputs.add(
      CardValueInput(
        id: c.account.id,
        title: c.title,
        spec: c.spec,
        annualFeeMinor: fee,
        statementDay: c.account.statementDay,
        benefits: benefits,
        unverified: unverified,
        spends: [
          for (final d in dated)
            if (d.date >= rankStart) d,
        ],
      ),
    );
    final yearSpend = dated.fold<int>(0, (s, d) => s + d.spend.amountMinor);
    final bonus = parseWelcomeBonus(perks);
    MilestoneRing? welcome;
    if (bonus != null) {
      final opened = toDubaiDate(c.user.createdAt);
      final since = dated
          .where((d) => d.date >= opened)
          .fold<int>(0, (s, d) => s + d.spend.amountMinor);
      welcome = welcomeBonusRing(bonus, opened, today, since);
    }
    final self = rankables[i];
    extras[c.account.id] = CardExtras(
      accountId: c.account.id,
      feeWaiver: feeWaiverRing(c.spec, fee, yearSpend),
      welcome: welcome,
      benefits: benefits,
      hints: cardHints(
        card: self,
        all: rankables,
        cycleEnd: cycleBounds(today, c.account.statementDay).$2,
      ),
      estimated: unverified,
    );
  }
  return CardValueReport(
    ranking: rankByNetValue(inputs, today),
    extras: extras,
  );
}
