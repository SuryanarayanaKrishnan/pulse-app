/// Cap tracking: how much of each card's monthly reward cap is used, and how
/// much spend that is, from the real ledger. Pure Dart, deterministic.
///
/// Per card, one [CapMeter] for every capped rule (a rule cap is shared by all
/// the categories of that rule, e.g. SIB's AED 300 over online spend) and one
/// for the card-wide cap when the catalog has one. [stackCapStatus] adds the
/// legs of a combo (Tabby + SIB) into one quota.
///
/// Cap-equivalent spend is `cap / rate`: a AED 300 cap at 10% is reached at
/// AED 3,000 of spend. For a card-wide cap it is worked out at the card's
/// top earning rate and marked approximate.
library;

import 'dart:math' as math;

import 'dates.dart';
import 'rewards.dart';

enum CapLevel { ok, near, hit }

/// Which month a card's caps run on.
enum CycleBasis {
  /// The issuer's terms say calendar month.
  calendar,

  /// The user's statement day (the issuer's terms say statement cycle, or
  /// the terms are not recorded and the user set a day).
  statement,

  /// Terms not recorded and no statement day set: calendar month assumed.
  calendarAssumed,
}

class CapMeter {
  const CapMeter({
    required this.id,
    required this.label,
    required this.isTotal,
    required this.capAed,
    required this.earnedAed,
    required this.rate,
    required this.spentAed,
    required this.categories,
    required this.approxSpend,
    required this.isCashback,
  });

  /// Rule name, or [totalCapKey] for the card-wide cap.
  final String id;
  final String label;
  final bool isTotal;

  /// Cap and earned, in AED value (points converted at the catalog value).
  final double capAed;
  final double earnedAed;

  /// Reward per AED spent (fraction of value), null when the rule pays 0.
  final double? rate;

  /// Spend that counted towards this cap this cycle (AED).
  final double spentAed;
  final Set<String> categories;

  /// Cap-equivalent spend is an estimate (card-wide cap).
  final bool approxSpend;
  final bool isCashback;

  double get remainingAed => math.max(0, capAed - earnedAed);
  double get pct => capAed <= 0 ? 0 : math.min(100, earnedAed / capAed * 100);
  CapLevel get level => remainingAed <= 0.005
      ? CapLevel.hit
      : pct >= nearCapPct
      ? CapLevel.near
      : CapLevel.ok;

  /// Spend at which the cap is reached (AED); null when the rule pays nothing.
  double? get capSpendAed =>
      (rate == null || rate! <= 0) ? null : capAed / rate!;

  /// Spend left before the cap is reached (AED).
  double? get remainingSpendAed =>
      (rate == null || rate! <= 0) ? null : remainingAed / rate!;
}

class CardCapStatus {
  const CardCapStatus({
    required this.cardId,
    required this.title,
    required this.cycleStart,
    required this.cycleEnd,
    required this.basis,
    required this.spendAed,
    required this.earnedAed,
    required this.meters,
    this.catalogId,
    this.hasEarningRules = true,
    this.sharedWith = const [],
    this.withPartner = false,
  });

  final String cardId;
  final String? catalogId;
  final String title;
  final CalDate cycleStart;
  final CalDate cycleEnd;
  final CycleBasis basis;
  final double spendAed;
  final double earnedAed;
  final List<CapMeter> meters;

  /// False for a card that earns nothing itself (Tabby).
  final bool hasEarningRules;

  /// Partnership mode: sorted account ids (this card included) whose spend
  /// is pooled under one cap. Empty when the card's cap is its own.
  final List<String> sharedWith;

  /// A household partner's supplementary card pools into this cap too.
  final bool withPartner;

  bool get isShared => sharedWith.length > 1 || withPartner;

  /// One card of a shared group speaks for it in alerts and stacks, so the
  /// same cap never alerts twice.
  bool get isShareLead => sharedWith.length < 2 || sharedWith.first == cardId;

  bool get hasCaps => meters.isNotEmpty;

  /// The meter closest to its cap (the card-wide one wins ties).
  CapMeter? get worst {
    if (meters.isEmpty) return null;
    final sorted = [...meters]
      ..sort((a, b) {
        final p = b.pct.compareTo(a.pct);
        return p != 0 ? p : (b.isTotal ? 1 : 0).compareTo(a.isTotal ? 1 : 0);
      });
    return sorted.first;
  }

  CapLevel get level => worst?.level ?? CapLevel.ok;

