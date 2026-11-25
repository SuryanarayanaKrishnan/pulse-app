import 'card_util.dart';
import 'models.dart';

/// Monthly spend (AED) assumed when the ledger has too little to learn from.
/// Round numbers for a UAE household; the UI says it is typical, not yours.
final typicalMonthlySpend = <SpendCategory, double>{
  SpendCategory.groceries: 1500,
  SpendCategory.dining: 900,
  SpendCategory.transport: 600,
  SpendCategory.shopping: 700,
  SpendCategory.travel: 400,
  SpendCategory.entertainment: 250,
};

class CardSuggestion {
  const CardSuggestion({
    required this.card,
    required this.annualGain,
    required this.topCategory,
    required this.typical,
  });
  final CreditCard card;

  /// Extra rewards a year over the best card you already hold in each
  /// category, minus this card's annual fee. AED.
  final double annualGain;
  final SpendCategory topCategory;

  /// Worked out from a typical profile, not from the user's own spend.
  final bool typical;

  String get reason =>
      '${rateFor(card, topCategory).toStringAsFixed(rateFor(card, topCategory) % 1 == 0 ? 0 : 1)}% on ${topCategory.label.toLowerCase()}'
      '${card.annualFee > 0 ? ', after the AED ${card.annualFee.round()} annual fee' : ', no annual fee'}';
}

/// Average monthly spend per expense category over the last 90 days, or null
/// when there are too few transactions to say anything real.
Map<SpendCategory, double>? learnedMonthlySpend(List<Transaction> txs, DateTime now) {
  final since = now.subtract(const Duration(days: 90));
  final byCat = <SpendCategory, double>{};
  var n = 0;
  for (final t in txs) {
    if (t.isIncome || t.excluded || t.date.isBefore(since)) continue;
    if (t.category.kind != CategoryKind.expense) continue;
    byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
    n++;
  }
  if (n < 15) return null;
  return {for (final e in byCat.entries) e.key: e.value / 3};
}

/// Cards worth adding, best first: what each unowned catalog card would earn on
/// your spend beyond what your current cards already earn, less its fee.
List<CardSuggestion> suggestCards({
  required List<CreditCard> catalog,
  required List<CreditCard> owned,
  required List<Transaction> txs,
  required DateTime now,
  int limit = 3,
}) {
  final learned = learnedMonthlySpend(txs, now);
  final spend = learned ?? typicalMonthlySpend;
  final heldIds = {for (final c in owned) c.catalogId ?? c.id};
  final out = <CardSuggestion>[];
  for (final c in catalog) {
    if (heldIds.contains(c.catalogId ?? c.id)) continue;
    var gain = 0.0;
    SpendCategory? top;
    var topGain = 0.0;
    for (final e in spend.entries) {
      final cand = rewardFor(c, e.key, e.value);
      var have = 0.0;
      for (final o in owned) {
        final r = rewardFor(o, e.key, e.value);
        if (r > have) have = r;
      }
      final g = cand - have;
      if (g > 0) {
        gain += g;
        if (g > topGain) {
          topGain = g;
          top = e.key;
        }
      }
    }
    final annual = gain * 12 - c.annualFee;
    if (annual > 0 && top != null) {
      out.add(CardSuggestion(card: c, annualGain: annual, topCategory: top, typical: learned == null));
    }
  }
  out.sort((a, b) => b.annualGain.compareTo(a.annualGain));
  return out.take(limit).toList();
}
