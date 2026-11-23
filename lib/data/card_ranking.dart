import 'card_util.dart';
import 'models.dart';

enum CardSort {
  use('Use'),
  rewards('Rewards'),
  returns('Return');

  const CardSort(this.label);
  final String label;
}

/// How one card is doing for you this month.
class CardStanding {
  const CardStanding({
    required this.card,
    required this.spend,
    required this.share,
    required this.rewards,
    required this.count,
  });
  final CreditCard card;
  final double spend;

  /// Share of all card spend this month, 0..1.
  final double share;

  /// Rewards earned this month in AED, caps applied in date order.
  final double rewards;
  final int count;

  double get monthlyFee => card.annualFee / 12;

  /// (rewards − monthly share of the annual fee) ÷ spend, in percent.
  double get netReturnPct =>
      spend <= 0 ? 0 : (rewards - monthlyFee) / spend * 100;

  /// Rewards at this pace over a year.
  double get annualRewards => rewards * 12;

  /// Carries a fee its rewards do not pay for.
  bool get feeNotCovered =>
      card.annualFee > 0 && annualRewards < card.annualFee;

  /// Barely used: under 10% of card spend.
  bool get underused => share < 0.1;

  /// One line of advice, or null when the card earns its place.
  String? get warning {
    if (feeNotCovered) {
      return 'Earns about AED ${annualRewards.round()} a year against an AED '
          '${card.annualFee.round()} fee';
    }
    if (underused && card.annualFee > 0) {
      return 'Rarely used for a card with a fee';
    }
    if (underused) return 'Rarely used';
    return null;
  }
}

/// Rewards on [txs] for [card], applying its monthly caps from zero in date
/// order and the base rate past each cap.
double earnedOn(CreditCard card, Iterable<Transaction> txs) {
  final used = <SpendCategory, double>{};
  var total = 0.0;
  final sorted = txs.toList()..sort((a, b) => a.date.compareTo(b.date));
  for (final t in sorted) {
    final rate = rateFor(card, t.category);
    final full = t.amount * rate / 100;
    final cap = card.caps[t.category];
    if (cap == null) {
      total += full;
      continue;
    }
    final left = (cap.limit - (used[t.category] ?? 0)).clamp(0.0, cap.limit);
    if (full <= left) {
      total += full;
      used[t.category] = (used[t.category] ?? 0) + full;
    } else {
      final cappedSpend = rate == 0 ? 0 : left / (rate / 100);
      total += left + (t.amount - cappedSpend) * card.baseRate / 100;
      used[t.category] = cap.limit;
    }
  }
  return total;
}

bool _counts(Transaction t) =>
    !t.isIncome && !t.excluded && !t.category.isTransfer;

/// Every card's standing for the month of [now], sorted by [sort].
List<CardStanding> cardStandings(
  List<CreditCard> cards,
  List<Transaction> txs, {
  CardSort sort = CardSort.use,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final month = [
    for (final t in txs)
      if (_counts(t) && t.date.year == n.year && t.date.month == n.month) t,
  ];
  final ids = {for (final c in cards) c.id};
  final total = month
      .where((t) => ids.contains(t.cardId))
      .fold<double>(0, (a, t) => a + t.amount);
  final out = [
    for (final c in cards)
      () {
        final mine = month.where((t) => t.cardId == c.id).toList();
        final spend = mine.fold<double>(0, (a, t) => a + t.amount);
        return CardStanding(
          card: c,
          spend: spend,
          share: total == 0 ? 0 : spend / total,
          rewards: earnedOn(c, mine),
          count: mine.length,
        );
      }(),
  ];
  int by(CardStanding a, CardStanding b) => switch (sort) {
    CardSort.use => b.spend.compareTo(a.spend),
    CardSort.rewards => b.rewards.compareTo(a.rewards),
    CardSort.returns => b.netReturnPct.compareTo(a.netReturnPct),
  };
  return out..sort(by);
}

/// The everyday categories the ranked page answers, with plain names.
const bestCardCategories = <(SpendCategory, String)>[
  (SpendCategory.groceries, 'Groceries'),
  (SpendCategory.dining, 'Dining'),
  (SpendCategory.transport, 'Fuel'),
  (SpendCategory.travel, 'Travel'),
  (SpendCategory.shopping, 'Online'),
  (SpendCategory.utilities, 'Bills'),
];
