/// Next-best card for the rest of the month, from a forecast of what the user
/// will actually spend. Pure Dart, deterministic, catalog data only.
///
/// 1. [forecastRemainingSpend] turns the ledger into a per-category forecast
///    of the spend still to come this cycle (after the cap point): a trimmed
///    mean of the last up to six full months, a cautious lower quartile when
///    spend swings a lot, and a clearly labelled fallback (this month's pace,
///    the budget, then typical spend) when there are fewer than two full
///    months.
/// 2. [rankNextBest] works out what the cards the user holds will earn on that
///    forecast (caps already used, minimum spend, card-wide cap) and what each
///    catalog card they do not hold would earn on it. A card whose minimum
///    monthly spend is above the forecast earns nothing and cannot win. The
///    yearly figure counts the annual fee unless the forecast spend reaches
///    its fee-waiver threshold.
///
/// Nothing here is invented: rates, caps, minimum spends, fees and waiver
/// conditions come from the catalog; gaps are reported in [GetCardOption.caveats].
library;

import 'dart:math' as math;

import 'card_upsell.dart';
import 'catalog.dart';
import 'dates.dart';
import 'rewards.dart';

/// Shown wherever a forecast-based pick appears.
const forecastCaveat =
    'An estimate from your past spending, not a guarantee. Card terms, caps and rates can change; confirm with the bank.';

/// Shorter form for tight spaces (notification body, chips).
const forecastCaveatShort =
    'Estimate from past spending, not a guarantee. Confirm with the bank.';

/// One past expense in AED.
class LedgerSpend {
  const LedgerSpend(this.date, this.amountMinor, this.category);
  final CalDate date;
  final int amountMinor;

  /// Reward slug (`groceries`, `transport`, `other`, ...).
  final String category;
}

enum ForecastBasis { history, runRate, budget, typical }

enum ForecastConfidence { low, medium, high }

class SpendForecast {
  const SpendForecast({
    required this.remainingMinor,
    required this.basis,
    required this.cycles,
    required this.volatile,
    required this.confidence,
    required this.note,
  });

  /// Forecast spend still to come this cycle, by category (fils).
  final Map<String, int> remainingMinor;
  final ForecastBasis basis;

  /// Full past months the figure is based on (0 for the fallbacks).
  final int cycles;

  /// Spend swings a lot between months; the figure is the cautious one.
  final bool volatile;
  final ForecastConfidence confidence;

  /// `Based on your last 4 months of spending`.
  final String note;

  int get totalMinor => remainingMinor.values.fold(0, (a, b) => a + b);
  bool get isEmpty => totalMinor <= 0;
}

double _mean(List<double> v) =>
    v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;

double _median(List<double> v) {
  final s = [...v]..sort();
  if (s.isEmpty) return 0;
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}

double _quartile(List<double> v) {
  final s = [...v]..sort();
  if (s.isEmpty) return 0;
  final pos = (s.length - 1) * 0.25;
  final lo = pos.floor(), hi = pos.ceil();
  return s[lo] + (s[hi] - s[lo]) * (pos - lo);
}

/// Mean without the highest and lowest month when there are five or more,
/// the median for three or four, the mean for two.
double _robust(List<double> v) {
  if (v.length >= 5) {
    final s = [...v]..sort();
    return _mean(s.sublist(1, s.length - 1));
  }
  if (v.length >= 3) return _median(v);
  return _mean(v);
}

double _cv(List<double> v) {
  final m = _mean(v);
  if (m <= 0 || v.length < 2) return 0;
  final variance =
      v.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / v.length;
  return math.sqrt(variance) / m;
}

/// Coefficient of variation above which spend counts as volatile.
const volatileCv = 0.5;

CalDate _monthStart(CalDate d) => CalDate(d.year, d.month, 1);

CalDate _addMonths(CalDate d, int n) {
  final i = d.year * 12 + (d.month - 1) + n;
  return CalDate(i ~/ 12, i % 12 + 1, 1);
}

