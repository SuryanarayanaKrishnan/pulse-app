/// Rewards engine: pure, deterministic card-reward maths (no network, no
/// database). Port of `app/services/rewards.py` and the ranking / nudge logic
/// of `rewards_service.py` (pulse-api).
///
/// A card's `reward_structure` (JSON in the catalog):
///
///     {"unit": "cashback" | "points", "point_value_aed": 0.025,
///      "base_rate": 0.01,
///      "rules": [{"name": "Dining", "categories": ["dining"],
///                 "merchants": ["talabat"], "rate": 0.05,
///                 "monthly_cap_units": 100}],
///      "excluded_categories": ["fees", "cc_payment", "transfer"],
///      "min_monthly_spend_minor": 200000,
///      "fee_waiver_spend_minor": 2000000}
///
/// Rule choice: a merchant match beats a category match beats the base rate;
/// an excluded category earns nothing. Caps are per rule per statement cycle
/// (AED for cashback, points otherwise).
library;

import 'dart:math' as math;

import 'dates.dart';
import 'types.dart';

class RuleSpec {
  const RuleSpec({
    required this.name,
    required this.rate,
    this.categories = const {},
    this.merchants = const [],
    this.capUnits,
  });
  final String name;
  final double rate;
  final Set<String> categories;
  final List<String> merchants;
  final double? capUnits;
}

class CardSpec {
  const CardSpec({
    required this.unit,
    required this.pointValueAed,
    required this.baseRate,
    this.rules = const [],
    this.excludedCategories = const {},
    this.minMonthlySpendMinor = 0,
    this.feeWaiverSpendMinor,
  });
  final String unit;
  final double pointValueAed;
  final double baseRate;
  final List<RuleSpec> rules;
  final Set<String> excludedCategories;
  final int minMonthlySpendMinor;
  final int? feeWaiverSpendMinor;

  bool get isCashback => unit == 'cashback';

  /// Value in fils of [units] (AED for cashback, points otherwise).
  int valueMinor(double units) =>
      roundHalfEven(_clean(units * pointValueAed * 100));
}

double _clean(double x) => (x * 1e9).round() / 1e9;

/// Validates and loads a reward structure; throws [FormatException] on garbage.
CardSpec parseStructure(Map<String, Object?> data) {
  final unit = (data['unit'] as String?) ?? 'cashback';
  if (unit != 'cashback' && unit != 'points') {
    throw const FormatException('unit must be cashback or points');
  }
  final value = ((data['point_value_aed'] as num?) ?? 1).toDouble();
  final base = ((data['base_rate'] as num?) ?? 0).toDouble();
  if (value <= 0 || base < 0) {
    throw const FormatException(
      'point_value_aed must be positive and base_rate non-negative',
    );
  }
  final rules = <RuleSpec>[];
  for (final r in (data['rules'] as List? ?? const [])) {
    final m = Map<String, Object?>.from(r as Map);
    final rate = (m['rate'] as num?)?.toDouble();
    final cats = (m['categories'] as List? ?? const []).cast<String>();
    final merchants = (m['merchants'] as List? ?? const []).cast<String>();
    if (rate == null || rate < 0 || (cats.isEmpty && merchants.isEmpty)) {
      throw FormatException(
        'rule ${m['name']} needs a rate and categories or merchants',
      );
    }
    rules.add(
      RuleSpec(
        name: '${m['name']}',
        rate: rate,
        categories: cats.toSet(),
        merchants: [for (final x in merchants) x.toLowerCase()],
        capUnits: (m['monthly_cap_units'] as num?)?.toDouble(),
      ),
    );
  }
  return CardSpec(
    unit: unit,
    pointValueAed: value,
    baseRate: base,
    rules: rules,
    excludedCategories: ((data['excluded_categories'] as List?) ?? const [])
        .cast<String>()
        .toSet(),
    minMonthlySpendMinor:
        (data['min_monthly_spend_minor'] as num?)?.toInt() ?? 0,
    feeWaiverSpendMinor: (data['fee_waiver_spend_minor'] as num?)?.toInt(),
  );
}

const baseRuleName = 'Base';

