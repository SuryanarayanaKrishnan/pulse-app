/// Recurring investing rules ("buy $200 of VOO every month"): when buys are
/// due, how well they were kept, and what a confirmed buy does to a holding.
/// Pure functions over [CalDate]; no I/O, no clock (callers pass today).
library;

import 'dates.dart';
import 'valuation.dart';

enum RuleFrequency {
  weekly('weekly', 'Weekly'),
  monthly('monthly', 'Monthly');

  const RuleFrequency(this.wire, this.label);
  final String wire, label;

  static RuleFrequency fromWire(String s) =>
      values.firstWhere((f) => f.wire == s, orElse: () => monthly);
}

enum OccurrenceStatus {
  pending,
  confirmed,
  skipped;

  static OccurrenceStatus fromWire(String s) =>
      values.firstWhere((f) => f.name == s, orElse: () => pending);
}

const fundRulePrefix = 'MF:';
String fundRuleSymbol(String holdingId) => '$fundRulePrefix$holdingId';

/// The plan: put [amountMinor] (of [currency], minor units) into [symbol].
class InvestRule {
  const InvestRule({
    required this.id,
    required this.symbol,
    this.name,
    required this.amountMinor,
    this.currency = 'USD',
    this.frequency = RuleFrequency.monthly,
    this.day = 1,
    required this.startDate,
    this.endDate,
    this.active = true,
  });

  final String id, symbol;
  final String? name;
  final int amountMinor;
  final String currency;
  final RuleFrequency frequency;

  /// Monthly: day of month (1-31, clamped to the month's length).
  /// Weekly: weekday, 1 = Monday .. 7 = Sunday.
  final int day;
  final CalDate startDate;
  final CalDate? endDate;
  final bool active;

  InvestRule copyWith({
    int? amountMinor,
    RuleFrequency? frequency,
    int? day,
    bool? active,
    CalDate? endDate,
    bool clearEnd = false,
  }) => InvestRule(
    id: id,
    symbol: symbol,
    name: name,
    amountMinor: amountMinor ?? this.amountMinor,
    currency: currency,
    frequency: frequency ?? this.frequency,
    day: day ?? this.day,
    startDate: startDate,
    endDate: clearEnd ? null : (endDate ?? this.endDate),
    active: active ?? this.active,
  );

  /// A SIP into a mutual fund: [symbol] is `MF:<fund holding id>`.
  bool get isFund => symbol.startsWith(fundRulePrefix);
  String? get fundId => isFund ? symbol.substring(fundRulePrefix.length) : null;

  /// What to call it on screen: the fund's name, or the ticker.
  String get label => isFund ? (name ?? 'mutual fund') : symbol;

  String get cadenceLabel => switch (frequency) {
    RuleFrequency.monthly => 'every month on the ${ordinal(day)}',
    RuleFrequency.weekly => 'every ${weekdayName(day)}',
  };
}

/// One planned buy and what became of it.
class RuleOccurrence {
  const RuleOccurrence({
    required this.id,
    required this.ruleId,
    required this.due,
    required this.amountMinor,
    this.status = OccurrenceStatus.pending,
    this.price,
    this.units,
    this.decidedOn,
  });

  final String id, ruleId;
  final CalDate due;
  final int amountMinor;
  final OccurrenceStatus status;

  /// Price per unit and units bought, set when confirmed.
  final double? price, units;
  final CalDate? decidedOn;
}

String ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
String weekdayName(int d) => _weekdays[(d - 1).clamp(0, 6)];

CalDate _monthDay(int y, int m, int day) {
  final last = DateTime.utc(y, m + 1, 0).day;
  return CalDate(y, m, day > last ? last : day);
}

int _weekday(CalDate d) => d.toUtcMidnight().weekday;