/// Forecast of the spend still to come in the calendar month of [today], for
/// the days after [fromDay] (default: today; pass the day the cap was hit to
/// forecast "after the cap"). [history] is every AED expense, any card.
SpendForecast forecastRemainingSpend({
  required List<LedgerSpend> history,
  required CalDate today,
  int? fromDay,
  Map<String, int> budgetMinor = const {},
  Map<String, int> typicalMinor = typicalMonthlySpendMinorByCategory,
  int maxCycles = 6,
}) {
  final from = fromDay ?? today.day;
  final thisMonth = _monthStart(today);
  final dim = daysInMonth(today.year, today.month);

  // Full past months: after the month of the first recorded spend (that
  // month is likely partial), before this one, newest first.
  CalDate? first;
  for (final s in history) {
    if (s.amountMinor > 0 && (first == null || s.date < first)) first = s.date;
  }
  final months = <CalDate>[];
  if (first != null) {
    final earliest = _addMonths(_monthStart(first), 1);
    for (var k = 1; k <= maxCycles; k++) {
      final m = _addMonths(thisMonth, -k);
      if (m < earliest) break;
      months.add(m);
    }
  }

  if (months.length >= 2) {
    final byCat = <String, List<double>>{};
    final totals = <double>[];
    for (final m in months) {
      final per = <String, double>{};
      for (final s in history) {
        if (s.amountMinor <= 0) continue;
        if (s.date.year != m.year || s.date.month != m.month) continue;
        if (s.date.day <= from) continue;
        per[s.category] = (per[s.category] ?? 0) + s.amountMinor;
      }
      totals.add(per.values.fold(0.0, (a, b) => a + b));
      for (final c in per.keys) {
        byCat.putIfAbsent(c, () => []);
      }
      for (final c in byCat.keys) {
        byCat[c]!.add(per[c] ?? 0);
      }
    }
    // Categories first seen in a later month need zeros for the earlier ones.
    for (final e in byCat.entries) {
      while (e.value.length < months.length) {
        e.value.insert(0, 0);
      }
    }
    final volatile = _cv(totals) > volatileCv;
    final out = <String, int>{};
    for (final e in byCat.entries) {
      final v = volatile ? _quartile(e.value) : _robust(e.value);
      final minor = v.round();
      if (minor > 0) out[e.key] = minor;
    }
    final n = months.length;
    final level = n >= 4 ? 2 : 1;
    final conf =
        ForecastConfidence.values[math.max(0, level - (volatile ? 1 : 0))];
    return SpendForecast(
      remainingMinor: out,
      basis: ForecastBasis.history,
      cycles: n,
      volatile: volatile,
      confidence: conf,
      note:
          'Based on your last $n months of spending'
          '${volatile ? ', which varies a lot, so this is a cautious figure' : ''}',
    );
  }

  // Fewer than two full months: this month's pace, then the budget, then a
  // typical month.
  final left = dim - today.day;
  final soFar = <String, double>{};
  var count = 0;
  for (final s in history) {
    if (s.amountMinor <= 0) continue;
    if (s.date.year != today.year ||
        s.date.month != today.month ||
        s.date > today)
      continue;
    soFar[s.category] = (soFar[s.category] ?? 0) + s.amountMinor;
    count++;
  }
  if (count >= 3 && today.day >= 5) {
    final out = <String, int>{
      for (final e in soFar.entries)
        if ((e.value / today.day * left).round() > 0)
          e.key: (e.value / today.day * left).round(),
    };
    return SpendForecast(
      remainingMinor: out,
      basis: ForecastBasis.runRate,
      cycles: 0,
      volatile: false,
      confidence: ForecastConfidence.low,
      note: "Based on this month's pace so far; not enough history yet (needs 2 full months)",
    );
  }
  final left01 = left / dim;
  if (budgetMinor.values.any((v) => v > 0)) {
    return SpendForecast(
      remainingMinor: {
        for (final e in budgetMinor.entries)
          if (e.value > 0 && (e.value * left01).round() > 0)
            e.key: (e.value * left01).round(),
      },
      basis: ForecastBasis.budget,
      cycles: 0,
      volatile: false,
      confidence: ForecastConfidence.low,
      note: 'Based on your budget; not enough spending history yet',
    );
  }
  return SpendForecast(
    remainingMinor: {
      for (final e in typicalMinor.entries)
        if ((e.value * left01).round() > 0) e.key: (e.value * left01).round(),
    },
    basis: ForecastBasis.typical,
    cycles: 0,
    volatile: false,
    confidence: ForecastConfidence.low,
    note: 'Based on typical UAE spending; not enough history yet',
  );
}

// ---------------------------------------------------------------------------
// Ranking
// ---------------------------------------------------------------------------

class NextBestPolicy {
  const NextBestPolicy({
    this.minNetYearlyMinor = 10000,
    this.maxGetCards = 3,
    this.upsell = const UpsellPolicy(),
  });

  /// A card to get must net at least AED 100 a year after its fee.
  final int minNetYearlyMinor;
  final int maxGetCards;
  final UpsellPolicy upsell;
}

