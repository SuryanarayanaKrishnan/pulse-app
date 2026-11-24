/// Card value engine: pure, on-device, deterministic. Builds on the rewards
/// engine (`rewards.dart`) and the catalog. No network, no database.
///
///  (a) [checkCard]: right/wrong card for one captured payment.
///  (b) [parseBenefits]: perks valued in AED per year.
///  (c) [feeWaiverRing], [welcomeBonusRing]: progress rings.
///  (d) [cardHints]: "use Card X until the cycle ends" when a cap or a
///      threshold is near.
///  (e) [rankByNetValue]: cards ranked by rewards + benefits - fee over a
///      trailing 90 days, annualised.
///
/// Every figure is an estimate built on catalog numbers that may be
/// unverified; callers label it that way.
///
/// Catalog `perks` schema (all keys optional):
///
///     {"benefits": [{"name": "Airport lounge", "value_aed_year": 600},
///                   {"name": "Cinema", "unit_value_aed": 35,
///                    "uses_per_year": 12, "expected_use_pct": 0.5}],
///      "welcome_bonus": {"name": "Welcome offer", "spend_minor": 500000,
///                        "within_days": 90, "bonus_value_aed": 400}}
library;

import 'dart:math' as math;

import 'dates.dart';
import 'rewards.dart';
import 'types.dart';

/// Smaller misses than this (AED 1) are noise: the card counts as right.
const minMissedMinor = 100;

/// Days in the ranking window.
const rankWindowDays = 90;

// ---------------------------------------------------------------------------
// (a) Right / wrong card
// ---------------------------------------------------------------------------

class CardCheck {
  const CardCheck({
    required this.paidCardId,
    required this.paidTitle,
    required this.earnedMinor,
    required this.bestCardId,
    required this.bestTitle,
    required this.bestMinor,
    required this.estimated,
  });

  final String paidCardId, paidTitle, bestCardId, bestTitle;

  /// What the card used earned for this payment / what the best owned card
  /// would have earned, in fils.
  final int earnedMinor, bestMinor;

  /// True when any figure came from unverified catalog terms.
  final bool estimated;

  int get missedMinor => math.max(0, bestMinor - earnedMinor);
  bool get right => missedMinor < minMissedMinor;
}

/// Compares the card used with the best card the user owns for [spend].
/// [before] holds every owned card with its cycle state as it stood before
/// this payment. Null when there is nothing to compare (fewer than two cards,
/// the card is unknown, or no card would earn anything).
CardCheck? checkCard({
  required String paidCardId,
  required List<RankableCard> before,
  required Spend spend,
  Set<String> unverifiedCardIds = const {},
}) {
  if (before.length < 2 || spend.amountMinor <= 0) return null;
  final ranked = rankCards(
    before,
    category: spend.category,
    merchantKey: spend.merchantKey,
    amountMinor: spend.amountMinor,
  );
  final paid = ranked.where((r) => r.card.id == paidCardId).firstOrNull;
  if (paid == null) return null;
  final best = ranked.first;
  if (best.quote.valueMinor <= 0) return null;
  // On a tie keep the card used, so we never call a tie "wrong".
  final pick = best.quote.valueMinor == paid.quote.valueMinor ? paid : best;
  return CardCheck(
    paidCardId: paidCardId,
    paidTitle: paid.card.title,
    earnedMinor: paid.quote.valueMinor,
    bestCardId: pick.card.id,
    bestTitle: pick.card.title,
    bestMinor: pick.quote.valueMinor,
    estimated: unverifiedCardIds.contains(paidCardId) || unverifiedCardIds.contains(pick.card.id),
  );
}

// ---------------------------------------------------------------------------
// (b) Benefits in AED per year
// ---------------------------------------------------------------------------

class Benefit {
  const Benefit(this.name, this.annualValueMinor);
  final String name;
  final int annualValueMinor;
}

/// Values the `benefits` list of a catalog `perks` document. Entries without a
/// usable value are skipped; never throws.
List<Benefit> parseBenefits(Map<String, Object?> perks) {
  final out = <Benefit>[];
  final list = perks['benefits'];
  for (final raw in (list is List ? list : const [])) {
    if (raw is! Map) continue;
    final name = raw['name'];
    if (name is! String || name.isEmpty) continue;
    double? aed = (raw['value_aed_year'] as num?)?.toDouble();
    if (aed == null) {
      final unit = (raw['unit_value_aed'] as num?)?.toDouble();
      final uses = (raw['uses_per_year'] as num?)?.toDouble();
      if (unit != null && uses != null) {
        final pct = ((raw['expected_use_pct'] as num?)?.toDouble() ?? 1).clamp(0, 1);
        aed = unit * uses * pct;
      }
    }
    if (aed == null || aed <= 0) continue;
    out.add(Benefit(name, roundHalfEven(aed * 100)));
  }
  return out;
}