/// Every date the rule fires within [from]..[to] inclusive, never before the
/// rule's start or after its end.
List<CalDate> scheduledDates(InvestRule r, CalDate from, CalDate to) {
  final lo = from < r.startDate ? r.startDate : from;
  final hi = r.endDate != null && r.endDate! < to ? r.endDate! : to;
  if (lo > hi) return const [];
  final out = <CalDate>[];
  switch (r.frequency) {
    case RuleFrequency.monthly:
      var y = lo.year, m = lo.month;
      while (true) {
        final d = _monthDay(y, m, r.day);
        if (d > hi) break;
        if (d >= lo) out.add(d);
        m++;
        if (m > 12) {
          m = 1;
          y++;
        }
      }
    case RuleFrequency.weekly:
      var d = lo;
      while (_weekday(d) != r.day) {
        d = d.addDays(1);
      }
      for (; d <= hi; d = d.addDays(7)) {
        out.add(d);
      }
  }
  return out;
}

/// The next date the rule fires on or after [today] (null when ended).
CalDate? nextDue(InvestRule r, CalDate today) {
  if (!r.active) return null;
  final upto = today.addDays(400);
  final l = scheduledDates(r, today, upto);
  return l.isEmpty ? null : l.first;
}

/// Occurrences that should exist by [today] but were never recorded: each
/// becomes a pending "did you buy?" the user confirms or skips. Looks back at
/// most [lookbackDays] so an old rule does not flood the screen on first run.
List<CalDate> dueButUnrecorded(
  InvestRule r,
  Set<CalDate> recorded,
  CalDate today, {
  int lookbackDays = 62,
}) {
  if (!r.active) return const [];
  final floor = today.addDays(-lookbackDays);
  return [
    for (final d in scheduledDates(r, floor, today))
      if (!recorded.contains(d)) d,
  ];
}

class Adherence {
  const Adherence({
    required this.confirmed,
    required this.skipped,
    required this.pending,
    required this.streak,
    required this.investedMinor,
  });

  final int confirmed, skipped, pending;

  /// Most recent run of confirmed buys without a skip or a miss.
  final int streak;

  /// Total put in through confirmed buys, in the rule's currency.
  final int investedMinor;

  int get decided => confirmed + skipped;
  int get total => confirmed + skipped + pending;

  /// Share of planned buys that happened, 0-100; null before any is due.
  double? get pct => total == 0 ? null : confirmed / total * 100;

  String get summary {
    if (total == 0) return 'No buys due yet';
    if (pending > 0 && confirmed == 0 && skipped == 0)
      return '$pending to confirm';
    return '$confirmed of $total kept';
  }
}

Adherence adherenceOf(Iterable<RuleOccurrence> occurrences) {
  final list = occurrences.toList()..sort((a, b) => a.due.compareTo(b.due));
  var c = 0, s = 0, p = 0, invested = 0;
  for (final o in list) {
    switch (o.status) {
      case OccurrenceStatus.confirmed:
        c++;
        invested += o.amountMinor;
      case OccurrenceStatus.skipped:
        s++;
      case OccurrenceStatus.pending:
        p++;
    }
  }
  var streak = 0;
  for (final o in list.reversed) {
    if (o.status == OccurrenceStatus.confirmed) {
      streak++;
    } else if (o.status == OccurrenceStatus.pending) {
      continue; // not decided yet: neither breaks nor extends the run
    } else {
      break;
    }
  }
  return Adherence(
    confirmed: c,
    skipped: s,
    pending: p,
    streak: streak,
    investedMinor: invested,
  );
}

/// A holding after a buy of [amount] (currency units, not minor) at [price].
class BuyResult {
  const BuyResult(this.units, this.avgCost, this.bought);
  final double units, avgCost, bought;
}

/// Weighted-average cost after buying [amount] at [price]. Starts from
/// [units]/[avgCost] (null average = cost unknown, so the new average is the
/// price paid only when nothing was held; otherwise it stays unknown).
BuyResult applyBuy({
  required double units,
  double? avgCost,
  required double amount,
  required double price,
}) {
  final bought = price > 0 ? amount / price : 0.0;
  final total = units + bought;
  if (units <= 0) return BuyResult(total, price, bought);
  if (avgCost == null) return BuyResult(total, 0, bought);
  final avg = (units * avgCost + amount) / total;
  return BuyResult(total, avg, bought);
}

