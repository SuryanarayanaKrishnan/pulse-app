import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/household/household_engine.dart';
import 'package:pulse/core/household/household_models.dart';

const me = 'aaaa';
const sam = 'bbbb';

HLine line(
  String id,
  String owner,
  int value, {
  bool liability = false,
  bool priv = false,
  String cur = 'AED',
}) => HLine(
  id: id,
  name: id,
  isLiability: liability,
  valueMinor: value,
  owner: owner,
  isPrivate: priv,
  currency: cur,
);

HTx tx(
  String id,
  String owner,
  int amount, {
  String cat = 'groceries',
  bool priv = false,
  int day = 10,
  bool debit = true,
  bool excl = false,
  int month = 11,
}) => HTx(
  id: id,
  owner: owner,
  isPrivate: priv,
  categoryId: cat,
  amountMinor: amount,
  isDebit: debit,
  excluded: excl,
  postedAt: DateTime.utc(2026, month, day),
);

void main() {
  group('joint net worth', () {
    final lines = [
      line('my-cash', me, 10000000),
      line('my-secret', me, 5000000, priv: true),
      line('sam-cash', sam, 20000000),
      line('home', Owner.shared, 80000000),
      line('mortgage', Owner.shared, 50000000, liability: true),
      line('my-card', me, 200000, liability: true),
    ];

    test(
      'joint is shared plus both members non-private items, never private',
      () {
        final j = householdNetWorth(
          lines,
          scope: NwScope.joint,
          me: me,
          memberIds: [me, sam],
        );
        expect(j.assetsMinor, 10000000 + 20000000 + 80000000);
        expect(j.liabilitiesMinor, 50000000 + 200000);
        expect(j.netMinor, 110000000 - 50200000);
        expect(j.lineCount, 5, reason: 'the private line is not counted');
      },
    );

    test('mine is my items (private included) plus my half of shared', () {
      final m = householdNetWorth(
        lines,
        scope: NwScope.mine,
        me: me,
        memberIds: [me, sam],
      );
      expect(m.assetsMinor, 10000000 + 5000000 + 40000000);
      expect(m.liabilitiesMinor, 25000000 + 200000);
    });

    test('an odd shared amount loses no money across the members', () {
      final odd = [line('x', Owner.shared, 10001)];
      final a = householdNetWorth(
        odd,
        scope: NwScope.mine,
        me: me,
        memberIds: [me, sam],
      ).assetsMinor;
      final b = householdNetWorth(
        odd,
        scope: NwScope.mine,
        me: sam,
        memberIds: [me, sam],
      ).assetsMinor;
      expect(a + b, 10001);
    });

    test('with sharing of mine off, my items leave the joint number', () {
      final j = householdNetWorth(
        lines,
        scope: NwScope.joint,
        me: me,
        memberIds: [me, sam],
        shareMine: false,
      );
      expect(j.assetsMinor, 20000000 + 80000000);
      expect(j.liabilitiesMinor, 50000000);
    });

    test('both phones agree on the joint number', () {
      // Sam sees my non-private lines through the mirror, never my private one.
      final samsView = [
        for (final l in lines)
          if (!l.isPrivate) l,
      ];
      final mine = householdNetWorth(
        lines,
        scope: NwScope.joint,
        me: me,
        memberIds: [me, sam],
      );
      final theirs = householdNetWorth(
        samsView,
        scope: NwScope.joint,
        me: sam,
        memberIds: [me, sam],
      );
      expect(theirs.netMinor, mine.netMinor);
    });

    test('per-owner breakdown, shared first', () {
      final j = householdNetWorth(
        lines,
        scope: NwScope.joint,
        me: me,
        memberIds: [me, sam],
      );
      expect([for (final o in j.byOwner) o.owner], [Owner.shared, me, sam]);
      expect(j.byOwner.first.netMinor, 30000000);
    });

    test('a currency without a rate is reported, not summed', () {
      final j = householdNetWorth(
        [line('usd', me, 100, cur: 'USD')],
        scope: NwScope.joint,
        me: me,
        memberIds: [me],
      );
      expect(j.assetsMinor, 0);
      expect(j.unconverted, ['USD']);
    });
  });

  group('spending by member', () {
    final from = DateTime.utc(2026, 11, 1), to = DateTime.utc(2026, 12, 1);
    test('groups by owner, biggest first, leaves out private, income, excluded and other months', () {
      final txs = [
        tx('a', me, 30000),
        tx('b', me, 5000, priv: true),
        tx('c', sam, 45000),
        tx('d', sam, 1000, debit: false),
        tx('e', sam, 2000, excl: true),
        tx('f', Owner.shared, 10000),
        tx('g', me, 99900, month: 10),
      ];
      final r = spendByMember(txs, from: from, to: to, me: me);
      expect(
        [for (final s in r) (s.owner, s.spentMinor, s.count)],
        [(sam, 45000, 1), (me, 30000, 1), (Owner.shared, 10000, 1)],
      );
    });

    test('mine drops out while sharing is off', () {
      final r = spendByMember(
        [tx('a', me, 100), tx('b', sam, 200)],
        from: from,
        to: to,
        me: me,
        shareMine: false,
      );
      expect([for (final s in r) s.owner], [sam]);
    });
  });

  group('joint budget', () {
    test(
      'counts every visible member in the limit category and ranks by progress',
      () {
        final limits = [
          const HLimit(id: 'l1', categoryId: 'groceries', limitMinor: 100000),
          const HLimit(id: 'l2', categoryId: 'dining', limitMinor: 100000),
        ];
        final txs = [
          tx('a', me, 40000),
          tx('b', sam, 35000),
          tx('c', me, 9000, priv: true),
          tx('d', Owner.shared, 30000),
          tx('e', me, 20000, cat: 'dining'),
        ];
        final b = jointBudget(
          limits,
          txs,
          month: DateTime.utc(2026, 11, 15),
          me: me,
        );
        expect(b.lines.first.limit.id, 'l1');
        expect(b.lines.first.spentMinor, 105000);
        expect(b.lines.first.remainingMinor, -5000);
        expect(b.lines.first.byOwner, {
          me: 40000,
          sam: 35000,
          Owner.shared: 30000,
        });
        expect(b.plannedMinor, 200000);
        expect(b.spentMinor, 125000);
      },
    );
  });

  group('bills', () {
    test('split is exact and deterministic', () {
      final s = splitMinor(10000, {'a': 3333, 'b': 3333, 'c': 3334});
      expect(s.values.fold(0, (x, y) => x + y), 10000);
      expect(splitMinor(100, {'a': 1, 'b': 1, 'c': 1}), {
        'a': 34,
        'b': 33,
        'c': 33,
      });
      expect(splitMinor(0, {'a': 1}), {'a': 0});
    });

    test('equal and 60/40 shares of a bill', () {
      const rent = HBill(
        id: 'r',
        name: 'Rent',
        amountMinor: 650000,
        dueDay: 1,
        split: {me: 6000, sam: 4000},
      );
      expect(billShares(rent), {me: 390000, sam: 260000});
      expect(equalSplit([me, sam]), {me: 5000, sam: 5000});
      expect(validSplit({}), isFalse);
      expect(validSplit({me: 0}), isFalse);
    });

    test('next due clamps to short months and rolls over', () {
      const b = HBill(
        id: 'b',
        name: 'x',
        amountMinor: 1,
        dueDay: 31,
        split: {me: 10000},
      );
      expect(nextDue(b, const CalDate(2026, 2, 3)).toIso(), '2026-02-28');
      expect(nextDue(b, const CalDate(2026, 4, 30)).toIso(), '2026-04-30');
      const c = HBill(
        id: 'c',
        name: 'x',
        amountMinor: 1,
        dueDay: 5,
        split: {me: 10000},
      );
      expect(nextDue(c, const CalDate(2026, 11, 5)).toIso(), '2026-11-05');
      expect(nextDue(c, const CalDate(2026, 11, 6)).toIso(), '2026-12-05');
      expect(nextDue(c, const CalDate(2026, 12, 20)).toIso(), '2027-01-05');
    });

    test('upcoming bills ordered by date with my share, and monthly total', () {
      const bills = [
        HBill(
          id: 'a',
          name: 'Internet',
          amountMinor: 40000,
          dueDay: 20,
          split: {me: 5000, sam: 5000},
        ),
        HBill(
          id: 'b',
          name: 'Rent',
          amountMinor: 650000,
          dueDay: 1,
          split: {me: 6000, sam: 4000},
        ),
      ];
      final u = upcomingBills(bills, const CalDate(2026, 11, 24), me);
      expect([for (final x in u) x.bill.id], ['b', 'a']);
      expect(u.first.daysAway, 7);
      expect(u.first.myShareMinor, 390000);
      expect(myMonthlyBills(bills, me), 410000);
    });
  });

  test('joint goals: shared first, never private', () {
    const g = [
      HGoal(
        id: '1',
        name: 'Zed',
        targetMinor: 100,
        currentMinor: 50,
        progressBps: 5000,
        owner: me,
      ),
      HGoal(
        id: '2',
        name: 'Trip',
        targetMinor: 100,
        currentMinor: 50,
        progressBps: 5000,
        owner: Owner.shared,
      ),
      HGoal(
        id: '3',
        name: 'Secret',
        targetMinor: 100,
        currentMinor: 50,
        progressBps: 5000,
        owner: me,
        isPrivate: true,
      ),
      HGoal(
        id: '4',
        name: 'Sam car',
        targetMinor: 100,
        currentMinor: 50,
        progressBps: 5000,
        owner: sam,
      ),
    ];
    expect(
      [for (final x in jointGoals(g, me: me)) x.name],
      ['Trip', 'Sam car', 'Zed'],
    );
  });
}
