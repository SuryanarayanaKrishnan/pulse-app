/// Budget overruns, explained: is this month's overspend a one-off or a habit?
///
/// Pure Dart over whole minor units (fils), no Flutter, no I/O, no model. For
/// each category that is over its plan right now, this looks at the last six
/// months of actual against planned and says one of four honest things:
///
///  * [OverrunKind.oneOff]: one payment, or one month, with normal months
///    around it. Nothing about the plan needs to change.
///  * [OverrunKind.pattern]: over in at least three of the last six months, or
///    climbing month after month. Worth moving the ceiling; a new one is
///    suggested (never applied).
///  * [OverrunKind.watch]: over now and once before, not yet a habit.
///  * [OverrunKind.tooEarly]: fewer than two earlier months to compare with.
///
/// A month the person marked as a one-off is left out of every count and every
/// typical amount, and marking never touches the plan. Everything is an
/// estimate from past spending, and the wording says so.
library;

import 'dart:math' as math;

/// How many completed months are looked at.
const overrunLookback = 5;

/// A month only counts as over when it is over by at least this share of the
/// plan, and by at least [overrunMinMinor], so pennies do not make a habit.
const overrunTolerance = 0.03;
const overrunMinMinor = 1000; // AED 10

enum OverrunKind {
  oneOff('one_off', 'One-off'),
  pattern('pattern', 'Recurring'),
  watch('watch', 'Watch'),
  tooEarly('early', 'Too early');

  const OverrunKind(this.key, this.label);

  /// The value used in analytics.
  final String key;
  final String label;
}

/// Why the kind was chosen, for the plain sentence.
enum OverrunReason {
  singlePurchase,
  singleMonth,
  repeatedMonths,
  risingTrend,
  oneEarlierMonth,
  twoMonthsRunning,
  shortHistory,
}

/// One payment, as the analysis needs it.
class OverrunTx {
  const OverrunTx({
    required this.id,
    required this.month,
    required this.merchant,
    required this.amountMinor,
  });
  final String id;

  /// `YYYY-MM-01`.
  final String month;
  final String merchant;

  /// Always positive.
  final int amountMinor;
}

class MonthAmount {
  const MonthAmount(this.month, this.plannedMinor, this.spentMinor);
  final String month;
  final int plannedMinor;
  final int spentMinor;

  int get overMinor => spentMinor - plannedMinor;

  /// Material overspend: past the tolerance and the floor.
  bool get isOver =>
      plannedMinor > 0 &&
      overMinor > 0 &&
      overMinor >=
          math.max(overrunMinMinor, (plannedMinor * overrunTolerance).round());
}

/// What the analysis reads for one category.
class OverrunInput {
  const OverrunInput({
    required this.categoryId,
    required this.months,
    this.txs = const [],
    this.markedOneOff = const {},
  });
  final String categoryId;

  /// Planned and spent per month, any order; the current month included.
  final List<MonthAmount> months;
  final List<OverrunTx> txs;

  /// Months (`YYYY-MM-01`) the person called a one-off.
  final Set<String> markedOneOff;
}

class Contributor {
  const Contributor(this.merchant, this.amountMinor, this.count);
  final String merchant;
  final int amountMinor;
  final int count;
}

class CategoryOverrun {
  const CategoryOverrun({
    required this.categoryId,
    required this.kind,
    required this.reason,
    required this.month,
    required this.plannedMinor,
    required this.spentMinor,
    required this.monthsCompared,
    required this.monthsOver,
    required this.contributors,
    this.largest,
    this.onePayment = false,
    this.typicalOverMinor,
    this.suggestedCeilingMinor,
  });

  final String categoryId;
  final OverrunKind kind;
  final OverrunReason reason;
  final String month;
  final int plannedMinor;
  final int spentMinor;

  /// Earlier months with a plan that were compared (0 to [overrunLookback]).
  final int monthsCompared;

  /// Of the months compared plus this one, how many were over.
  final int monthsOver;

  /// This month's biggest merchants in the category, largest first (up to 3).
  final List<Contributor> contributors;

  /// The single biggest payment this month, when there is one.
  final OverrunTx? largest;

  /// That one payment alone accounts for the whole overspend.
  final bool onePayment;

  /// Typical amount over, across the over months. Set for a pattern.
  final int? typicalOverMinor;

  /// A new monthly ceiling, rounded up. Set only for a pattern and only when
  /// it is above the current plan.
  final int? suggestedCeilingMinor;

  int get overMinor => spentMinor - plannedMinor;
}

int _median(List<int> v) {
  final s = [...v]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : ((s[m - 1] + s[m]) / 2).round();
}

/// Rounds up to a tidy amount: 5 under AED 100, 10 under 500, 50 under 2,000,
/// 100 above.
int niceCeilingMinor(int minor) {
  final aed = (minor / 100).ceil();
  final step = aed < 100 ? 5 : (aed < 500 ? 10 : (aed < 2000 ? 50 : 100));
  return ((aed + step - 1) ~/ step) * step * 100;
}