/// Position value and P&L for a stock/ETF line, in the holding's currency and
/// in AED when an FX rate is known. Same maths as funds: units x price.
FundValue valuePosition({
  required double units,
  required double price,
  double? avgCost,
  required double? fxToAed,
}) =>
    valueFund(units: units, nav: price, avgCostNav: avgCost, fxToAed: fxToAed);

// ---- "buy $200 of VOO monthly" ---------------------------------------------------

class RuleDraft {
  const RuleDraft({
    required this.symbol,
    required this.amountMinor,
    required this.currency,
    required this.frequency,
    required this.day,
  });
  final String symbol, currency;
  final int amountMinor, day;
  final RuleFrequency frequency;
}

const _dayNames = {
  'monday': 1,
  'mon': 1,
  'tuesday': 2,
  'tue': 2,
  'tues': 2,
  'wednesday': 3,
  'wed': 3,
  'thursday': 4,
  'thu': 4,
  'thur': 4,
  'thurs': 4,
  'friday': 5,
  'fri': 5,
  'saturday': 6,
  'sat': 6,
  'sunday': 7,
  'sun': 7,
};

final _stop = {
  'I',
  'BUY',
  'INVEST',
  'MONTHLY',
  'WEEKLY',
  'EVERY',
  'MONTH',
  'WEEK',
  'USD',
  'AED',
  'EUR',
  'INR',
  'GBP',
  'ON',
  'THE',
  'IN',
  'OF',
  'OR',
  'AND',
  'EACH',
  'DAY',
  'FOR',
  'A',
  'PER',
};

/// Understands "buy $200 of VOO monthly", "invest 500 AED in VTI every month
/// on the 5th", "200 usd QQQ weekly on friday". Null when there is no amount
/// or no ticker.
RuleDraft? parseRuleText(String text) {
  final t = text.trim();
  final lower = t.toLowerCase();
  final am = RegExp(
    r'(?:\$|usd|aed|eur|gbp|inr)?\s*(\d[\d,]*(?:\.\d+)?)\s*(usd|aed|eur|gbp|inr|dollars?|bucks)?',
    caseSensitive: false,
  ).firstMatch(t);
  if (am == null) return null;
  final amount = double.tryParse(am[1]!.replaceAll(',', ''));
  if (amount == null || amount <= 0) return null;
  var currency = 'USD';
  final cm = RegExp(
    r'\b(usd|aed|eur|gbp|inr)\b',
    caseSensitive: false,
  ).firstMatch(t);
  if (cm != null) {
    currency = cm[1]!.toUpperCase();
  } else if (!t.contains(r'$') &&
      (lower.contains('dirham') || lower.contains('dhs'))) {
    currency = 'AED';
  }

  String? sym;
  for (final m in RegExp(
    r'\b([A-Za-z]{1,5}(?:[.\-][A-Za-z])?)\b',
  ).allMatches(t)) {
    final w = m[1]!.toUpperCase();
    if (_stop.contains(w) || _dayNames.containsKey(w.toLowerCase())) continue;
    // Prefer an actual all-caps ticker as typed; fall back to the first word after "of"/"in".
    if (m[1]! == m[1]!.toUpperCase()) {
      sym = w;
      break;
    }
  }
  sym ??= RegExp(
    r'\b(?:of|in|into)\s+\$?([A-Za-z]{1,5})\b',
    caseSensitive: false,
  ).firstMatch(t)?[1]?.toUpperCase();
  if (sym == null || _stop.contains(sym)) return null;

  var freq = RuleFrequency.monthly;
  var day = 1;
  if (RegExp(r'week|weekly').hasMatch(lower) ||
      _dayNames.keys.any((d) => RegExp('\\b$d\\b').hasMatch(lower))) {
    freq = RuleFrequency.weekly;
    day = 1;
    for (final e in _dayNames.entries) {
      if (RegExp('\\b${e.key}\\b').hasMatch(lower)) {
        day = e.value;
        break;
      }
    }
  } else {
    final dm = RegExp(r'\b(?:on\s+(?:the\s+)?)?(\d{1,2})(?:st|nd|rd|th)\b')
        .firstMatch(lower);
    if (dm != null) {
      final v = int.parse(dm[1]!);
      if (v >= 1 && v <= 31) day = v;
    }
  }
  return RuleDraft(
    symbol: sym,
    amountMinor: (amount * 100).round(),
    currency: currency,
    frequency: freq,
    day: day,
  );
}

