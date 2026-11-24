/// Net worth over time: range windows, the change across a window, a backfill
/// of the days before the first stored snapshot, and chart-sized sampling.
/// Pure and deterministic.
library;

import 'dates.dart';
import 'types.dart';

/// One day of net worth. All minor units, liabilities positive.
class NwPoint {
  const NwPoint(this.date, this.assetsMinor, this.liabilitiesMinor, {this.estimated = false});
  final CalDate date;
  final int assetsMinor, liabilitiesMinor;

  /// Rebuilt from transactions, not stored on the day.
  final bool estimated;
  int get netMinor => assetsMinor - liabilitiesMinor;

  @override
  bool operator ==(Object other) =>
      other is NwPoint &&
      other.date == date &&
      other.assetsMinor == assetsMinor &&
      other.liabilitiesMinor == liabilitiesMinor &&
      other.estimated == estimated;
  @override
  int get hashCode => Object.hash(date, assetsMinor, liabilitiesMinor, estimated);
}

enum NwRange {
  m1('1M', 30),
  m3('3M', 91),
  m6('6M', 182),
  y1('1Y', 365),
  all('All', null);

  const NwRange(this.label, this.days);
  final String label;

  /// Window length in days; null: everything.
  final int? days;
}

/// The points inside [range] ending at [today], oldest first. When history
/// reaches back further than the window starts, the value held at the start
/// is carried in as the first point so the line spans the whole window.
List<NwPoint> pointsFor(List<NwPoint> all, NwRange range, CalDate today) {
  final sorted = stableSorted(all, (a, b) => a.date.compareTo(b.date));
  final days = range.days;
  if (days == null || sorted.isEmpty) return sorted;
  final start = today.addDays(-days);
  final inside = [for (final p in sorted) if (p.date >= start && p.date <= today) p];
  final before = sorted.where((p) => p.date < start).lastOrNull;
  if (before != null) {
    inside.insert(0, NwPoint(start, before.assetsMinor, before.liabilitiesMinor, estimated: before.estimated));
  }
  return inside;
}

/// Change across a window: first to last point.
class NwChange {
  const NwChange(this.deltaMinor, this.pct);
  final int deltaMinor;

  /// Percent of the starting value's size; 0 when it started at zero.
  final double pct;
}

NwChange changeOver(List<NwPoint> pts) {
  if (pts.length < 2) return const NwChange(0, 0);
  final from = pts.first.netMinor, to = pts.last.netMinor;
  final d = to - from;
  return NwChange(d, from == 0 ? 0 : d / from.abs() * 100);
}

/// At most [max] points, always keeping the first and the last. Evenly
/// spaced by index, so sparse and dense stretches both survive.
List<NwPoint> sample(List<NwPoint> pts, int max) {
  if (max < 2 || pts.length <= max) return pts;
  final out = <NwPoint>[];
  for (var i = 0; i < max; i++) {
    out.add(pts[(i * (pts.length - 1) / (max - 1)).round()]);
  }
  return out;
}

/// Money moving through one account on one day (credits +, debits -).
class NwFlow {
  const NwFlow(this.date, this.signedMinor, {required this.isCard});
  final CalDate date;
  final int signedMinor;

  /// A credit card account (its flows move liabilities); else cash-like
  /// (its flows move assets).
  final bool isCard;
}

/// Daily points for the days before [firstSnapshot] (or before today when
/// there is none), rebuilt by taking every later transaction back out of
/// today's [assetsNowMinor] and [liabilitiesNowMinor]. Property, gold and
/// other manually valued things are held at today's value. At most
/// [maxDays] days back, and never earlier than the first flow.
List<NwPoint> backfill({
  required int assetsNowMinor,
  required int liabilitiesNowMinor,
  required List<NwFlow> flows,
  required CalDate today,
  CalDate? firstSnapshot,
  int maxDays = 365,
}) {
  if (flows.isEmpty) return const [];
  final stop = (firstSnapshot ?? today).addDays(-1);
  var earliest = flows.map((f) => f.date).reduce((a, b) => a < b ? a : b);
  final limit = today.addDays(-maxDays);
  if (earliest < limit) earliest = limit;
  if (earliest > stop) return const [];

  // Net flow per day and side, then walk from today back.
  final cash = <CalDate, int>{}, card = <CalDate, int>{};
  for (final f in flows) {
    final m = f.isCard ? card : cash;
    m[f.date] = (m[f.date] ?? 0) + f.signedMinor;
  }
  // S(d) is the position at the end of day d: S(today) is now and
  // S(d - 1) = S(d) minus day d's flows.
  var assets = assetsNowMinor, liabilities = liabilitiesNowMinor;
  final out = <NwPoint>[];
  for (var d = today; d >= earliest; d = d.addDays(-1)) {
    assets -= cash[d] ?? 0;
    liabilities += card[d] ?? 0;
    final prev = d.addDays(-1);
    if (prev <= stop && prev >= limit) {
      out.add(NwPoint(prev, assets, liabilities < 0 ? 0 : liabilities, estimated: true));
    }
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

/// Share of [part] in [whole] as a fraction 0..1 (0 when whole is 0).
double share(int part, int whole) => whole <= 0 ? 0 : (part / whole).clamp(0, 1).toDouble();
