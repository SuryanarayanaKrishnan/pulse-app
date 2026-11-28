/// What the Recurring screen shows, worked out from detected series. Pure and
/// deterministic: the same ledger, choices and date give the same month.
///
/// A month is a list of [RecItem]s, each one expected or seen payment:
/// paid (a charge landed this month), upcoming (expected from today on) or
/// overdue (expected earlier, not seen yet). Card dues and household bills
/// join the same list so the calendar shows every date money leaves.
library;

import 'dates.dart';
import 'recurring.dart';
import 'rewards.dart' show daysInMonth;
import 'types.dart';

/// What the user told us about a detected series.
enum RecChoice {
  confirmed,
  ignored;

  static RecChoice? tryParse(String? s) => switch (s) {
    'confirmed' => RecChoice.confirmed,
    'ignored' => RecChoice.ignored,
    _ => null,
  };
}

enum RecState { paid, upcoming, overdue }

/// Where an item comes from.
enum RecKind { subscription, payment, cardDue, bill }

/// A card with something to pay (for the calendar only).
class CardDueInput {
  const CardDueInput(this.id, this.name, this.dueOn, this.amountMinor);
  final String id, name;
  final CalDate dueOn;
  final int amountMinor;
}

/// A household bill (monthly, on [dueDay]); [amountMinor] is what I owe.
class BillInput {
  const BillInput(this.id, this.name, this.dueDay, this.amountMinor);
  final String id, name;
  final int dueDay, amountMinor;
}

class RecItem {
  const RecItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.state,
    required this.dueOn,
    required this.amountMinor,
    this.series,
    this.confirmed = false,
  });

  /// Series key, `card:<id>` or `bill:<id>`.
  final String id;
  final String title;
  final RecKind kind;
  final RecState state;

  /// The day it was paid (paid), or is expected (upcoming, overdue).
  final CalDate dueOn;
  final int amountMinor;

  /// The detected series behind it; null for card dues and bills.
  final Series? series;
  final bool confirmed;

  bool get isDetected => series != null;
}

/// A subscription whose price went up.
class PriceHint {
  const PriceHint(this.series, this.yearlyExtraMinor);
  final Series series;

  /// What the rise costs over a year at the series' cadence.
  final int yearlyExtraMinor;
  PriceIncrease get change => series.priceIncrease!;
}

class RecurringMonth {
  const RecurringMonth({
    required this.month,
    required this.items,
    required this.hints,
    required this.lapsed,
  });

  /// First day of the month shown.
  final CalDate month;

  /// All items of the month, by date.
  final List<RecItem> items;
  final List<PriceHint> hints;

  /// Detected series that stopped charging (kept out of every total).
  final List<Series> lapsed;

  List<RecItem> _by(RecState s) => [
    for (final i in items)
      if (i.state == s) i,
  ];
  List<RecItem> get paid => _by(RecState.paid);
  List<RecItem> get upcoming => _by(RecState.upcoming);
  List<RecItem> get overdue => _by(RecState.overdue);

  static int _sum(Iterable<RecItem> l) =>
      l.fold(0, (a, i) => a + i.amountMinor);

  /// Everything that leaves this month: paid, still to come, and late.
  int get committedMinor => _sum(items);
  int get paidMinor => _sum(paid);
  int get leftMinor => _sum(upcoming) + _sum(overdue);

  /// Items by day of month, for the calendar dots.
  Map<int, List<RecItem>> get byDay {
    final m = <int, List<RecItem>>{};
    for (final i in items) {
      if (i.dueOn.year == month.year && i.dueOn.month == month.month)
        (m[i.dueOn.day] ??= []).add(i);
    }
    return m;
  }
}

CalDate monthStart(CalDate d) => CalDate(d.year, d.month, 1);
CalDate monthEnd(CalDate d) =>
    CalDate(d.year, d.month, daysInMonth(d.year, d.month));

/// Expected dates of [s] in [start]..[end], counting from its next expected
/// date. Unlike [occurrencesBetween] an overdue date keeps its own day.
List<CalDate> _expected(Series s, CalDate start, CalDate end) {
  final out = <CalDate>[];
  var d = s.nextExpectedOn;
  var guard = 0;
  while (d <= end && guard++ < 400) {
    if (d >= start) out.add(d);
    d = advance(d, s.cadence, s.anchorDay);
  }
  return out;
}

