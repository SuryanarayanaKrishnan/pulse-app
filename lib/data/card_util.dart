import 'models.dart';

/// Advertised reward rate (percent) for [category].
double rateFor(CreditCard c, SpendCategory category) =>
    c.categoryRates[category] ?? c.baseRate;

/// The rate the next purchase actually earns: the base rate once the
/// category's monthly cap is used up.
double effectiveRate(CreditCard c, SpendCategory category) {
  final cap = c.caps[category];
  if (cap != null && cap.reached) return c.baseRate;
  return rateFor(c, category);
}

/// Reward (AED) for spending [amount] in [category], respecting the cap.
double rewardFor(CreditCard c, SpendCategory category, double amount) {
  final cap = c.caps[category];
  final full = amount * rateFor(c, category) / 100;
  if (cap == null) return full;
  if (cap.reached) return amount * c.baseRate / 100;
  if (full <= cap.remaining) return full;
  // Part at the category rate until the cap, the rest at the base rate.
  final cappedSpend = cap.remaining / (rateFor(c, category) / 100);
  return cap.remaining + (amount - cappedSpend) * c.baseRate / 100;
}

/// Cards ranked best-first for [category], cap-aware.
List<CreditCard> rankCardsFor(List<CreditCard> cards, SpendCategory category) =>
    List.of(cards)..sort(
      (a, b) =>
          effectiveRate(b, category).compareTo(effectiveRate(a, category)),
    );

String formatRate(double r) => '${r.toStringAsFixed(r % 1 == 0 ? 0 : 1)}%';

/// Pre-purchase advice: which card to use for [category].
class CardAdvice {
  const CardAdvice({
    required this.best,
    required this.rate,
    required this.reason,
    this.runnerUp,
    this.runnerUpRate,
    this.estimate,
  });
  final CreditCard best;
  final double rate;
  final String reason;
  final CreditCard? runnerUp;
  final double? runnerUpRate;

  /// Reward on the given amount, when one was given.
  final double? estimate;
}

CardAdvice? adviseCard(
  List<CreditCard> cards,
  SpendCategory category, {
  double? amount,
}) {
  if (cards.isEmpty) return null;
  final ranked = rankCardsFor(cards, category);
  final best = ranked.first;
  final rate = effectiveRate(best, category);
  final second = ranked.length > 1 ? ranked[1] : null;
  final cap = best.caps[category];
  final cappedOut = [
    for (final c in cards)
      if (c.caps[category]?.reached ?? false) c,
  ];
  String reason;
  if (cappedOut.isNotEmpty && !cappedOut.contains(best)) {
    final c = cappedOut.first;
    reason =
        '${c.issuer} ${c.name} has used its ${category.label.toLowerCase()} cap this month';
  } else if (cap != null) {
    reason =
        'AED ${cap.remaining.toStringAsFixed(0)} of reward left before its monthly cap';
  } else {
    reason = 'No cap on ${category.label.toLowerCase()}';
  }
  return CardAdvice(
    best: best,
    rate: rate,
    reason: reason,
    runnerUp: second,
    runnerUpRate: second == null ? null : effectiveRate(second, category),
    estimate: amount == null ? null : rewardFor(best, category, amount),
  );
}

/// What a card tap earned, shown right after capture.
class RewardMoment {
  const RewardMoment({
    required this.merchant,
    required this.amount,
    required this.card,
    required this.category,
    required this.earned,
    required this.rate,
    this.cap,
    this.nudge,
  });
  final String merchant;
  final double amount;
  final CreditCard card;
  final SpendCategory category;
  final double earned;
  final double rate;

  /// The category cap after this purchase.
  final RewardCap? cap;

  /// "Use X for the next dining purchase (+3% vs +0.5%)", when another card
  /// would now earn more.
  final String? nudge;
}

/// Builds the moment for a purchase of [amount] in [category] on [card]
/// (with the card's caps *before* the purchase).
RewardMoment rewardMoment({
  required List<CreditCard> cards,
  required CreditCard card,
  required String merchant,
  required SpendCategory category,
  required double amount,
}) {
  final earned = rewardFor(card, category, amount);
  final capBefore = card.caps[category];
  final capAfter = capBefore?.add(earned);
  final after = capAfter == null
      ? card
      : card.copyWith(caps: {...card.caps, category: capAfter});
  final nextRate = effectiveRate(after, category);
  final others = [
    for (final c in cards)
      if (c.id != card.id) c,
  ];
  String? nudge;
  if (others.isNotEmpty) {
    final alt = rankCardsFor(others, category).first;
    final altRate = effectiveRate(alt, category);
    if (altRate > nextRate) {
      final lead = (capAfter?.reached ?? false)
          ? 'Cap reached on this card. '
          : '';
      nudge =
          '${lead}Use ${alt.issuer} ${alt.name} for your next '
          '${category.label.toLowerCase()} purchase '
          '(+${formatRate(altRate)} vs +${formatRate(nextRate)})';
    }
  }
  return RewardMoment(
    merchant: merchant,
    amount: amount,
    card: card,
    category: category,
    earned: earned,
    rate: amount == 0 ? 0 : earned / amount * 100,
    cap: capAfter,
    nudge: nudge,
  );
}

/// Due-date view of a card.
class DueInfo {
  const DueInfo({
    required this.card,
    required this.daysLeft,
    required this.payBy,
    required this.minDue,
    required this.totalDue,
    required this.today,
  });
  final CreditCard card;
  final int daysLeft;
  final DateTime today;

  /// One banking day before the due date, so the payment lands in time.
  final DateTime payBy;
  final double minDue;
  final double totalDue;

  bool get urgent => daysLeft <= 5;
  bool get overdue => daysLeft < 0;

  String get nudge {
    if (overdue) return 'Overdue. Pay at least the minimum today';
    if (daysLeft == 0)
      return 'Due today. Pay the full amount to avoid interest';
    final d = payBy.difference(today).inDays;
    if (d <= 0) return 'Pay today to land before the due date';
    return 'Pay in full within $d ${d == 1 ? 'day' : 'days'} to avoid interest';
  }
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DueInfo dueInfo(CreditCard c, {DateTime? today}) {
  final t = today ?? _today();
  final due = DateTime(c.dueDate.year, c.dueDate.month, c.dueDate.day);
  return DueInfo(
    card: c,
    daysLeft: due.difference(t).inDays,
    payBy: due.subtract(const Duration(days: 1)),
    minDue: c.minDue,
    totalDue: c.totalDue,
    today: t,
  );
}
