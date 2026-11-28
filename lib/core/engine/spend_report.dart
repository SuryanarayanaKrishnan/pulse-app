/// Spending reports: by category and by household member over a date range.
/// Pure. Inputs are plain rows so the same code serves the ledger and the
/// household's shared log.
library;

import 'dates.dart';
import 'types.dart';

/// One payment, already filtered to what counts as spend by the caller's
/// category rules (transfers and card payments are not spend).
class SpendRow {
  const SpendRow({
    required this.date,
    required this.amountMinor,
    required this.categoryId,
    this.owner,
    this.merchant = '',
  });
  final CalDate date;

  /// Positive; refunds are passed as negative.
  final int amountMinor;
  final String categoryId;

  /// Member id for household reports; null outside a household.
  final String? owner;
  final String merchant;
}

/// A reporting window: whole months, ending with [end]'s month.
class ReportRange {
  const ReportRange(this.start, this.end);
  final CalDate start, end;

  bool contains(CalDate d) => d >= start && d <= end;

  /// The month of [anyDay].
  factory ReportRange.month(CalDate anyDay) => ReportRange(
    CalDate(anyDay.year, anyDay.month, 1),
    CalDate(anyDay.year, anyDay.month + 1, 1).addDays(-1),
  );

  /// The last [months] whole months up to and including [anyDay]'s month.
  factory ReportRange.lastMonths(CalDate anyDay, int months) {
    final idx = anyDay.year * 12 + anyDay.month - 1 - (months - 1);
    return ReportRange(
      CalDate(idx ~/ 12, idx % 12 + 1, 1),
      CalDate(anyDay.year, anyDay.month + 1, 1).addDays(-1),
    );
  }

  /// The same number of whole months immediately before this range.
  ReportRange get previous {
    final months =
        (end.year * 12 + end.month) - (start.year * 12 + start.month) + 1;
    final idx = start.year * 12 + start.month - 1 - months;
    return ReportRange(CalDate(idx ~/ 12, idx % 12 + 1, 1), start.addDays(-1));
  }
}

class SpendSlice {
  const SpendSlice(this.id, this.totalMinor, this.count);
  final String id;
  final int totalMinor, count;
}

/// Totals per key (category or owner) in [range], largest first. Slices that
/// net to zero or less are left out.
List<SpendSlice> spendBy(
  Iterable<SpendRow> rows,
  ReportRange range,
  String Function(SpendRow) keyOf,
) {
  final sums = <String, int>{}, counts = <String, int>{};
  for (final r in rows) {
    if (!range.contains(r.date)) continue;
    final k = keyOf(r);
    sums[k] = (sums[k] ?? 0) + r.amountMinor;
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final out = [
    for (final e in sums.entries)
      if (e.value > 0) SpendSlice(e.key, e.value, counts[e.key]!),
  ];
  return stableSorted(out, (a, b) {
    final c = b.totalMinor.compareTo(a.totalMinor);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
}

List<SpendSlice> spendByCategory(Iterable<SpendRow> rows, ReportRange range) =>
    spendBy(rows, range, (r) => r.categoryId);

List<SpendSlice> spendByOwner(Iterable<SpendRow> rows, ReportRange range) =>
    spendBy(rows, range, (r) => r.owner ?? 'me');

/// Small categories folded into one "Other" slice so a treemap stays
/// readable: keep the top [keep] and any slice above [minShare] of the total.
List<SpendSlice> foldSmall(
  List<SpendSlice> slices, {
  int keep = 8,
  double minShare = 0.03,
  String otherId = 'other',
}) {
  final total = slices.fold(0, (a, s) => a + s.totalMinor);
  if (total == 0) return slices;
  final kept = <SpendSlice>[];
  var restTotal = 0, restCount = 0;
  for (final (i, s) in slices.indexed) {
    if (i < keep && s.totalMinor / total >= minShare) {
      kept.add(s);
    } else {
      restTotal += s.totalMinor;
      restCount += s.count;
    }
  }
  if (restTotal > 0) {
    final i = kept.indexWhere((s) => s.id == otherId);
    if (i >= 0) {
      kept[i] = SpendSlice(
        otherId,
        kept[i].totalMinor + restTotal,
        kept[i].count + restCount,
      );
    } else {
      kept.add(SpendSlice(otherId, restTotal, restCount));
    }
  }
  return stableSorted(kept, (a, b) => b.totalMinor.compareTo(a.totalMinor));
}

/// Months offered by the range chips.
enum ReportSpan {
  month('Month', 1),
  m3('3M', 3),
  m6('6M', 6),
  y1('1Y', 12);

  const ReportSpan(this.label, this.months);
  final String label;
  final int months;
}