  /// The card cannot earn more this cycle: its card-wide cap is hit, or every
  /// capped rule is hit and the card has no uncapped earning rule.
  bool get isExhausted =>
      meters.any((m) => m.isTotal && m.level == CapLevel.hit);
}

/// The cycle that contains [today] for [spec]: the issuer's stated basis, else
/// the user's statement day, else the calendar month (marked as assumed).
(CalDate, CalDate, CycleBasis) resolveCycle(
  CardSpec spec,
  CalDate today,
  int? statementDay,
) {
  if (spec.capCycle == 'calendar') {
    final (a, b) = cycleBounds(today, null);
    return (a, b, CycleBasis.calendar);
  }
  if (statementDay != null) {
    final (a, b) = cycleBounds(today, statementDay);
    return (a, b, CycleBasis.statement);
  }
  final (a, b) = cycleBounds(today, null);
  return (a, b, CycleBasis.calendarAssumed);
}

/// Cap status of one card from the spends of its current cycle, oldest first.
CardCapStatus cardCapStatus({
  required String cardId,
  required String title,
  required CardSpec spec,
  required List<Spend> spends,
  required CalDate cycleStart,
  required CalDate cycleEnd,
  required CycleBasis basis,
  String? catalogId,
  List<String> sharedWith = const [],
  bool withPartner = false,
}) {
  final res = computeCycle(spec, spends);
  final value = spec.pointValueAed;
  final spentByRule = <String, double>{};
  for (final s in spends) {
    if (s.amountMinor <= 0) continue;
    final rule = selectRule(spec, s.category, s.merchantKey);
    if (rule == null) continue;
    spentByRule[rule.name] =
        (spentByRule[rule.name] ?? 0) + s.amountMinor / 100;
  }
  final meters = <CapMeter>[];
  var topRate = 0.0;
  for (final r in spec.rules) {
    if (r.rate * value > topRate) topRate = r.rate * value;
  }
  if (spec.baseRate * value > topRate) topRate = spec.baseRate * value;
  for (final r in spec.rules) {
    if (r.capUnits == null) continue;
    meters.add(
      CapMeter(
        id: r.name,
        label: r.name,
        isTotal: false,
        capAed: r.capUnits! * value,
        earnedAed:
            math.min(r.capUnits!, res.usage[r.name]?.usedUnits ?? 0) * value,
        rate: r.rate > 0 ? r.rate * value : null,
        spentAed: spentByRule[r.name] ?? 0,
        categories: r.categories,
        approxSpend: false,
        isCashback: spec.isCashback,
      ),
    );
  }
  if (spec.totalCapUnits != null) {
    meters.add(
      CapMeter(
        id: totalCapKey,
        label: 'All rewards',
        isTotal: true,
        capAed: spec.totalCapUnits! * value,
        earnedAed:
            math.min(
              spec.totalCapUnits!,
              res.usage[totalCapKey]?.usedUnits ?? 0,
            ) *
            value,
        rate: topRate > 0 ? topRate : null,
        spentAed: res.spendMinor / 100,
        categories: const {},
        approxSpend: true,
        isCashback: spec.isCashback,
      ),
    );
  }
  return CardCapStatus(
    cardId: cardId,
    catalogId: catalogId,
    title: title,
    cycleStart: cycleStart,
    cycleEnd: cycleEnd,
    basis: basis,
    spendAed: res.spendMinor / 100,
    earnedAed: res.earnedUnits * value,
    meters: meters,
    hasEarningRules: topRate > 0,
    sharedWith: sharedWith,
    withPartner: withPartner,
  );
}

/// A combo's legs added up: the stack's monthly quota is the sum of what each
/// leg can earn under its caps. A leg's quota is its card-wide cap when it has
/// one, else the sum of its rule caps. Legs with no cap (Tabby earns nothing
/// itself) add nothing and are listed in [uncappedLegs].
class StackCapStatus {
  const StackCapStatus({
    required this.title,
    required this.legs,
    required this.quotaAed,
    required this.earnedAed,
    required this.remainingSpendAed,
    required this.uncappedLegs,
  });

  final String title;
  final List<CardCapStatus> legs;
  final double quotaAed;
  final double earnedAed;

  /// Spend still earning at the cap rates, summed over the capped legs.
  final double remainingSpendAed;
  final List<String> uncappedLegs;

  double get remainingAed => math.max(0, quotaAed - earnedAed);
  double get pct =>
      quotaAed <= 0 ? 0 : math.min(100, earnedAed / quotaAed * 100);
  CapLevel get level => quotaAed <= 0
      ? CapLevel.ok
      : remainingAed <= 0.005
      ? CapLevel.hit
      : pct >= nearCapPct
      ? CapLevel.near
      : CapLevel.ok;
}