enum Eligibility {
  /// Salary known and at or over the card's minimum (or no minimum stated).
  confirmed,

  /// Salary not known; the card's minimum is within a normal range.
  unconfirmed,
}

class GetCardOption {
  const GetCardOption({
    required this.card,
    required this.monthlyValueMinor,
    required this.heldValueMinor,
    required this.feeMinor,
    required this.feeWaivedByForecast,
    required this.netYearlyMinor,
    required this.routedCategories,
    required this.routedSpendMinor,
    required this.minMonthlySpendMinor,
    required this.eligibility,
    required this.caveats,
    this.feeWaiverText,
    this.welcomeText,
    this.welcomeValueAed,
    this.salaryNote,
  });

  final CatalogCard card;

  /// What the card earns in a month on the spend routed to it (fils).
  final int monthlyValueMinor;

  /// What the best held cards earn on that same spend (fils).
  final int heldValueMinor;
  final int feeMinor;
  final bool feeWaivedByForecast;

  /// (earned - held) x 12, less the annual fee unless the forecast spend
  /// reaches its waiver threshold.
  final int netYearlyMinor;
  final List<String> routedCategories;
  final int routedSpendMinor;
  final int minMonthlySpendMinor;
  final Eligibility eligibility;
  final String? feeWaiverText;
  final String? welcomeText;
  final double? welcomeValueAed;
  final String? salaryNote;

  /// Data gaps and assumptions, in plain words.
  final List<String> caveats;

  int get gainMonthlyMinor => monthlyValueMinor - heldValueMinor;
}

class HeldPick {
  const HeldPick(this.card, this.valueMinor);
  final RankableCard card;
  final int valueMinor;
}

class NextBestPlan {
  const NextBestPlan({
    required this.forecast,
    required this.held,
    required this.heldValueMinor,
    required this.heldByCategory,
    required this.getCards,
    required this.reason,
    this.skippedForMinSpend,
  });

  final SpendForecast forecast;

  /// Best held card for the forecast spend, per category (card id), after caps
  /// already used.
  final Map<String, HeldPick> heldByCategory;
  final HeldPick? held;
  final int heldValueMinor;

  /// Cards to get, best first (at most [NextBestPolicy.maxGetCards]).
  final List<GetCardOption> getCards;

  /// A card that looks better on rate but needs more monthly spend than the
  /// forecast.
  final CatalogCard? skippedForMinSpend;

  /// One plain line: what the user usually spends and why this card.
  final String reason;

  GetCardOption? get top => getCards.isEmpty ? null : getCards.first;
}

CycleResult _clone(CycleResult s) {
  final r = CycleResult()
    ..spendMinor = s.spendMinor
    ..earnedUnits = s.earnedUnits
    ..minSpendMet = s.minSpendMet;
  s.usage.forEach(
    (k, u) =>
        r.usage[k] = CapUsage(u.rule, u.capUnits)..usedUnits = u.usedUnits,
  );
  return r;
}

String _aed0(int minor) {
  final v = (minor / 100).round();
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return 'AED $b';
}

/// What the held cards earn on [spend] (category -> fils): each chunk goes to
/// the card that earns most from it given the caps already used. A card whose
/// minimum monthly spend ends up unmet earns nothing.
({Map<String, HeldPick> byCategory, int total, HeldPick? top}) _simulateHeld(
  List<RankableCard> held,
  Map<String, int> spend,
) {
  if (held.isEmpty) return (byCategory: const {}, total: 0, top: null);
  final states = {for (final c in held) c.id: _clone(c.state)};
  final earnedUnitsByCard = {for (final c in held) c.id: 0.0};
  final routed = {for (final c in held) c.id: 0};
  final valueByCat = <String, int>{};
  final cardByCat = <String, RankableCard>{};
  final cats = spend.keys.toList()
    ..sort((a, b) => spend[b]!.compareTo(spend[a]!));
  for (final cat in cats) {
    final amt = spend[cat]!;
    RankableCard? best;
    var bestV = -1;
    for (final c in held) {
      final v = quote(c.spec, states[c.id]!, Spend(amt, cat)).valueMinor;
      if (v > bestV ||
          (v == bestV && best != null && c.createdOrder < best.createdOrder)) {
        best = c;
        bestV = v;
      }
    }
    final b = best!;
    final (units, _) = earn(b.spec, Spend(amt, cat), states[b.id]!.usage);
    earnedUnitsByCard[b.id] = earnedUnitsByCard[b.id]! + units;
    routed[b.id] = routed[b.id]! + amt;
    states[b.id]!.spendMinor += amt;
    valueByCat[cat] = b.spec.valueMinor(units);
    cardByCat[cat] = b;
  }
  // Minimum monthly spend: earnings only count when the card's month total
  // (what it already carried plus the forecast routed to it) reaches it.
  final dead = <String>{
    for (final c in held)
      if (c.spec.minMonthlySpendMinor > 0 &&
          c.state.spendMinor + routed[c.id]! < c.spec.minMonthlySpendMinor)
        c.id,
  };
  var total = 0;
  final by = <String, HeldPick>{};
  for (final cat in cats) {
    final c = cardByCat[cat]!;
    final v = dead.contains(c.id) ? 0 : valueByCat[cat]!;
    by[cat] = HeldPick(c, v);
    total += v;
  }
  HeldPick? top;
  for (final p in by.values) {
    if (top == null || p.valueMinor > top.valueMinor) top = p;
  }
  return (byCategory: by, total: total, top: top);
}

