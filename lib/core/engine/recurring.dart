/// Recurring payment / subscription detection. Pure and deterministic.
///
/// A series is a merchant with at least [minOccurrences] debits whose gaps fit
/// one cadence (weekly, fortnightly, monthly, quarterly, yearly). Amounts are
/// *fixed* when every charge is within 5% of the median (subscriptions, rent)
/// and *variable* otherwise (utilities, phone bills). Port of
/// `app/services/recurring.py`.
library;

import 'dart:math' as math;

import 'dates.dart';
import 'rewards.dart' show daysInMonth;
import 'types.dart';

const minOccurrences = 3;
const minOccurrencesYearly = 2;
const fixedTolerance = 0.05;
const priceIncreaseMinPct = 3.0;
const priceIncreaseMinMinor = 100;
const forgottenAfterCharges = 4;
const ignoredCategories = {
  'transfer', 'cc_payment', 'salary', 'other_income', 'fees', 'savings',
};

const _cadences = <(String, int, int)>[
  ('weekly', 7, 2),
  ('fortnightly', 14, 3),
  ('monthly', 30, 4),
  ('quarterly', 91, 7),
  ('yearly', 365, 12),
];

/// Merchants (lower-case substring of the normalised name) that are
/// subscriptions by nature.
const subscriptionMerchants = [
  'netflix', 'spotify', 'anghami', 'shahid', 'osn', 'disney', 'apple.com/bill', 'apple music', 'icloud',
  'google one', 'google play', 'youtube', 'amazon prime', 'prime video', 'adobe', 'microsoft', 'chatgpt',
  'openai', 'claude', 'notion', 'dropbox', 'canva', 'linkedin', 'gym', 'fitness', 'talabat pro',
  'deliveroo plus', 'noon one', 'careem plus', 'starzplay', 'tod', 'playstation', 'xbox', 'nintendo',
];

class Charge {
  const Charge(this.postedOn, this.amountMinor, this.merchant, this.key, [this.categorySlug]);
  final CalDate postedOn;
  final int amountMinor;

  /// Display name.
  final String merchant;

  /// Normalised grouping key.
  final String key;
  final String? categorySlug;
}

class PriceIncrease {
  const PriceIncrease(this.fromMinor, this.toMinor, this.increaseMinor, this.pct);
  final int fromMinor, toMinor, increaseMinor;
  final double pct;
}

class Series {
  Series({
    required this.key,
    required this.merchant,
    required this.cadence,
    required this.intervalDays,
    required this.amountKind,
    required this.typicalAmountMinor,
    required this.lastAmountMinor,
    required this.lastChargeOn,
    required this.nextExpectedOn,
    required this.occurrences,
    required this.firstChargeOn,
    required this.categorySlug,
    required this.isSubscription,
    required this.status,
    required this.anchorDay,
  });
  final String key, merchant, cadence;
  final int intervalDays;

  /// `fixed` or `variable`.
  String amountKind;
  int typicalAmountMinor;
  final int lastAmountMinor;
  final CalDate lastChargeOn;
  final CalDate nextExpectedOn;
  final int occurrences;
  final CalDate firstChargeOn;
  final String? categorySlug;
  final bool isSubscription;

  /// `active`, `due` or `lapsed`.
  final String status;
  final int anchorDay;
  PriceIncrease? priceIncrease;
  final List<String> flags = [];
}

CalDate addMonths(CalDate d, int months, [int? anchorDay]) {
  final idx = d.year * 12 + d.month - 1 + months;
  final year = idx ~/ 12, month = idx % 12 + 1;
  return CalDate(year, month, math.min(anchorDay ?? d.day, daysInMonth(year, month)));
}

CalDate advance(CalDate d, String cadence, [int? anchorDay]) => switch (cadence) {
  'weekly' => d.addDays(7),
  'fortnightly' => d.addDays(14),
  'monthly' => addMonths(d, 1, anchorDay),
  'quarterly' => addMonths(d, 3, anchorDay),
  _ => addMonths(d, 12, anchorDay),
};

(String, int)? _classify(List<int> gaps) {
  final med = median(gaps);
  for (final (name, nominal, tol) in _cadences) {
    if ((med - nominal).abs() <= tol) {
      final fit = gaps.where((g) => (g - nominal).abs() <= tol * 2).length / gaps.length;
      if (fit >= 0.7) return (name, nominal);
    }
  }
  return null;
}

bool isSubscriptionMerchant(String key) => subscriptionMerchants.any(key.contains);