/// The rule that earns for this spend; null when the category is excluded.
RuleSpec? selectRule(CardSpec spec, String? category, String? merchantKey) {
  if (category != null && spec.excludedCategories.contains(category))
    return null;
  if (merchantKey != null && merchantKey.isNotEmpty) {
    for (final r in spec.rules) {
      if (r.merchants.any(merchantKey.contains)) return r;
    }
  }
  if (category != null) {
    for (final r in spec.rules) {
      if (r.categories.contains(category)) return r;
    }
  }
  return RuleSpec(name: baseRuleName, rate: spec.baseRate);
}

class Spend {
  const Spend(this.amountMinor, [this.category, this.merchantKey]);
  final int amountMinor;
  final String? category;
  final String? merchantKey;
}

class CapUsage {
  CapUsage(this.rule, this.capUnits);
  final String rule;
  final double? capUnits;
  double usedUnits = 0;

  double? get remainingUnits =>
      capUnits == null ? null : math.max(0, capUnits! - usedUnits);
  double? get pctUsed => (capUnits == null || capUnits == 0)
      ? null
      : math.min(100, usedUnits / capUnits! * 100);
}

class CycleResult {
  int spendMinor = 0;
  double earnedUnits = 0;
  final Map<String, CapUsage> usage = {};
  bool minSpendMet = true;

  int earnedValueMinor(CardSpec spec) =>
      minSpendMet ? spec.valueMinor(earnedUnits) : 0;
}

/// Units earned by one spend given what the cycle already used (mutates
/// [usage]).
(double, RuleSpec?) earn(
  CardSpec spec,
  Spend spend,
  Map<String, CapUsage> usage,
) {
  final rule = selectRule(spec, spend.category, spend.merchantKey);
  if (rule == null || spend.amountMinor <= 0) return (0, rule);
  var units = spend.amountMinor / 100 * rule.rate;
  final state = usage.putIfAbsent(
    rule.name,
    () => CapUsage(rule.name, rule.capUnits),
  );
  if (state.capUnits != null) {
    units = math.min(units, math.max(0, state.capUnits! - state.usedUnits));
  }
  state.usedUnits += units;
  return (units, rule);
}

/// Applies a cycle's spends in order (caps bind chronologically).
CycleResult computeCycle(CardSpec spec, List<Spend> spends) {
  final res = CycleResult();
  for (final sp in spends) {
    res.spendMinor += math.max(0, sp.amountMinor);
    final (units, _) = earn(spec, sp, res.usage);
    res.earnedUnits += units;
  }
  res.minSpendMet = res.spendMinor >= spec.minMonthlySpendMinor;
  return res;
}

class Quote {
  const Quote(
    this.units,
    this.valueMinor,
    this.rule,
    this.headroomUnits,
    this.capped,
  );
  final double units;
  final int valueMinor;
  final String? rule;

  /// Cap left on the rule before this spend (null = uncapped).
  final double? headroomUnits;

  /// This spend would hit (part of) the cap.
  final bool capped;
}

/// What a spend would earn on top of the cycle so far (state is not modified).
Quote quote(CardSpec spec, CycleResult state, Spend spend) {
  final rule = selectRule(spec, spend.category, spend.merchantKey);
  if (rule == null || spend.amountMinor <= 0)
    return const Quote(0, 0, null, null, false);
  final used = state.usage[rule.name];
  double? headroom;
  if (rule.capUnits != null) {
    headroom = math.max(0, rule.capUnits! - (used?.usedUnits ?? 0));
  }
  final full = spend.amountMinor / 100 * rule.rate;
  final units = headroom == null ? full : math.min(full, headroom);
  return Quote(
    units,
    spec.valueMinor(units),
    rule.name,
    headroom,
    units < full,
  );
}

// ---------------------------------------------------------------------------
// Cycle dates
// ---------------------------------------------------------------------------

int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

CalDate _clamp(int year, int month, int day) =>
    CalDate(year, month, math.min(day, daysInMonth(year, month)));

/// (first day, last day) of the reward cycle containing [today]. With a
/// statement day the cycle runs from the day after one statement date to the
/// next one; without it, the calendar month.
(CalDate, CalDate) cycleBounds(CalDate today, int? statementDay) {
  if (statementDay == null) {
    return (
      CalDate(today.year, today.month, 1),
      _clamp(today.year, today.month, 31),
    );
  }
  final thisMonth = _clamp(today.year, today.month, statementDay);
  final last = thisMonth < today
      ? thisMonth
      : _clamp(
          today.year - (today.month == 1 ? 1 : 0),
          (today.month - 2) % 12 + 1,
          statementDay,
        );
  final nxtMonth = last.month % 12 + 1;
  final nxt = _clamp(
    last.year + (last.month == 12 ? 1 : 0),
    nxtMonth,
    statementDay,
  );
  return (last.addDays(1), nxt);
}

