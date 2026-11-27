/// Savings estimate for the "Reddit stack" chain: Tabby, SIB Cashback and a
/// second credit card (Liv Cashback or Dubai First) used in that order.
///
/// How the chain works (reported by community members, confirmed by surya):
///   1. Pay everything with the Tabby card.
///   2. Pay the Tabby bill with the SIB Cashback card through Apple Pay or
///      Google Pay: a flat 10% back, up to the card's AED 300 monthly cap, less
///      the fee Tabby charges to repay by credit card (reported as about 1%).
///   3. Pay the SIB bill with another credit card, which may earn that card's
///      cashback on top. The estimate does not count step 3: the catalog lists
///      credit card payments (`cc_payment`) as excluded on Liv and Dubai First,
///      so it is shown as possible extra, not as a promise.
///
/// Everything comes from the bundled catalog (`assets/catalog/cards.json`):
/// the rates, caps, tiers and annual fees below are read from it, never typed
/// in. The assumptions are the month of spending, the app's own typical month
/// (`typicalMonthlySpendMinorByCategory` in `card_upsell.dart`), and Tabby's
/// repayment fee, which the catalog does not hold.
/// The result is an estimate against using Liv Cashback alone, not a promise.
library;

import 'card_upsell.dart' show typicalMonthlySpendMinorByCategory;

/// Fee Tabby may charge to repay by credit card (community report, "up to
/// about 1%"). Not in the catalog, so it is the one rate typed here.
const tabbyCardRepaymentFeeRate = 0.01;

class StackEstimate {
  const StackEstimate({
    required this.stackMonthlyAed,
    required this.livAloneMonthlyAed,
    required this.annualFeesAed,
    required this.chainMonthlyAed,
    required this.sibMonthlyAed,
    required this.tabbyFeeMonthlyAed,
    required this.livMonthlyAed,
    required this.monthlySpendAed,
  });
  final double stackMonthlyAed;
  final double livAloneMonthlyAed;
  final double annualFeesAed;

  /// Spend routed through Tabby, repaid by SIB (held to what the AED 300 cap
  /// can pay 10% on).
  final double chainMonthlyAed;
  final double sibMonthlyAed;
  final double tabbyFeeMonthlyAed;
  final double livMonthlyAed;
  final double monthlySpendAed;

  double get grossYearlyAed => (sibMonthlyAed - tabbyFeeMonthlyAed) * 12;

  /// Yearly gain from the Tabby + SIB chain alone (SIB cashback less the Tabby
  /// repayment fee), after the SIB annual fee. Other cards come on top.
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

  // Bills stay on Liv: SIB pays only 0.5% on them and Tabby repays do not suit
  // utilities. Everything else can go through the chain.
  final bills = all.where(billCats.contains).fold<double>(
    0,
    (a, k) => a + spend(k),
  );
  final nonBill = total - bills;

  final sibRule = _rule(sib, 'shopping');
  final sibRate = (sibRule['rate'] as num).toDouble();
  final sibCap = (sibRule['monthly_cap_units'] as num).toDouble();
  // Spend the AED 300 cap can pay 10% on; more than this earns nothing extra.
  final chainMax = sibCap / sibRate;
  final chain = nonBill < chainMax ? nonBill : chainMax;
  final sibEarned = chain * sibRate;
  final sibMonthly = sibEarned < sibCap ? sibEarned : sibCap;
  final tabbyFee = chain * tabbyCardRepaymentFeeRate;

  // What stays on Liv: the bills and whatever the chain could not take.
  final left = total - chain;
  final leftRate = _livRate(liv, left);
  final livLeft = (nonBill - chain) * leftRate + bills * billsRate;
  final livStack = livLeft < livCap ? livLeft : livCap;

  final fees = (sibCard['annual_fee_minor'] as num) / 100;
  return StackEstimate(
    stackMonthlyAed: sibMonthly - tabbyFee + livStack,
    livAloneMonthlyAed: livAlone,
    annualFeesAed: fees.toDouble(),
    chainMonthlyAed: chain,
    sibMonthlyAed: sibMonthly,
    tabbyFeeMonthlyAed: tabbyFee,
    livMonthlyAed: livStack,
    monthlySpendAed: total,
  );
}