/// The month of [anyDay] for the user: paid, upcoming and overdue items.
///
/// [charges] is the whole ledger as [detect] saw it; [choices] maps series
/// keys to the user's verdict. An ignored series disappears; a confirmed one
/// is marked so. [cardDues] and [bills] are added as they are.
RecurringMonth planMonth({
  required List<Series> series,
  required List<Charge> charges,
  required CalDate today,
  CalDate? anyDay,
  Map<String, RecChoice> choices = const {},
  List<CardDueInput> cardDues = const [],
  List<BillInput> bills = const [],
}) {
  final month = monthStart(anyDay ?? today);
  final end = monthEnd(month);
  final isCurrent = month == monthStart(today);
  final items = <RecItem>[];
  final hints = <PriceHint>[];
  final lapsed = <Series>[];
  final byKey = <String, List<Charge>>{};
  for (final c in charges) {
    if (c.amountMinor > 0) (byKey[c.key] ??= []).add(c);
  }

  for (final s in series) {
    final choice = choices[s.key];
    if (choice == RecChoice.ignored) continue;
    if (s.status == 'lapsed') {
      lapsed.add(s);
      continue;
    }
    final confirmed = choice == RecChoice.confirmed;
    RecItem item(RecState st, CalDate on, int amount) => RecItem(
      id: s.key,
      title: s.merchant,
      kind: s.isSubscription ? RecKind.subscription : RecKind.payment,
      state: st,
      dueOn: on,
      amountMinor: amount,
      series: s,
      confirmed: confirmed,
    );
    // Paid: charges that landed in the month (one per day, split payments
    // summed), for tier series only the ones that belong to the tier.
    final seen = <CalDate, int>{};
    for (final c in byKey[s.key.split('#').first] ?? const <Charge>[]) {
      if (c.postedOn < month || c.postedOn > end) continue;
      if (s.key.contains('#') && !_inTier(s, c.amountMinor)) continue;
      seen[c.postedOn] = (seen[c.postedOn] ?? 0) + c.amountMinor;
    }
    for (final e in seen.entries) {
      items.add(item(RecState.paid, e.key, e.value));
    }
    for (final d in _expected(s, month, end)) {
      if (d >= today) {
        items.add(item(RecState.upcoming, d, s.typicalAmountMinor));
      } else if (isCurrent && s.status == 'due') {
        items.add(item(RecState.overdue, d, s.typicalAmountMinor));
      }
    }
    // A due series whose expected date sits before this month still counts
    // as overdue in the current month (the grace window can cross a month).
    if (isCurrent && s.status == 'due' && s.nextExpectedOn < month) {
      items.add(item(RecState.overdue, s.nextExpectedOn, s.typicalAmountMinor));
    }
    if (s.priceIncrease != null) {
      hints.add(
        PriceHint(s, s.priceIncrease!.increaseMinor * _perYear(s.cadence)),
      );
    }
  }

  for (final c in cardDues) {
    if (c.amountMinor <= 0 || c.dueOn < month || c.dueOn > end) continue;
    items.add(
      RecItem(
        id: 'card:${c.id}',
        title: c.name,
        kind: RecKind.cardDue,
        state: c.dueOn >= today ? RecState.upcoming : RecState.overdue,
        dueOn: c.dueOn,
        amountMinor: c.amountMinor,
      ),
    );
  }
  for (final b in bills) {
    // A bill the detector already found (rent paid by card, say) is shown
    // once, as the detected series.
    final n = b.name.trim().toLowerCase();
    if (n.isNotEmpty &&
        series.any(
          (s) =>
              choices[s.key] != RecChoice.ignored &&
              (s.key.contains(n) || n.contains(s.key.split('#').first)),
        )) {
      continue;
    }
    final day = b.dueDay.clamp(1, daysInMonth(month.year, month.month));
    final on = CalDate(month.year, month.month, day);
    // Earlier days of the current month are not shown: we cannot tell
    // whether the bill was settled.
    if (on < today) continue;
    items.add(
      RecItem(
        id: 'bill:${b.id}',
        title: b.name,
        kind: RecKind.bill,
        state: RecState.upcoming,
        dueOn: on,
        amountMinor: b.amountMinor,
      ),
    );
  }

  hints.sort((a, b) => b.yearlyExtraMinor.compareTo(a.yearlyExtraMinor));
  final sorted = stableSorted(items, (a, b) {
    final c = a.dueOn.compareTo(b.dueOn);
    return c != 0 ? c : a.title.compareTo(b.title);
  });
  return RecurringMonth(
    month: month,
    items: sorted,
    hints: hints,
    lapsed: lapsed,
  );
}

bool _inTier(Series s, int amountMinor) {
  final ref = s.typicalAmountMinor;
  return (amountMinor - ref).abs() <= ref * (fixedTolerance * 3);
}

int _perYear(String cadence) => switch (cadence) {
  'weekly' => 52,
  'fortnightly' => 26,
  'monthly' => 12,
  'quarterly' => 4,
  _ => 1,
};

/// Past charges of a series, newest first (for the detail sheet).
List<Charge> historyOf(Series s, List<Charge> charges) {
  final base = s.key.split('#').first;
  final out = [
    for (final c in charges)
      if (c.key == base &&
          c.amountMinor > 0 &&
          (!s.key.contains('#') || _inTier(s, c.amountMinor)))
        c,
  ];
  out.sort((a, b) => b.postedOn.compareTo(a.postedOn));
  return out;
}