// ---------------------------------------------------------------------------
// Ranking and nudges
// ---------------------------------------------------------------------------

/// One owned card with its cycle state, ready to be ranked.
class RankableCard {
  RankableCard({
    required this.id,
    required this.title,
    required this.spec,
    required this.state,
    this.createdOrder = 0,
  });
  final String id;
  final String title;
  final CardSpec spec;
  final CycleResult state;
  final int createdOrder;
}

class RankedCard {
  const RankedCard(this.card, this.quote);
  final RankableCard card;
  final Quote quote;
}

/// Cards ranked best first for a purchase (ties: the older card first).
List<RankedCard> rankCards(
  List<RankableCard> cards, {
  String? category,
  String? merchantKey,
  required int amountMinor,
  String? excludeId,
}) {
  final out = [
    for (final c in cards)
      if (c.id != excludeId)
        RankedCard(
          c,
          quote(c.spec, c.state, Spend(amountMinor, category, merchantKey)),
        ),
  ];
  out.sort((a, b) {
    final v = b.quote.valueMinor.compareTo(a.quote.valueMinor);
    return v != 0 ? v : a.card.createdOrder.compareTo(b.card.createdOrder);
  });
  return out;
}

const nearCapPct = 80.0;

class RewardNudge {
  const RewardNudge({
    required this.level,
    required this.message,
    required this.cardId,
    this.suggestedCardId,
    this.extraValueMinor = 0,
    this.capUnit = 'AED',
  });

  /// `near_cap` or `capped`.
  final String level;
  final String message;
  final String cardId;
  final String? suggestedCardId;
  final int extraValueMinor;
  final String capUnit;
}

/// After a capture: when the card's cap for this spend is reached (or nearly)
/// point at the user's other card that earns more for it. Null when nothing
/// useful can be said. [state] must already include the captured spend.
RewardNudge? nudgeFor({
  required RankableCard card,
  required List<RankableCard> all,
  required CalDate cycleEnd,
  String? category,
  String? merchantKey,
}) {
  final rule = selectRule(card.spec, category, merchantKey);
  if (rule == null || rule.capUnits == null) return null;
  final pct = card.state.usage[rule.name]?.pctUsed;
  if (pct == null || pct < nearCapPct) return null;
  final level = pct >= 100 ? 'capped' : 'near_cap';
  final unit = card.spec.isCashback ? 'AED' : 'points';
  final base =
      '${card.title}: ${rule.name} ${level == 'capped' ? 'cap reached' : '${pct.toStringAsFixed(0)}% of the cap used'}';
  final alts = rankCards(
    all,
    category: category,
    merchantKey: merchantKey,
    amountMinor: 10000,
    excludeId: card.id,
  );
  final mine = quote(
    card.spec,
    card.state,
    Spend(10000, category, merchantKey),
  ).valueMinor;
  final best = alts.isNotEmpty && alts.first.quote.valueMinor > mine
      ? alts.first
      : null;
  if (best == null) {
    return RewardNudge(
      level: level,
      message:
          '$base (until ${cycleEnd.toIso()}); no other card of yours earns more for this.',
      cardId: card.id,
      capUnit: unit,
    );
  }
  return RewardNudge(
    level: level,
    message:
        '$base. Use ${best.card.title} for ${rule.name.toLowerCase()} until ${cycleEnd.toIso()}: '
        'it earns about AED ${(best.quote.valueMinor / 100).toStringAsFixed(2)} per AED 100 vs AED ${(mine / 100).toStringAsFixed(2)}.',
    cardId: card.id,
    suggestedCardId: best.card.id,
    extraValueMinor: best.quote.valueMinor - mine,
    capUnit: unit,
  );
}

/// Annual-fee waiver progress.
class FeeWaiver {
  const FeeWaiver(
    this.annualFeeMinor,
    this.thresholdMinor,
    this.spendThisYearMinor,
  );
  final int annualFeeMinor, thresholdMinor, spendThisYearMinor;
  double get progressPct =>
      math.min(100, spendThisYearMinor / thresholdMinor * 100);
  bool get waived => spendThisYearMinor >= thresholdMinor;
}