/// The month key before [month].
String _prevMonth(String month) {
  final y = int.parse(month.substring(0, 4)),
      m = int.parse(month.substring(5, 7));
  final i = y * 12 + m - 2;
  return '${(i ~/ 12).toString().padLeft(4, '0')}-${(i % 12 + 1).toString().padLeft(2, '0')}-01';
}

/// Classifies [input] for [currentMonth] (`YYYY-MM-01`). Null when the
/// category is not over its plan now (or the overrun was marked a one-off).
CategoryOverrun? analyseOverrun(
  OverrunInput input, {
  required String currentMonth,
}) {
  MonthAmount? found;
  final earlier = <MonthAmount>[];
  for (final m in input.months) {
    if (m.month == currentMonth) {
      found = m;
    } else if (m.month.compareTo(currentMonth) < 0 && m.plannedMinor > 0) {
      earlier.add(m);
    }
  }
  if (found == null || !found.isOver) return null;
  final now = found;
  if (input.markedOneOff.contains(currentMonth)) return null;

  earlier.sort((a, b) => a.month.compareTo(b.month));
  // Only the consecutive-ish recent window: the last [overrunLookback] months
  // by calendar, so an old gap does not stretch the window.
  final floor = () {
    var k = currentMonth;
    for (var i = 0; i < overrunLookback; i++) {
      k = _prevMonth(k);
    }
    return k;
  }();
  final hist = [
    for (final m in earlier)
      if (m.month.compareTo(floor) >= 0) m,
  ];

  bool marked(MonthAmount m) => input.markedOneOff.contains(m.month);
  final overHist = [
    for (final m in hist)
      if (m.isOver && !marked(m)) m,
  ];
  final n = hist.length;

  // This month's payments and who they went to.
  final mine = [
    for (final t in input.txs)
      if (t.month == currentMonth) t,
  ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
  final byMerchant = <String, (int, int)>{};
  for (final t in mine) {
    final cur = byMerchant[t.merchant] ?? (0, 0);
    byMerchant[t.merchant] = (cur.$1 + t.amountMinor, cur.$2 + 1);
  }
  final contributors = [
    for (final e in byMerchant.entries)
      Contributor(e.key, e.value.$1, e.value.$2),
  ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
  final largest = mine.isEmpty ? null : mine.first;
  final over = now.overMinor;
  final single =
      largest != null &&
      largest.amountMinor >= over &&
      largest.amountMinor * 10 >= now.spentMinor * 3;

  CategoryOverrun make(
    OverrunKind kind,
    OverrunReason reason, {
    int? typicalOver,
    int? ceiling,
  }) => CategoryOverrun(
    categoryId: input.categoryId,
    kind: kind,
    reason: reason,
    month: currentMonth,
    plannedMinor: now.plannedMinor,
    spentMinor: now.spentMinor,
    monthsCompared: n,
    monthsOver: overHist.length + 1,
    contributors: contributors.take(3).toList(),
    largest: largest,
    onePayment: single,
    typicalOverMinor: typicalOver,
    suggestedCeilingMinor: ceiling,
  );

  // Rising: the last three completed months and this one each higher than the
  // one before, and this month at least 20% above the first of them.
  final recent = hist.length >= 3
      ? hist.sublist(hist.length - 3)
      : <MonthAmount>[];
  final climbing =
      !single &&
      recent.length == 3 &&
      !recent.any(marked) &&
      recent[0].spentMinor < recent[1].spentMinor &&
      recent[1].spentMinor < recent[2].spentMinor &&
      recent[2].spentMinor < now.spentMinor &&
      now.spentMinor >= recent[0].spentMinor * 1.2;

  final repeated = n >= 2 && overHist.length >= 2;
  if (repeated || climbing) {
    final overs = [...overHist, now];
    final typicalOver = _median([for (final m in overs) m.overMinor]);
    List<int> basis;
    if (climbing && !repeated) {
      basis = [for (final m in recent) m.spentMinor, now.spentMinor];
    } else {
      basis = [
        for (final m in hist)
          if (!marked(m)) m.spentMinor,
        now.spentMinor,
      ];
    }
    var typical = _median(basis);
    if (typical <= now.plannedMinor)
      typical = _median([for (final m in overs) m.spentMinor]);
    if (climbing && !repeated) typical = math.max(typical, now.spentMinor);
    final ceiling = niceCeilingMinor(typical);
    return make(
      OverrunKind.pattern,
      repeated ? OverrunReason.repeatedMonths : OverrunReason.risingTrend,
      typicalOver: typicalOver,
      ceiling: ceiling > now.plannedMinor ? ceiling : null,
    );
  }

  if (n < 2) {
    return make(OverrunKind.tooEarly, OverrunReason.shortHistory);
  }
  if (overHist.isEmpty) {
    return make(
      OverrunKind.oneOff,
      single ? OverrunReason.singlePurchase : OverrunReason.singleMonth,
    );
  }
  // Over in exactly one earlier month, and this month.
  if (single) return make(OverrunKind.oneOff, OverrunReason.singlePurchase);
  if (n == 2) return make(OverrunKind.tooEarly, OverrunReason.twoMonthsRunning);
  return make(OverrunKind.watch, OverrunReason.oneEarlierMonth);
}

/// Every over-plan category, biggest overrun first.
List<CategoryOverrun> analyseOverruns(
  Iterable<OverrunInput> inputs, {
  required String currentMonth,
}) {
  final out =
      [for (final i in inputs) ?analyseOverrun(i, currentMonth: currentMonth)]
        ..sort((a, b) {
          final c = b.overMinor.compareTo(a.overMinor);
          return c != 0 ? c : a.categoryId.compareTo(b.categoryId);
        });
  return out;
}

// ---- where the extra money would come from -----------------------------------------

/// A flexible category with money still unspent this month.
class Slack {
  const Slack(this.categoryId, this.unusedMinor);
  final String categoryId;
  final int unusedMinor;
}

class FundingHint {
  const FundingHint({
    required this.extraMinor,
    required this.sources,
    required this.shortMinor,
  });

  /// What raising the ceiling adds to the monthly plan.
  final int extraMinor;

  /// Flexible categories with room, most room first (up to 2).
  final List<Slack> sources;

  /// How much of [extraMinor] those categories cannot cover this month.
  final int shortMinor;

  bool get covered => shortMinor <= 0;
}

/// Where a ceiling raise of [extraMinor] could be funded from: unspent money
/// in other flexible categories. [slack] holds every flexible category with
/// something left this month; the over category itself is skipped.
FundingHint fundingHint({
  required int extraMinor,
  required Iterable<Slack> slack,
  required String exceptId,
}) {
  final ordered = [
    for (final s in slack)
      if (s.categoryId != exceptId && s.unusedMinor > 0) s,
  ]..sort((a, b) => b.unusedMinor.compareTo(a.unusedMinor));
  final total = ordered.fold<int>(0, (a, s) => a + s.unusedMinor);
  return FundingHint(
    extraMinor: extraMinor,
    sources: ordered.take(2).toList(),
    shortMinor: math.max(0, extraMinor - total),
  );
}

// ---- wording -----------------------------------------------------------------------

/// "AED 1,240" from fils, whole dirhams.
String aedWhole(int minor) {
  final aed = (minor / 100).round();
  final digits = aed.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
    b.write(digits[i]);
  }
  return 'AED $b';
}

/// "Dining is AED 340 over".
String overrunTitle(CategoryOverrun o, String label) =>
    '$label is ${aedWhole(o.overMinor)} over';

/// One plain sentence on why this is labelled the way it is.
String overrunSentence(CategoryOverrun o) {
  final top = o.largest;
  final one = top == null
      ? null
      : '${top.merchant} (${aedWhole(top.amountMinor)})';
  switch (o.reason) {
    case OverrunReason.singlePurchase:
      return 'One payment, $one, accounts for it. The earlier months stayed within plan or close to it.';
    case OverrunReason.singleMonth:
      return 'Over this month only. The ${o.monthsCompared} months before were within plan.';
    case OverrunReason.repeatedMonths:
      final of = math.min(o.monthsCompared + 1, overrunLookback + 1);
      final typ = o.typicalOverMinor == null
          ? ''
          : ', by about ${aedWhole(o.typicalOverMinor!)} a time';
      return 'Over in ${o.monthsOver} of the last $of months$typ.';
    case OverrunReason.risingTrend:
      return 'Spending here has risen each month and is now above plan.';
    case OverrunReason.oneEarlierMonth:
      return 'Over now and in one of the ${o.monthsCompared} months before. Not a habit yet.';
    case OverrunReason.twoMonthsRunning:
      return 'Over this month and last. One more month will show if it is a habit.';
    case OverrunReason.shortHistory:
      if (o.onePayment)
        return 'One payment, $one, accounts for it. Too early to say if it repeats.';
      return o.monthsCompared == 0
          ? 'Not enough months yet to tell if this repeats.'
          : 'Only one earlier month to compare with, so it is too early to tell.';
  }
}

/// Shown with every suggestion.
const overrunCaveat =
    'Estimates from your past spending, to help you plan. You decide the budget; nothing changes unless you tap.';

/// "Raise to AED 1,200".
String raiseLabel(int ceilingMinor) => 'Raise to ${aedWhole(ceilingMinor)}';

/// Where the extra would come from, in a sentence. [labelOf] names a category.
String fundingSentence(FundingHint h, String Function(String id) labelOf) {
  if (h.sources.isEmpty) {
    return 'Your other flexible categories have nothing spare this month, so the extra would come out of what you save.';
  }
  final names = [
    for (final s in h.sources)
      '${labelOf(s.categoryId)} (${aedWhole(s.unusedMinor)} unused)',
  ].join(' and ');
  return h.covered
      ? 'The extra ${aedWhole(h.extraMinor)} a month could come from $names.'
      : 'Only $names has room, ${aedWhole(h.shortMinor)} short of the extra ${aedWhole(h.extraMinor)}; the rest would come out of what you save.';
}
