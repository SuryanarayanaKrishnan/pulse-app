import 'models.dart';

/// Reward rate (percent) for [category]; falls back to a 0.5% base rate.
double rateFor(CreditCard c, SpendCategory category) =>
    c.categoryRates[category] ?? 0.5;

/// Cards ranked best-first for [category].
List<CreditCard> rankCardsFor(List<CreditCard> cards, SpendCategory category) =>
    List.of(cards)
      ..sort((a, b) => rateFor(b, category).compareTo(rateFor(a, category)));