Map<String, Object?> _asMap(Object? o) =>
    o is Map ? Map<String, Object?>.from(o) : const {};

/// The plan: forecast spend, what held cards earn on it, and the cards to get.
///
/// [held] are the user's cards with their cycle so far. [afterCap] says the
/// forecast is "after the cap" (affects wording only).
NextBestPlan rankNextBest({
  required SpendForecast forecast,
  required List<RankableCard> held,
  required List<CatalogCard> catalog,
  Set<String> heldCatalogIds = const {},
  Set<String> dismissedIds = const {},
  Set<String> unavailableIssuers = const {},
  int? salaryMinor,
  bool afterCap = true,
  NextBestPolicy policy = const NextBestPolicy(),
}) {
  final spend = forecast.remainingMinor;
  final sim = _simulateHeld(held, spend);
  final blocked = {for (final i in unavailableIssuers) i.toLowerCase().trim()};
  final options = <GetCardOption>[];
  CatalogCard? skipped;
  var skippedGain = 0;

  for (final card in catalog) {
    if (heldCatalogIds.contains(card.id) || dismissedIds.contains(card.id))
      continue;
    if (blocked.contains(card.issuer.toLowerCase().trim())) continue;
    if (!isAttainable(card, salaryMinor: salaryMinor, policy: policy.upsell))
      continue;
    final CardSpec spec;
    try {
      spec = card.spec;
    } on Object {
      continue;
    }
    final minSpend = spec.minMonthlySpendMinor;

    // Variant A: only the categories where this card beats what is held.
    // Variant B: all the forecast spend on it (helps a minimum-spend card).
    ({int value, int held, List<String> cats, int spent, int rawValue})?
    evaluate(Iterable<String> cats) {
      final list = cats.toList();
      if (list.isEmpty) return null;
      final chunks = [for (final c in list) Spend(spend[c]!, c)];
      final spent = chunks.fold(0, (a, s) => a + s.amountMinor);
      final res = computeCycle(spec, chunks);
      final raw = spec.valueMinor(res.earnedUnits);
      final value = spent >= minSpend ? raw : 0;
      final heldV = list.fold(
        0,
        (a, c) => a + (sim.byCategory[c]?.valueMinor ?? 0),
      );
      return (
        value: value,
        held: heldV,
        cats: list,
        spent: spent,
        rawValue: raw,
      );
    }

    final winners = [
      for (final c in spend.keys)
        if (spec.valueMinor(
              computeCycle(spec, [Spend(spend[c]!, c)]).earnedUnits,
            ) >
            (sim.byCategory[c]?.valueMinor ?? 0))
          c,
    ];
    final a = evaluate(winners);
    final b = evaluate(spend.keys);
    final cands = [?a, ?b];
    if (cands.isEmpty) continue;
    cands.sort((x, y) => (y.value - y.held).compareTo(x.value - x.held));
    final bestEval = cands.first;
    final rawBest = [...cands]
      ..sort((x, y) => (y.rawValue - y.held).compareTo(x.rawValue - x.held));
    final rawGain = rawBest.first.rawValue - rawBest.first.held;

    if (bestEval.value - bestEval.held <= 0) {
      // Looks good on rate but the minimum monthly spend is out of reach.
      if (minSpend > 0 &&
          rawGain > skippedGain &&
          rawBest.first.spent < minSpend) {
        skipped = card;
        skippedGain = rawGain;
      }
      continue;
    }

    final perks = _asMap(card.perks);
    final waiver = _asMap(perks['fee_waiver']);
    final waiverSpend =
        (waiver['spend_minor'] as num?)?.toInt() ?? spec.feeWaiverSpendMinor;
    final yearly = waiver['period'] == null || waiver['period'] == 'year';
    final waivedByForecast =
        card.annualFeeMinor > 0 &&
        waiverSpend != null &&
        yearly &&
        bestEval.spent * 12 >= waiverSpend;
    final fee = card.annualFeeMinor;
    final gain = bestEval.value - bestEval.held;
    final net = gain * 12 - (waivedByForecast ? 0 : fee);
    if (net < policy.minNetYearlyMinor) continue;

    final welcome = _asMap(perks['welcome_offer']);
    final until = DateTime.tryParse('${welcome['valid_until'] ?? ''}');
    final welcomeLive =
        welcome['text'] != null &&
        (until == null || !until.isBefore(DateTime.now()));
    final caveats = <String>[];
    if (!card.verified)
      caveats.add('Figures not yet verified against the issuer');
    if (card.minSalaryMinor == null)
      caveats.add('Minimum salary is not in our data');
    if (perks['confidence'] == 'low')
      caveats.add('Low-confidence data for this card');
    if (card.annualFeeMinor > 0 && waiverSpend == null)
      caveats.add('Fee waiver terms are not in our data');
    options.add(
      GetCardOption(
        card: card,
        monthlyValueMinor: bestEval.value,
        heldValueMinor: bestEval.held,
        feeMinor: fee,
        feeWaivedByForecast: waivedByForecast,
        netYearlyMinor: net,
        routedCategories: bestEval.cats,
        routedSpendMinor: bestEval.spent,
        minMonthlySpendMinor: minSpend,
        eligibility: salaryMinor != null
            ? Eligibility.confirmed
            : Eligibility.unconfirmed,
        feeWaiverText: waiver['text'] as String?,
        welcomeText: welcomeLive ? welcome['text'] as String? : null,
        welcomeValueAed: welcomeLive
            ? (welcome['value_aed_est'] as num?)?.toDouble()
            : null,
        salaryNote: card.minSalaryMinor == null
            ? null
            : 'Needs a salary of ${_aed0(card.minSalaryMinor!)} a month',
        caveats: caveats,
      ),
    );
  }

  options.sort((x, y) {
    final n = y.netYearlyMinor.compareTo(x.netYearlyMinor);
    if (n != 0) return n;
    final f = x.feeMinor.compareTo(y.feeMinor);
    return f != 0 ? f : x.card.id.compareTo(y.card.id);
  });
  final picks = options.take(policy.maxGetCards).toList();

  // The skipped card only matters when it would have beaten the pick.
  final skippedShown =
      skipped != null &&
          (picks.isEmpty || skippedGain > picks.first.gainMonthlyMinor)
      ? skipped
      : null;

  final lead = switch (forecast.basis) {
    ForecastBasis.history =>
      'You usually spend about ${_aed0(forecast.totalMinor)} a month ${afterCap ? 'after the cap' : 'in the rest of the month'}',
    _ =>
      'You may spend about ${_aed0(forecast.totalMinor)} ${afterCap ? 'after the cap' : 'in the rest of the month'}',
  };
  String reason;
  if (forecast.isEmpty) {
    reason = 'Not enough spending to forecast yet';
  } else if (picks.isNotEmpty) {
    final t = picks.first;
    final name = '${t.card.issuer} ${t.card.name}';
    if (skippedShown != null) {
      final sm = skippedShown.spec.minMonthlySpendMinor;
      reason =
          '$lead. ${skippedShown.issuer} ${skippedShown.name} needs ${_aed0(sm)} a month to earn anything, so $name is the better fit.';
    } else {
      reason =
          '$lead; $name would earn about ${_aed0(t.monthlyValueMinor)} a month on it.';
    }
  } else if (skippedShown != null) {
    reason =
        '$lead. ${skippedShown.issuer} ${skippedShown.name} needs ${_aed0(skippedShown.spec.minMonthlySpendMinor)} a month to earn anything, so it would not pay off.';
  } else {
    reason =
        '$lead; no card in the catalog beats what you hold for that spend.';
  }

  return NextBestPlan(
    forecast: forecast,
    held: sim.top,
    heldValueMinor: sim.total,
    heldByCategory: sim.byCategory,
    getCards: picks,
    reason: reason,
    skippedForMinSpend: skippedShown,
  );
}