int totalBenefitsMinor(List<Benefit> b) => b.fold(0, (s, x) => s + x.annualValueMinor);

// ---------------------------------------------------------------------------
// (c) Progress rings
// ---------------------------------------------------------------------------

enum RingState { active, complete, expired }

class MilestoneRing {
  const MilestoneRing({
    required this.label,
    required this.currentMinor,
    required this.targetMinor,
    required this.state,
    this.daysLeft,
    this.rewardMinor = 0,
  });

  final String label;
  final int currentMinor, targetMinor;
  final RingState state;

  /// Days until a welcome offer closes; null for the fee waiver.
  final int? daysLeft;

  /// What reaching the target is worth (fee saved or bonus), in fils.
  final int rewardMinor;

  double get fraction => targetMinor <= 0 ? 1 : (currentMinor / targetMinor).clamp(0, 1).toDouble();
  int get remainingMinor => math.max(0, targetMinor - currentMinor);
}

/// Annual-fee waiver progress; null when the card has no fee or no known
/// waiver threshold. [yearSpendMinor] is the spend in the current fee year.
MilestoneRing? feeWaiverRing(CardSpec spec, int annualFeeMinor, int yearSpendMinor) {
  final target = spec.feeWaiverSpendMinor;
  if (target == null || target <= 0 || annualFeeMinor <= 0) return null;
  return MilestoneRing(
    label: 'Fee waiver',
    currentMinor: yearSpendMinor,
    targetMinor: target,
    state: yearSpendMinor >= target ? RingState.complete : RingState.active,
    rewardMinor: annualFeeMinor,
  );
}

class WelcomeBonus {
  const WelcomeBonus({
    required this.name,
    required this.spendMinor,
    required this.withinDays,
    required this.bonusValueMinor,
  });
  final String name;
  final int spendMinor, withinDays, bonusValueMinor;
}

WelcomeBonus? parseWelcomeBonus(Map<String, Object?> perks) {
  final w = perks['welcome_bonus'];
  if (w is! Map) return null;
  final spend = (w['spend_minor'] as num?)?.toInt();
  final days = (w['within_days'] as num?)?.toInt();
  final value = (w['bonus_value_aed'] as num?)?.toDouble();
  if (spend == null || spend <= 0 || days == null || days <= 0 || value == null || value <= 0) return null;
  return WelcomeBonus(
    name: (w['name'] as String?) ?? 'Welcome offer',
    spendMinor: spend,
    withinDays: days,
    bonusValueMinor: roundHalfEven(value * 100),
  );
}

/// Welcome-bonus progress. [spendSinceOpenMinor] counts spend from [openedOn]
/// (the day the card was added) up to [today].
MilestoneRing welcomeBonusRing(
  WelcomeBonus bonus,
  CalDate openedOn,
  CalDate today,
  int spendSinceOpenMinor,
) {
  final left = bonus.withinDays - today.daysSince(openedOn);
  final done = spendSinceOpenMinor >= bonus.spendMinor;
  return MilestoneRing(
    label: bonus.name,
    currentMinor: spendSinceOpenMinor,
    targetMinor: bonus.spendMinor,
    state: done ? RingState.complete : (left < 0 ? RingState.expired : RingState.active),
    daysLeft: math.max(0, left),
    rewardMinor: bonus.bonusValueMinor,
  );
}

// ---------------------------------------------------------------------------
// (d) "Use Card X until the cycle ends"
// ---------------------------------------------------------------------------

class CardHint {
  const CardHint({required this.cardId, required this.message, this.suggestedCardId, required this.kind});

  /// `cap` or `threshold`.
  final String kind;
  final String cardId;
  final String? suggestedCardId;
  final String message;
}

