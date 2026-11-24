/// Local valuation maths for jewellery, mutual funds and reminders. Pure
/// functions over integers (minor units) and doubles; no I/O, so every figure
/// is unit-tested.
library;

import 'dates.dart';
import 'prices.dart';
import 'types.dart';

/// Half-even rounding with float noise (1e-6) removed first.
int _round(double x) => roundHalfEven((x * 1e6).round() / 1e6);

// ---- gold / jewellery ---------------------------------------------------------

const jewelleryKarats = [24, 22, 21, 18];

/// Fineness of a karat: 24k = 1, 22k = 0.9167, 21k = 0.875, 18k = 0.75.
double purityForKarat(int karat) => karat / 24;

/// The usual stamped fineness ("916" for 22k).
String finenessLabel(int karat) => switch (karat) {
  24 => '999',
  22 => '916',
  21 => '875',
  18 => '750',
  _ => (purityForKarat(karat) * 1000).round().toString(),
};

/// Karat closest to a fineness (0.916 -> 22), or null when none is near.
int? karatForPurity(double purity) {
  for (final k in jewelleryKarats) {
    if ((purityForKarat(k) - purity).abs() < 0.006) return k;
  }
  return null;
}

class JewelleryValue {
  const JewelleryValue({
    required this.pureGrams,
    required this.pricePerGram,
    required this.valueMinor,
    this.purchasePriceMinor,
    this.makingChargesMinor,
  });

  /// weight x purity.
  final double pureGrams;

  /// AED per gram of 24k gold used.
  final double pricePerGram;

  /// Melt value in AED fils: pure grams x 24k price. Making charges and dealer
  /// spread are not included, so this is what the gold itself is worth.
  final int valueMinor;
  final int? purchasePriceMinor;
  final int? makingChargesMinor;

  /// Melt value minus what was paid (total, making charges included). Null
  /// without a purchase price.
  int? get gainMinor => purchasePriceMinor == null ? null : valueMinor - purchasePriceMinor!;
  double? get gainPct {
    final p = purchasePriceMinor;
    return p == null || p <= 0 ? null : (valueMinor - p) / p * 100;
  }
}

/// Value of [weightGrams] of gold at [karat] (or an explicit [purity]) from the
/// 24k price in AED per gram. Rounded half-even to whole fils.
JewelleryValue valueJewellery({
  required double weightGrams,
  required double aedPerGram24,
  int karat = 22,
  double? purity,
  int? purchasePriceMinor,
  int? makingChargesMinor,
}) {
  final p = purity ?? purityForKarat(karat);
  final pure = weightGrams * p;
  return JewelleryValue(
    pureGrams: pure,
    pricePerGram: aedPerGram24,
    valueMinor: _round(pure * aedPerGram24 * 100),
    purchasePriceMinor: purchasePriceMinor,
    makingChargesMinor: makingChargesMinor,
  );
}

// ---- mutual funds -------------------------------------------------------------

class FundValue {
  const FundValue({
    required this.valueAedMinor,
    this.costAedMinor,
    required this.fxRate,
    required this.valueNativeMinor,
    this.costNativeMinor,
  });

  /// Current value / cost in AED fils; null when there is no FX rate.
  final int? valueAedMinor;
  final int? costAedMinor;
  final double? fxRate;

  /// Value in the fund's own currency (minor units).
  final int valueNativeMinor;
  final int? costNativeMinor;

  int? get gainAedMinor => valueAedMinor == null || costAedMinor == null ? null : valueAedMinor! - costAedMinor!;
  double? get gainPct {
    final c = costNativeMinor;
    return c == null || c <= 0 ? null : (valueNativeMinor - c) / c * 100;
  }
}

/// units x NAV in the fund currency, converted at [fxToAed] (AED per unit of
/// that currency; null = unknown, so the AED value is null, never a guess).
FundValue valueFund({
  required double units,
  required double nav,
  double? avgCostNav,
  required double? fxToAed,
}) {
  final native = _round(units * nav * 100);
  final cost = avgCostNav == null ? null : _round(units * avgCostNav * 100);
  int? aed(int v) => fxToAed == null ? null : _round(v * fxToAed);
  return FundValue(
    valueAedMinor: aed(native),
    costAedMinor: cost == null ? null : aed(cost),
    fxRate: fxToAed,
    valueNativeMinor: native,
    costNativeMinor: cost,
  );
}

/// Next SIP debit on or after [today] for a monthly [day] (1..31, clamped to
/// the month length).
CalDate nextSipDate(int day, CalDate today) {
  CalDate inMonth(int y, int m) {
    final last = DateTime.utc(y, m + 1, 0).day;
    return CalDate(y, m, day > last ? last : day);
  }

  final thisMonth = inMonth(today.year, today.month);
  if (thisMonth >= today) return thisMonth;
  final m = today.month == 12 ? 1 : today.month + 1;
  final y = today.month == 12 ? today.year + 1 : today.year;
  return inMonth(y, m);
}

// ---- reminders ------------------------------------------------------------------

enum DueStatus { overdue, dueSoon, upcoming }

/// overdue (past), dueSoon (within [soonDays]), else upcoming.
DueStatus dueStatus(CalDate due, CalDate today, {int soonDays = 30}) {
  final d = due.daysSince(today);
  if (d < 0) return DueStatus.overdue;
  return d <= soonDays ? DueStatus.dueSoon : DueStatus.upcoming;
}

/// When to fire the reminder: 09:00 local on (due date - [daysBefore]).
/// Null when that moment has passed (nothing to schedule).
DateTime? reminderTime(CalDate due, int daysBefore, DateTime now) {
  final day = due.addDays(-daysBefore);
  final at = DateTime(day.year, day.month, day.day, 9);
  return at.isAfter(now) ? at : null;
}

/// "in 12 days", "today", "3 days ago".
String dueText(CalDate due, CalDate today) {
  final d = due.daysSince(today);
  if (d == 0) return 'today';
  if (d == 1) return 'tomorrow';
  if (d == -1) return 'yesterday';
  if (d > 0) return d < 90 ? 'in $d days' : 'in ${(d / 30).round()} months';
  return '${-d} days ago';
}

/// Stable notification id for a document id (positive 31-bit).
int notificationIdFor(String id) {
  var h = 0;
  for (final u in id.codeUnits) {
    h = (h * 31 + u) & 0x3fffffff;
  }
  return h;
}
