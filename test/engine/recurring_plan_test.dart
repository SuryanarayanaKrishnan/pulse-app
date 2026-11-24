import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/recurring.dart';
import 'package:pulse/core/engine/recurring_plan.dart';

const _today = CalDate(2026, 11, 14);

Charge c(CalDate d, int minor, String key) => Charge(d, minor, key.toUpperCase(), key, 'entertainment');

List<Charge> monthly(String key, int day, int amount, {int n = 5, int lastMonth = 11}) => [
  for (var i = n - 1; i >= 0; i--)
    () {
      final idx = 2026 * 12 + lastMonth - 1 - i;
      return c(CalDate(idx ~/ 12, idx % 12 + 1, day), amount, key);
    }(),
];

RecurringMonth plan(
  List<Charge> charges, {
  Map<String, RecChoice> choices = const {},
  List<CardDueInput> cards = const [],
  List<BillInput> bills = const [],
  CalDate? day,
}) => planMonth(
  series: detect(charges, _today),
  charges: charges,
  today: _today,
  anyDay: day,
  choices: choices,
  cardDues: cards,
  bills: bills,
);

void main() {
  // Paid on the 3rd (this month), due on the 20th, expected on the 10th but
  // not seen (overdue, within the grace window).
  final ledger = [
    ...monthly('paid co', 3, 5000),
    ...monthly('later co', 20, 12000, lastMonth: 10),
    ...monthly('late co', 10, 3000, lastMonth: 10),
  ];

  test('groups a month into paid, upcoming and overdue', () {
    final m = plan(ledger);
    expect([for (final i in m.paid) i.title], ['PAID CO']);
    expect([for (final i in m.upcoming) i.title], ['LATER CO']);
    expect([for (final i in m.overdue) i.title], ['LATE CO']);
    expect(m.paid.single.dueOn, const CalDate(2026, 11, 3));
    expect(m.upcoming.single.dueOn, const CalDate(2026, 11, 20));
    expect(m.overdue.single.dueOn, const CalDate(2026, 11, 10));
  });

  test('committed this month is paid plus still to come', () {
    final m = plan(ledger);
    expect(m.paidMinor, 5000);
    expect(m.leftMinor, 15000);
    expect(m.committedMinor, 20000);
  });

  test('ignoring a series removes it everywhere; confirming marks it', () {
    final m = plan(ledger, choices: {'later co': RecChoice.ignored, 'paid co': RecChoice.confirmed});
    expect(m.upcoming, isEmpty);
    expect(m.committedMinor, 8000);
    expect(m.paid.single.confirmed, isTrue);
    expect(m.overdue.single.confirmed, isFalse);
  });

  test('a stopped series sits in lapsed and in no total', () {
    final m = plan([...ledger, ...monthly('gone co', 8, 9900, lastMonth: 6)]);
    expect(m.lapsed.map((s) => s.key), ['gone co']);
    expect(m.committedMinor, 20000);
  });

  test('weekly series show every date left in the month, past ones as paid', () {
    final weekly = [for (var i = 0; i < 8; i++) c(const CalDate(2026, 9, 21).addDays(7 * i), 1500, 'weekly co')];
    // Charges: Sep 21 ... Nov 2, Nov 9; next Nov 16, 23, 30.
    final m = plan(weekly);
    expect(m.paid.map((i) => i.dueOn.day), [2, 9]);
    expect(m.upcoming.map((i) => i.dueOn.day), [16, 23, 30]);
    expect(m.committedMinor, 1500 * 5);
  });

  test('the calendar maps days to items', () {
    final m = plan(ledger);
    final by = m.byDay;
    expect(by.keys.toList()..sort(), [3, 10, 20]);
    expect(by[20]!.single.state, RecState.upcoming);
  });

  test('a past month shows what was paid, no overdue and no upcoming', () {
    final m = plan(ledger, day: const CalDate(2026, 10, 1));
    expect(m.upcoming, isEmpty);
    expect(m.overdue, isEmpty);
    expect(m.paid.map((i) => i.title).toSet(), {'PAID CO', 'LATER CO', 'LATE CO'});
  });

  test('a future month projects upcoming items', () {
    final m = plan(ledger, day: const CalDate(2026, 12, 1));
    expect(m.paid, isEmpty);
    expect(m.upcoming.map((i) => i.dueOn.day).toList(), [3, 10, 20]);
  });

  test('card dues and household bills join the calendar; earlier bill days are not guessed', () {
    final m = plan(
      ledger,
      cards: [CardDueInput('c1', 'Gold card', const CalDate(2026, 11, 25), 80000), CardDueInput('c2', 'Old card', const CalDate(2026, 11, 8), 12000)],
      bills: const [BillInput('b1', 'Internet', 28, 35000), BillInput('b2', 'Cleaner', 2, 20000)],
    );
    final titles = {for (final i in m.items) i.title: i};
    expect(titles['Gold card']!.state, RecState.upcoming);
    expect(titles['Gold card']!.kind, RecKind.cardDue);
    expect(titles['Old card']!.state, RecState.overdue);
    expect(titles['Internet']!.kind, RecKind.bill);
    expect(titles['Internet']!.dueOn, const CalDate(2026, 11, 28));
    expect(titles.containsKey('Cleaner'), isFalse);
    expect(m.committedMinor, 20000 + 80000 + 12000 + 35000);
  });

  test('a bill already detected from the ledger is shown once', () {
    final m = plan(ledger, bills: const [BillInput('b1', 'Later Co', 20, 12000)]);
    expect(m.items.where((i) => i.title.toLowerCase() == 'later co'), hasLength(1));
  });

  test('price rises become hints, biggest yearly cost first, and ignored ones drop out', () {
    final up = [...monthly('tv plus', 6, 4000, n: 4, lastMonth: 10), c(const CalDate(2026, 11, 6), 5000, 'tv plus')];
    final up2 = [...monthly('big co', 8, 20000, n: 4, lastMonth: 10), c(const CalDate(2026, 11, 8), 22000, 'big co')];
    final m = plan([...up, ...up2]);
    expect(m.hints.map((h) => h.series.key), ['big co', 'tv plus']);
    expect(m.hints.first.yearlyExtraMinor, 2000 * 12);
    final hidden = plan([...up, ...up2], choices: {'big co': RecChoice.ignored});
    expect(hidden.hints.map((h) => h.series.key), ['tv plus']);
  });

  test('history of a series lists its charges newest first', () {
    final s = detect(ledger, _today).firstWhere((s) => s.key == 'paid co');
    final h = historyOf(s, ledger);
    expect(h.first.postedOn, const CalDate(2026, 11, 3));
    expect(h, hasLength(5));
  });

  test('an amount tier only shows its own charges', () {
    final ch = [
      for (var i = 0; i < 5; i++) ...[
        c(addMonths(const CalDate(2026, 7, 5), i), 2000, 'bill co'),
        c(addMonths(const CalDate(2026, 6, 20), i), 9000, 'bill co'),
      ],
    ];
    final series = detect(ch, _today);
    final low = series.firstWhere((s) => s.key == 'bill co#20');
    expect(historyOf(low, ch).map((c) => c.amountMinor).toSet(), {2000});
    final m = planMonth(series: series, charges: ch, today: _today);
    expect(m.paid.map((i) => i.amountMinor).toList()..sort(), [2000]);
    expect(m.upcoming.map((i) => i.amountMinor).toList()..sort(), [9000]);
  });
}