// ---- "SIP of 5000 rupees monthly in Parag Parikh Flexi Cap" ------------------------

class SipDraft {
  const SipDraft({
    required this.fundQuery,
    required this.amountMinor,
    required this.currency,
    required this.frequency,
    required this.day,
  });

  /// The words that name the fund, for a scheme search.
  final String fundQuery;
  final String currency;
  final int amountMinor, day;
  final RuleFrequency frequency;
}

/// Understands "SIP 5000 monthly in Parag Parikh Flexi Cap", "invest ₹10,000
/// every month on the 7th into HDFC Index Fund Nifty 50", "₹2000 weekly sip
/// mirae asset large cap". Null without an amount or a fund name. Rupees are
/// the default: SIPs are an Indian product.
SipDraft? parseSipText(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  RegExpMatch? amountMatch;
  double? amount;
  for (final m in RegExp(
    r'(?:₹|rs\.?|inr|\$|usd|aed)?\s*(\d[\d,]*(?:\.\d+)?)\s*(?:rupees?|inr|aed|usd)?',
    caseSensitive: false,
  ).allMatches(t)) {
    // "7th" and the 50 in "Nifty 50" are not the amount: it is the first
    // figure of 100 or more that is not an ordinal.
    if (RegExp(
      r'^(?:st|nd|rd|th)',
      caseSensitive: false,
    ).hasMatch(t.substring(m.start + m[0]!.indexOf(m[1]!) + m[1]!.length))) {
      continue;
    }
    final v = double.tryParse(m[1]!.replaceAll(',', ''));
    if (v != null && v >= 100) {
      amount = v;
      amountMatch = m;
      break;
    }
  }
  if (amount == null || amountMatch == null) return null;
  var currency = 'INR';
  if (RegExp(r'\baed\b|dirham', caseSensitive: false).hasMatch(t))
    currency = 'AED';
  if (t.contains(r'$') ||
      RegExp(r'\busd\b', caseSensitive: false).hasMatch(t)) {
    currency = 'USD';
  }

  final lower = t.toLowerCase();
  var freq = RuleFrequency.monthly;
  var day = 1;
  if (RegExp(r'\bweekly\b|\bevery week\b|\beach week\b').hasMatch(lower) ||
      _dayNames.keys.any((d) => RegExp('\\b$d\\b').hasMatch(lower))) {
    freq = RuleFrequency.weekly;
    for (final e in _dayNames.entries) {
      if (RegExp('\\b${e.key}\\b').hasMatch(lower)) {
        day = e.value;
        break;
      }
    }
  } else {
    final dm = RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)\b').firstMatch(lower);
    if (dm != null) {
      final v = int.parse(dm[1]!);
      if (v >= 1 && v <= 31) day = v;
    }
  }

  var q = '${t.substring(0, amountMatch.start)} ${t.substring(amountMatch.end)}'
      .replaceAll(
        RegExp(r'\b\d{1,2}(?:st|nd|rd|th)\b', caseSensitive: false),
        ' ',
      )
      .replaceAll(
        RegExp(
          r'\b(?:sip|invest|investing|buy|monthly|weekly|every|each|month|week|day|on|the|of|in|into|a|an|per|for|my|to|mutual fund|rupees?)\b',
          caseSensitive: false,
        ),
        ' ',
      );
  for (final d in _dayNames.keys) {
    q = q.replaceAll(RegExp('\\b$d\\b', caseSensitive: false), ' ');
  }
  q = q
      .replaceAll(RegExp(r'[^A-Za-z0-9&\- ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (q.length < 3) return null;
  return SipDraft(
    fundQuery: q,
    amountMinor: (amount * 100).round(),
    currency: currency,
    frequency: freq,
    day: day,
  );
}