List<CapMeter> _quotaMeters(CardCapStatus c) {
  final total = c.meters.where((m) => m.isTotal);
  return total.isNotEmpty ? total.toList() : c.meters;
}

StackCapStatus stackCapStatus(String title, List<CardCapStatus> legs) {
  var quota = 0.0, earned = 0.0, spend = 0.0;
  final uncapped = <String>[];
  for (final l in legs) {
    final ms = _quotaMeters(l);
    if (ms.isEmpty) {
      uncapped.add(l.title);
      continue;
    }
    for (final m in ms) {
      quota += m.capAed;
      earned += m.earnedAed;
      spend += m.remainingSpendAed ?? 0;
    }
  }
  return StackCapStatus(
    title: title,
    legs: legs,
    quotaAed: quota,
    earnedAed: earned,
    remainingSpendAed: spend,
    uncappedLegs: uncapped,
  );
}

/// A short stack name from the issuers of its cards: `Tabby+SIB`.
String stackLabel(Iterable<String> issuers) {
  final seen = <String>[];
  for (final i in issuers) {
    final s = i.trim();
    if (s.isNotEmpty && !seen.contains(s)) seen.add(s);
  }
  return seen.join('+');
}

// ---------------------------------------------------------------------------
// Alerts
// ---------------------------------------------------------------------------

/// One alert worth showing: a card or stack crossing 80% or 100% of a cap.
class CapAlert {
  const CapAlert({
    required this.key,
    required this.cardId,
    required this.title,
    required this.level,
    required this.message,
    this.isStack = false,
  });

  /// Stable per card, cap, level and cycle, so each fires once a cycle.
  final String key;
  final String cardId;
  final String title;
  final CapLevel level;

  /// `Tabby+SIB cap reached: AED 300 of 300 this month`.
  final String message;
  final bool isStack;
}

String _aed(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// `AED 300 of 300` for a cap figure.
String capFigures(double earned, double cap) =>
    'AED ${_aed(earned)} of ${_aed(cap)}';

/// The line used by alerts, Which-card and the meter: names the card or stack
/// and the figures; `null` below the near threshold.
String? capLine(String title, CapLevel level, double earned, double cap) =>
    switch (level) {
      CapLevel.hit =>
        '$title cap reached: ${capFigures(earned, cap)} this month',
      CapLevel.near =>
        '$title is nearly at its cap: ${capFigures(earned, cap)} this month',
      CapLevel.ok => null,
    };

/// Every status at or over the near threshold. [muted] holds card ids (and
/// `stack:<id>` keys) the user muted; those are left out.
List<CapAlert> capAlerts(
  List<CardCapStatus> cards, {
  List<(String id, StackCapStatus status)> stacks = const [],
  Set<String> muted = const {},
}) {
  final out = <CapAlert>[];
  for (final c in cards) {
    if (muted.contains(c.cardId) || !c.isShareLead) continue;
    final m = c.worst;
    if (m == null || m.level == CapLevel.ok) continue;
    final base = c.isShared ? '${c.title} (shared)' : c.title;
    final where = m.isTotal || c.meters.length == 1
        ? base
        : '$base ${m.label.toLowerCase()}';
    out.add(
      CapAlert(
        key: '${c.cardId}|${c.cycleStart.toIso()}|${m.id}|${m.level.name}',
        cardId: c.cardId,
        title: c.title,
        level: m.level,
        message: capLine(where, m.level, m.earnedAed, m.capAed)!,
      ),
    );
  }
  for (final (id, s) in stacks) {
    if (muted.contains('stack:$id') ||
        s.level == CapLevel.ok ||
        s.legs.length < 2)
      continue;
    final start = s.legs
        .map((l) => l.cycleStart)
        .reduce((a, b) => a > b ? a : b);
    out.add(
      CapAlert(
        key: 'stack:$id|${start.toIso()}|${s.level.name}',
        cardId: 'stack:$id',
        title: s.title,
        level: s.level,
        message: capLine(s.title, s.level, s.earnedAed, s.quotaAed)!,
        isStack: true,
      ),
    );
  }
  return out;
}

/// Alerts not yet sent: [sent] holds the keys already notified.
List<CapAlert> unsentAlerts(List<CapAlert> alerts, Set<String> sent) => [
  for (final a in alerts)
    if (!sent.contains(a.key)) a,
];