/// Hints for one card: a capped rule near or at its cap (point at the owned
/// card that earns more for it), or a monthly minimum spend that is close to
/// being met (keep using this card until [cycleEnd]).
List<CardHint> cardHints({
  required RankableCard card,
  required List<RankableCard> all,
  required CalDate cycleEnd,
}) {
  final out = <CardHint>[];
  final seen = <String>{};
  for (final rule in card.spec.rules) {
    if (rule.capUnits == null) continue;
    final n = nudgeFor(
      card: card,
      all: all,
      cycleEnd: cycleEnd,
      category: rule.categories.isEmpty ? null : rule.categories.first,
      merchantKey: rule.categories.isEmpty && rule.merchants.isNotEmpty ? rule.merchants.first : null,
    );
    if (n == null || !seen.add(n.message)) continue;
    out.add(CardHint(kind: 'cap', cardId: card.id, suggestedCardId: n.suggestedCardId, message: n.message));
  }
  final min = card.spec.minMonthlySpendMinor;
  if (min > 0 && !card.state.minSpendMet && card.state.spendMinor >= min * nearCapPct / 100) {
    final gap = min - card.state.spendMinor;
    out.add(
      CardHint(
        kind: 'threshold',
        cardId: card.id,
        message:
            'Use ${card.title} until ${cycleEnd.toIso()}: AED ${(gap / 100).toStringAsFixed(0)} more '
            'reaches its monthly minimum, or this cycle earns nothing.',
      ),
    );
  }
  return out;
}

// ---------------------------------------------------------------------------
// (e) Net annual value over a trailing window
// ---------------------------------------------------------------------------

class DatedSpend {
  const DatedSpend(this.date, this.spend);
  final CalDate date;
  final Spend spend;
}

class CardValueInput {
  const CardValueInput({
    required this.id,
    required this.title,
    required this.spec,
    required this.annualFeeMinor,
    required this.spends,
    this.statementDay,
    this.benefits = const [],
    this.unverified = false,
  });
  final String id, title;
  final CardSpec spec;
  final int annualFeeMinor;
  final int? statementDay;
  final List<Benefit> benefits;

  /// Debit spends of the cycle that contains the window start up to today.
  final List<DatedSpend> spends;
  final bool unverified;
}

class CardNetValue {
  const CardNetValue({
    required this.id,
    required this.title,
    required this.windowSpendMinor,
    required this.windowRewardsMinor,
    required this.annualRewardsMinor,
    required this.annualBenefitsMinor,
    required this.annualFeeMinor,
    required this.feeWaived,
    required this.estimated,
  });
  final String id, title;
  final int windowSpendMinor, windowRewardsMinor;

  /// Annualised from the window.
  final int annualRewardsMinor, annualBenefitsMinor;

  /// The fee counted (0 when the annualised spend reaches the waiver).
  final int annualFeeMinor;
  final bool feeWaived, estimated;

  int get netAnnualMinor => annualRewardsMinor + annualBenefitsMinor - annualFeeMinor;
}

/// Ranks cards by net annual value, best first (ties: the input order).
/// Rewards come from the trailing [rankWindowDays] days ending [today],
/// replayed cycle by cycle so caps and minimums bind as they would have.
List<CardNetValue> rankByNetValue(List<CardValueInput> cards, CalDate today) {
  final windowStart = today.addDays(-(rankWindowDays - 1));
  final out = <CardNetValue>[];
  for (final c in cards) {
    final sorted = [...c.spends]..sort((a, b) => a.date.compareTo(b.date));
    final cycles = <String, List<DatedSpend>>{};
    for (final s in sorted) {
      cycles.putIfAbsent(cycleBounds(s.date, c.statementDay).$1.toIso(), () => []).add(s);
    }
    var spend = 0;
    var rewards = 0;
    for (final list in cycles.values) {
      final usage = <String, CapUsage>{};
      var cycleSpend = 0;
      var inWindowUnits = 0.0;
      for (final s in list) {
        cycleSpend += math.max(0, s.spend.amountMinor);
        final (units, _) = earn(c.spec, s.spend, usage);
        if (s.date >= windowStart && s.date <= today) {
          inWindowUnits += units;
          spend += math.max(0, s.spend.amountMinor);
        }
      }
      if (cycleSpend >= c.spec.minMonthlySpendMinor) rewards += c.spec.valueMinor(inWindowUnits);
    }
    final annualRewards = (rewards * 365 / rankWindowDays).round();
    final target = c.spec.feeWaiverSpendMinor;
    final waived = target != null && c.annualFeeMinor > 0 && spend * 365 / rankWindowDays >= target;
    out.add(
      CardNetValue(
        id: c.id,
        title: c.title,
        windowSpendMinor: spend,
        windowRewardsMinor: rewards,
        annualRewardsMinor: annualRewards,
        annualBenefitsMinor: totalBenefitsMinor(c.benefits),
        annualFeeMinor: waived ? 0 : c.annualFeeMinor,
        feeWaived: waived,
        estimated: c.unverified,
      ),
    );
  }
  // List.sort is not stable; break ties by input order explicitly.
  final order = {for (final (i, c) in cards.indexed) c.id: i};
  out.sort((a, b) {
    final v = b.netAnnualMinor.compareTo(a.netAnnualMinor);
    return v != 0 ? v : order[a.id]!.compareTo(order[b.id]!);
  });
  return out;
}
