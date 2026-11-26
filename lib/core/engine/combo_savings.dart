/// Savings estimate for the "Reddit stack" combo: Liv Cashback, Dubai First
/// Cashback, SIB Cashback and Tabby together.
///
/// Everything comes from the bundled catalog (`assets/catalog/cards.json`):
/// the rates, caps, tiers and annual fees below are read from it, never typed
/// in. The only assumption is the month of spending, the app's own typical
/// month (`typicalMonthlySpendMinorByCategory` in `card_upsell.dart`).
/// The result is an estimate against using Liv Cashback alone, not a promise.
library;

import 'card_upsell.dart' show typicalMonthlySpendMinorByCategory;

/// Which stack card takes which typical-month category.
///
/// * Dubai First: supermarkets and dining (5% rules, capped per rule).
/// * SIB Cashback: shopping, entertainment and travel, which the catalog
///   lists under its 10% online and wallet rule (shared monthly cap).
/// * Liv Cashback: everything else.
/// * Tabby earns nothing itself (catalog base rate 0), so it adds no figure.
const stackDubaiFirstCategories = ['groceries', 'dining'];
const stackSibCategories = ['shopping', 'entertainment', 'travel'];

class StackEstimate {
  const StackEstimate({
    required this.stackMonthlyAed,
    required this.livAloneMonthlyAed,
    required this.annualFeesAed,
    required this.dubaiFirstMonthlyAed,
    required this.sibMonthlyAed,
    required this.livMonthlyAed,
    required this.monthlySpendAed,
  });
  final double stackMonthlyAed;
  final double livAloneMonthlyAed;
  final double annualFeesAed;
  final double dubaiFirstMonthlyAed;
  final double sibMonthlyAed;
  final double livMonthlyAed;
  final double monthlySpendAed;

  double get grossYearlyAed => (stackMonthlyAed - livAloneMonthlyAed) * 12;

  /// Yearly gain over Liv alone, after the Dubai First and SIB annual fees.
  double get netYearlyAed => grossYearlyAed - annualFeesAed;
}

Map<String, dynamic> _card(Map<String, dynamic> catalog, String id) {
  for (final c in catalog['cards'] as List) {
    if ((c as Map<String, dynamic>)['id'] == id) return c;
  }
  throw StateError('Card $id is not in the catalog');
}

Map<String, dynamic> _reward(Map<String, dynamic> card) =>
    card['reward_structure'] as Map<String, dynamic>;

Map<String, dynamic> _rule(Map<String, dynamic> reward, String category) {
  for (final r in reward['rules'] as List) {
    final m = r as Map<String, dynamic>;
    if ((m['categories'] as List).contains(category)) return m;
  }
  throw StateError('No rule for $category');
}

/// Liv's flat rate for a month of total spend, from `tiered_base` keys such as
/// `monthly_spend_under_5000`, `5000_to_9999`, `10000_plus`.
double _livRate(Map<String, dynamic> reward, double monthlyTotal) {
  final tiers = reward['tiered_base'] as Map<String, dynamic>;
  var best = 0.0, bestFloor = -1.0;
  tiers.forEach((key, rate) {
    final nums = RegExp(r'\d+')
        .allMatches(key)
        .map((m) => double.parse(m[0]!))
        .toList();
    final floor = key.contains('under') ? 0.0 : nums.first;
    if (monthlyTotal >= floor && floor > bestFloor) {
      bestFloor = floor;
      best = (rate as num).toDouble();
    }
  });
  return best;
}

/// Works the estimate out from the parsed `cards.json`.
StackEstimate estimateRedditStack(
  Map<String, dynamic> catalog, {
  Map<String, int> typicalMinor = typicalMonthlySpendMinorByCategory,
}) {
  final liv = _reward(_card(catalog, 'liv-cashback'));
  final dfCard = _card(catalog, 'dubai-first-cashback');
  final df = _reward(dfCard);
  final sibCard = _card(catalog, 'sib-cashback');
  final sib = _reward(sibCard);

  double spend(String cat) => (typicalMinor[cat] ?? 0) / 100;
  final all = typicalMinor.keys.toList();
  final total = all.fold<double>(0, (a, k) => a + spend(k));

  // Liv's bills rate (utilities, telecom, education, rent) is its own rule.
  final livBills = _rule(liv, 'utilities');
  final billsRate = (livBills['rate'] as num).toDouble();
  final billCats = (livBills['categories'] as List).cast<String>();
  final livCap = (liv['monthly_cap_total_units'] as num).toDouble();

  double livMonthly(Iterable<String> cats) {
    final spent = cats.fold<double>(0, (a, k) => a + spend(k));
    final rate = _livRate(liv, spent);
    var m = 0.0;
    for (final k in cats) {
      m += spend(k) * (billCats.contains(k) ? billsRate : rate);
    }
    return m < livCap ? m : livCap;
  }

  final livAlone = livMonthly(all);

  var dfMonthly = 0.0;
  for (final k in stackDubaiFirstCategories) {
    final r = _rule(df, k);
    final cap = (r['monthly_cap_units'] as num).toDouble();
    final earned = spend(k) * (r['rate'] as num).toDouble();
    dfMonthly += earned < cap ? earned : cap;
  }

  final sibRule = _rule(sib, stackSibCategories.first);
  final sibCap = (sibRule['monthly_cap_units'] as num).toDouble();
  final sibEarned =
      stackSibCategories.fold<double>(0, (a, k) => a + spend(k)) *
      (sibRule['rate'] as num).toDouble();
  final sibMonthly = sibEarned < sibCap ? sibEarned : sibCap;

  final rest = [
    for (final k in all)
      if (!stackDubaiFirstCategories.contains(k) &&
          !stackSibCategories.contains(k))
        k,
  ];
  final livStack = livMonthly(rest);

  final fees =
      ((dfCard['annual_fee_minor'] as num) +
          (sibCard['annual_fee_minor'] as num)) /
      100;
  return StackEstimate(
    stackMonthlyAed: dfMonthly + sibMonthly + livStack,
    livAloneMonthlyAed: livAlone,
    annualFeesAed: fees,
    dubaiFirstMonthlyAed: dfMonthly,
    sibMonthlyAed: sibMonthly,
    livMonthlyAed: livStack,
    monthlySpendAed: total,
  );
}
