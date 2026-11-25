/// "You'd earn more with...": picks ONE catalog card the user does not hold
/// that would earn clearly more for a category (or merchant) than the best
/// card they already hold. Pure Dart, deterministic, no network.
///
/// How the figure is worked out (all in fils, per month, for one fresh
/// statement cycle of [monthlySpendMinor] in the category):
///
///   ownedBest   = best monthly reward over the cards the user holds
///   candidate   = monthly reward of the candidate, caps applied
///   gross       = candidate - ownedBest
///   net / year  = gross * 12 - candidate annual fee   (fee is never waived
///                 in this maths, so the figure errs low)
///   net / month = net / year / 12
///
/// A card is only suggested when `net / month` is at least
/// [UpsellPolicy.minMonthlyGainMinor], or at least [UpsellPolicy.minGainRatio]
/// better than the best owned card (and above [UpsellPolicy.floorMinor], so a
/// tiny base cannot make a few fils look like 50%).
library;

import 'catalog.dart';
import 'institutions.dart' show normName;
import 'rewards.dart';

class UpsellPolicy {
  const UpsellPolicy({
    this.minMonthlyGainMinor = 2500,
    this.minGainRatio = 0.15,
    this.floorMinor = 500,
    this.unknownSalaryMaxMinSalaryMinor = 1500000,
  });

  /// AED 25 a month, net of fee.
  final int minMonthlyGainMinor;

  /// 15% better than the best card already held.
  final double minGainRatio;

  /// The ratio rule needs at least AED 5 a month net.
  final int floorMinor;

  /// Salary unknown: skip cards asking for more than AED 15,000 a month.
  final int unknownSalaryMaxMinSalaryMinor;
}

/// Typical monthly spend (fils) for a category slug, used when the ledger has
/// too little to learn from. Round numbers for a UAE household.
const typicalMonthlySpendMinorByCategory = <String, int>{
  'groceries': 150000,
  'dining': 90000,
  'transport': 60000,
  'shopping': 70000,
  'travel': 40000,
  'entertainment': 25000,
  'health': 30000,
  'utilities': 50000,
};

int typicalMonthlySpendMinor(String? category) =>
    typicalMonthlySpendMinorByCategory[category] ?? 50000;

class CardUpsell {
  const CardUpsell({
    required this.card,
    required this.ownedBest,
    required this.monthlySpendMinor,
    required this.ownedMonthlyMinor,
    required this.candidateMonthlyMinor,
    required this.annualFeeMinor,
    required this.ruleName,
  });

  /// The card not held.
  final CatalogCard card;

  /// The best held card for this spend (null when none earns anything).
  final CatalogCard? ownedBest;
  final int monthlySpendMinor;
  final int ownedMonthlyMinor;
  final int candidateMonthlyMinor;
  final int annualFeeMinor;

  /// The rule of [card] that earns for this spend.
  final String? ruleName;

  int get grossMonthlyMinor => candidateMonthlyMinor - ownedMonthlyMinor;
  int get netYearlyMinor => grossMonthlyMinor * 12 - annualFeeMinor;
  int get netMonthlyMinor => (netYearlyMinor / 12).round();

  /// Net monthly gain over what the best held card earns (1.0 = double).
  double get gainRatio => ownedMonthlyMinor <= 0
      ? double.infinity
      : netMonthlyMinor / ownedMonthlyMinor;
}

/// Monthly reward (fils) of [card] for [spendMinor] in a fresh cycle. A card
/// whose minimum monthly spend is not met by [totalMonthlySpendMinor] earns
/// nothing.
int monthlyRewardMinor(
  CatalogCard card, {
  required int spendMinor,
  required int totalMonthlySpendMinor,
  String? category,
  String? merchantKey,
}) {
  final CardSpec spec;
  try {
    spec = card.spec;
  } on Object {
    return 0;
  }
  if (totalMonthlySpendMinor < spec.minMonthlySpendMinor) return 0;
  final res = computeCycle(spec, [Spend(spendMinor, category, merchantKey)]);
  return spec.valueMinor(res.earnedUnits);
}

/// Can the user plausibly get [card]? Salary known: its minimum must be at or
/// under it. Unknown: the minimum must not be high.
bool isAttainable(
  CatalogCard card, {
  int? salaryMinor,
  UpsellPolicy policy = const UpsellPolicy(),
}) {
  final min = card.minSalaryMinor;
  if (min == null) return true;
  if (salaryMinor != null) return min <= salaryMinor;
  return min <= policy.unknownSalaryMaxMinSalaryMinor;
}

/// Does [gain] clear the thresholds in [policy]?
bool isMeaningful(CardUpsell gain, UpsellPolicy policy) {
  final net = gain.netMonthlyMinor;
  if (net >= policy.minMonthlyGainMinor) return true;
  return net >= policy.floorMinor && gain.gainRatio >= policy.minGainRatio;
}

/// The one card worth mentioning, or null. [owned] are the user's cards as
/// catalog entries; [ownedIds] also excludes held cards the catalog no longer
/// lists. [dismissedIds] are cards the user said "Not interested" to;
/// [unavailableIssuers] are issuers (any spelling) we must not promote.
CardUpsell? suggestUnownedCard({
  required List<CatalogCard> catalog,
  required List<CatalogCard> owned,
  Set<String> ownedIds = const {},
  Set<String> dismissedIds = const {},
  Set<String> unavailableIssuers = const {},
  required String? category,
  String? merchantKey,
  required int monthlySpendMinor,
  int? totalMonthlySpendMinor,
  int? salaryMinor,
  UpsellPolicy policy = const UpsellPolicy(),
}) {
  if (monthlySpendMinor <= 0 || owned.isEmpty) return null;
  final total = totalMonthlySpendMinor ?? monthlySpendMinor;
  int reward(CatalogCard c) => monthlyRewardMinor(
    c,
    spendMinor: monthlySpendMinor,
    totalMonthlySpendMinor: total,
    category: category,
    merchantKey: merchantKey,
  );

  CatalogCard? best;
  var bestValue = 0;
  for (final c in owned) {
    final v = reward(c);
    if (best == null || v > bestValue) {
      best = c;
      bestValue = v;
    }
  }

  final heldIds = {...ownedIds, for (final c in owned) c.id};
  final blocked = {for (final i in unavailableIssuers) normName(i)};
  CardUpsell? top;
  for (final c in catalog) {
    if (heldIds.contains(c.id) || dismissedIds.contains(c.id)) continue;
    if (blocked.contains(normName(c.issuer))) continue;
    if (!isAttainable(c, salaryMinor: salaryMinor, policy: policy)) continue;
    final value = reward(c);
    if (value <= bestValue) continue;
    final rule = selectRule(c.spec, category, merchantKey);
    final gain = CardUpsell(
      card: c,
      ownedBest: best,
      monthlySpendMinor: monthlySpendMinor,
      ownedMonthlyMinor: bestValue,
      candidateMonthlyMinor: value,
      annualFeeMinor: c.annualFeeMinor,
      ruleName: rule?.name,
    );
    if (!isMeaningful(gain, policy)) continue;
    if (top == null || _better(gain, top)) top = gain;
  }
  return top;
}

// Highest net yearly gain; then the lower fee; then the id, so the pick is
// stable across runs.
bool _better(CardUpsell a, CardUpsell b) {
  final y = a.netYearlyMinor.compareTo(b.netYearlyMinor);
  if (y != 0) return y > 0;
  final f = a.annualFeeMinor.compareTo(b.annualFeeMinor);
  if (f != 0) return f < 0;
  return a.card.id.compareTo(b.card.id) < 0;
}