/// All recurring series in [charges] (debits only), next-expected first.
List<Series> detect(List<Charge> charges, CalDate today) {
  final groups = <String, List<Charge>>{};
  for (final c in charges) {
    if (c.amountMinor > 0 && !ignoredCategories.contains(c.categorySlug) && c.key.isNotEmpty) {
      groups.putIfAbsent(c.key, () => []).add(c);
    }
  }
  final out = <Series>[];
  for (final MapEntry(key: key, value: items0) in groups.entries) {
    final items = stableSorted(items0, (a, b) => a.postedOn.compareTo(b.postedOn));
    // Several charges on one day (split payments) count as one occurrence.
    final days = <Charge>[];
    for (final c in items) {
      if (days.isNotEmpty && days.last.postedOn == c.postedOn) {
        days[days.length - 1] = Charge(c.postedOn, days.last.amountMinor + c.amountMinor, c.merchant, key, c.categorySlug);
      } else {
        days.add(c);
      }
    }
    if (days.length < minOccurrencesYearly) continue;
    final gaps = [for (var i = 1; i < days.length; i++) days[i].postedOn.daysSince(days[i - 1].postedOn)];
    final found = _classify(gaps);
    if (found == null) continue;
    final (cadence, nominal) = found;
    if (days.length < minOccurrences && cadence != 'yearly') continue;
    final amounts = [for (final c in days) c.amountMinor];
    final med = median(amounts).truncate();
    final fixed = amounts.every((a) => (a - med).abs() <= med * fixedTolerance);
    final dayCounts = <int, int>{};
    for (final c in days) {
      dayCounts[c.postedOn.day] = (dayCounts[c.postedOn.day] ?? 0) + 1;
    }
    final anchor = dayCounts.keys.reduce((a, b) {
      final ca = dayCounts[a]!, cb = dayCounts[b]!;
      return (cb > ca || (cb == ca && b > a)) ? b : a;
    });
    final last = days.last;
    final nxt = advance(last.postedOn, cadence, anchor);
    final grace = math.max(3, nominal ~/ 6);
    final status = nxt >= today ? 'active' : (today.daysSince(nxt) <= grace ? 'due' : 'lapsed');
    final recent = amounts.length >= 3 ? amounts.sublist(amounts.length - 3) : amounts;
    final series = Series(
      key: key,
      merchant: last.merchant,
      cadence: cadence,
      intervalDays: nominal,
      amountKind: fixed ? 'fixed' : 'variable',
      typicalAmountMinor: fixed ? med : median(recent).truncate(),
      lastAmountMinor: last.amountMinor,
      lastChargeOn: last.postedOn,
      nextExpectedOn: nxt,
      occurrences: days.length,
      firstChargeOn: days.first.postedOn,
      categorySlug: last.categorySlug,
      isSubscription: isSubscriptionMerchant(key),
      status: status,
      anchorDay: anchor,
    );
    _priceIncrease(series, amounts);
    out.add(series);
  }
  return stableSorted(out, (a, b) {
    final c = a.nextExpectedOn.compareTo(b.nextExpectedOn);
    return c != 0 ? c : a.merchant.compareTo(b.merchant);
  });
}

void _priceIncrease(Series s, List<int> amounts) {
  final earlier = amounts.sublist(0, amounts.length - 1);
  if (earlier.length < 2) return;
  final base = median(earlier).truncate();
  if (!earlier.every((a) => (a - base).abs() <= base * fixedTolerance)) return;
  final now = amounts.last;
  final pct = base != 0 ? (now - base) / base * 100 : 0.0;
  if (now - base >= priceIncreaseMinMinor && pct >= priceIncreaseMinPct) {
    s.priceIncrease = PriceIncrease(base, now, now - base, roundTo(pct, 1));
    s.flags.add('price_increase');
    s.amountKind = 'fixed';
    s.typicalAmountMinor = now;
  }
}

/// A subscription that keeps charging and that the user never told us they
/// want.
bool forgotten(Series s, {required bool reviewed}) =>
    s.isSubscription &&
    !reviewed &&
    s.status != 'lapsed' &&
    s.occurrences >= forgottenAfterCharges &&
    const {'monthly', 'quarterly', 'yearly'}.contains(s.cadence);

/// Expected charge dates of an active/due series in [start, end] inclusive.
List<CalDate> occurrencesBetween(Series s, CalDate start, CalDate end) {
  if (s.status == 'lapsed') return const [];
  var d = s.nextExpectedOn;
  final out = <CalDate>[];
  if (d < start) {
    // Due but not yet seen: expected as soon as possible.
    out.add(start);
    d = advance(d, s.cadence, s.anchorDay);
  }
  while (d <= end) {
    if (d >= start) out.add(d);
    d = advance(d, s.cadence, s.anchorDay);
  }
  return out;
}

int monthlyCostMinor(Series s) {
  final factor = switch (s.cadence) {
    'weekly' => 52 / 12,
    'fortnightly' => 26 / 12,
    'monthly' => 1.0,
    'quarterly' => 1 / 3,
    _ => 1 / 12,
  };
  return roundHalfEven(s.typicalAmountMinor * factor);
}
