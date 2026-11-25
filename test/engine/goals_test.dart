import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/goals.dart';

const today = CalDate(2026, 11, 24);
const created = CalDate(2026, 5, 1);

GoalInput save({
  int target = 1200000,
  int start = 0,
  int? linked,
  CalDate? date,
  int? monthly,
  bool paused = false,
  List<ContributionPoint> c = const [],
  String id = 'g',
}) => GoalInput(
  id: id,
  name: 'Goal $id',
  kind: GoalKind.save,
  targetMinor: target,
  startMinor: start,
  linkedMinor: linked,
  targetDate: date,
  plannedMonthlyMinor: monthly,
  paused: paused,
  createdOn: created,
  contributions: c,
);

GoalInput paydown({int owed = 900000, int? linked, CalDate? date, int? monthly, List<ContributionPoint> c = const []}) => GoalInput(
  id: 'p',
  name: 'Card',
  kind: GoalKind.paydown,
  targetMinor: 0,
  startMinor: owed,
  linkedMinor: linked,
  targetDate: date,
  plannedMonthlyMinor: monthly,
  createdOn: created,
  contributions: c,
);

ContributionPoint pt(int daysAgo, int amount) => ContributionPoint(today.addDays(-daysAgo), amount);

void main() {
  group('state', () {
    test('save: start plus contributions, withdrawals subtract', () {
      final s = goalState(save(start: 100000, c: [pt(40, 300000), pt(10, -50000)]));
      expect(s.currentMinor, 350000);
      expect(s.remainingMinor, 850000);
      expect(s.progress, closeTo(350000 / 1200000, 1e-9));
      expect(s.done, isFalse);
    });

    test('save reaches its target', () {
      final s = goalState(save(target: 100000, c: [pt(3, 100000)]));
      expect(s.done, isTrue);
      expect(s.progress, 1);
      expect(s.remainingMinor, 0);
    });

    test('a linked goal reads the linked value, not contributions', () {
      expect(goalState(save(linked: 600000, start: 1, c: [pt(3, 999)])).currentMinor, 600000);
    });

    test('paydown: owed falls with payments; progress is the share paid', () {
      final s = goalState(paydown(c: [pt(20, 100000), pt(5, 200000)]));
      expect(s.currentMinor, 600000);
      expect(s.remainingMinor, 600000);
      expect(s.progress, closeTo(1 / 3, 1e-9));
      expect(s.done, isFalse);
    });

    test('paydown linked to a liability follows its balance, done at zero', () {
      expect(goalState(paydown(linked: 450000)).progress, closeTo(0.5, 1e-9));
      expect(goalState(paydown(linked: 0)).done, isTrue);
    });

    test('paying more than owed clamps at done', () {
      final s = goalState(paydown(c: [pt(2, 1000000)]));
      expect(s.done, isTrue);
      expect(s.progress, 1);
    });
  });

  group('plan and suggestion', () {
    test('suggested is remaining over months left, rounded up', () {
      final g = save(target: 1000000, date: CalDate(2027, 5, 24));
      expect(suggestedMonthly(g, today), (1000000 / 6).ceil());
    });

    test('no date means no suggestion; the planned figure wins when set', () {
      expect(suggestedMonthly(save(), today), isNull);
      expect(plannedMonthly(save(monthly: 50000, date: CalDate(2027, 5, 24)), today), 50000);
      expect(plannedMonthly(save(), today), 0);
    });

    test('the plan never exceeds what is left', () {
      expect(plannedMonthly(save(target: 100000, start: 80000, monthly: 500000), today), 20000);
    });
  });

  group('pace and projection', () {
    test('recent pace averages the last three months', () {
      final g = save(c: [pt(80, 300000), pt(45, 300000), pt(10, 300000)]);
      expect(recentPaceMinor(g, today), 300000);
    });

    test('contributions older than 90 days are ignored', () {
      expect(recentPaceMinor(save(c: [pt(120, 500000)]), today), isNull);
    });

    test('projects completion from the recent pace', () {
      // 900k in over three months (300k a month) of 1.2m: 300k left -> one month.
      final g = save(c: [pt(80, 300000), pt(45, 300000), pt(10, 300000)]);
      expect(projectedCompletion(g, today), const CalDate(2026, 12, 24));
    });

    test('falls back to the plan when nothing was added yet', () {
      final g = save(target: 600000, monthly: 100000);
      expect(projectedCompletion(g, today), const CalDate(2027, 5, 24));
    });

    test('addMonths clamps to the end of a short month', () {
      expect(addMonths(const CalDate(2026, 1, 31), 1), const CalDate(2026, 2, 28));
    });

    test('done goals have no projection', () {
      expect(projectedCompletion(save(target: 10, start: 10), today), isNull);
    });

    test('paydown projects from payments', () {
      final g = paydown(c: [pt(70, 100000), pt(40, 100000), pt(10, 100000)]);
      // 900k - 300k = 600k left at 100k a month
      expect(projectedCompletion(g, today), const CalDate(2027, 5, 24));
    });
  });

  group('pace wording', () {
    final deadline = CalDate(2027, 5, 24); // 6 months

    test('on track when the pace finishes by the date', () {
      final g = save(date: deadline, c: [pt(80, 300000), pt(45, 300000), pt(10, 300000)]);
      expect(goalPace(g, today), GoalPace.onTrack);
    });

    test('a little behind when it would finish after', () {
      final g = save(target: 6000000, date: deadline, c: [pt(10, 100000)]);
      expect(goalPace(g, today), GoalPace.behind);
    });

    test('paused, done, no date, nothing yet', () {
      expect(goalPace(save(paused: true, monthly: 1000), today), GoalPace.paused);
      expect(goalPace(save(target: 5, start: 5), today), GoalPace.done);
      expect(goalPace(save(c: [pt(5, 1000)]), today), GoalPace.noDeadline);
      expect(goalPace(save(), today), GoalPace.noPace);
      // with a date the plan is the suggestion, so there is a pace to project
      expect(goalPace(save(date: deadline), today), GoalPace.onTrack);
    });
  });

  group('safe-to-spend reservation', () {
    final date = CalDate(2027, 5, 24);

    test('each active goal reserves its monthly plan', () {
      final r = goalReservations([
        save(id: 'a', monthly: 100000),
        save(id: 'b', target: 600000, date: date),
      ], today);
      expect({for (final e in r) e.goalId: e.amountMinor}, {'a': 100000, 'b': 100000});
      expect(totalReserved(r), 200000);
    });

    test('a paused goal reserves nothing, and resuming brings it back', () {
      final paused = save(id: 'a', monthly: 100000, paused: true);
      expect(goalReservations([paused], today), isEmpty);
      expect(totalReserved(goalReservations([save(id: 'a', monthly: 100000)], today)), 100000);
    });

    test('a finished goal reserves nothing', () {
      expect(goalReservations([save(target: 100, start: 100, monthly: 50)], today), isEmpty);
    });

    test('money already put in this month reduces the reservation', () {
      final g = save(monthly: 100000, c: [pt(3, 40000)]); // 21 Nov, this month
      expect(totalReserved(goalReservations([g], today)), 60000);
      final full = save(monthly: 100000, c: [pt(3, 150000)]);
      expect(goalReservations([full], today), isEmpty);
    });

    test('contributions from last month do not count against this month', () {
      expect(totalReserved(goalReservations([save(monthly: 100000, c: [pt(30, 100000)])], today)), 100000);
    });

    test('paydown reserves its monthly payment, capped at what is owed', () {
      expect(totalReserved(goalReservations([paydown(monthly: 100000)], today)), 100000);
      expect(totalReserved(goalReservations([paydown(owed: 30000, monthly: 100000)], today)), 30000);
      expect(goalReservations([paydown(linked: 0, monthly: 100000)], today), isEmpty);
    });
  });
}
