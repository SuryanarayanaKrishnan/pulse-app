import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/nw_history.dart';
import 'package:pulse/core/engine/recurring_plan.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/recurring_service.dart';

import 'local_repository_test.dart' show rig;

Future<void> tx(PulseDatabase db, String id, DateTime at, int minor, String dir, {String account = 'a1'}) =>
    db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        id: id,
        accountId: account,
        amountMinor: minor,
        direction: dir,
        postedAt: at,
        source: 'manual',
        merchantRaw: const Value('Test'),
      ),
    );

void main() {
  test('net worth history: today is stored once a day and earlier days are rebuilt from payments', () async {
    final r = await rig(); // clock: 12 March 2026
    final db = r.db;
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: 'a1',
        type: 'bank',
        name: 'Current',
        balanceAnchorMinor: const Value(100000),
        balanceAnchorAt: Value(DateTime.utc(2026, 1, 1)),
      ),
    );
    await tx(db, 't1', DateTime.utc(2026, 1, 10, 8), 20000, 'debit');
    await tx(db, 't2', DateTime.utc(2026, 2, 1, 8), 500000, 'credit');
    await tx(db, 't3', DateTime.utc(2026, 2, 20, 8), 30000, 'debit');

    final h = await r.repo.netWorthHistory();
    // 100000 - 20000 + 500000 - 30000 = 550000 today.
    expect(h.last.date, const CalDate(2026, 3, 12));
    expect(h.last.netMinor, 550000);
    expect(h.last.estimated, isFalse);
    // Rebuilt days: before the salary, after it, before the spend.
    NwPoint at(CalDate d) => h.firstWhere((p) => p.date == d);
    expect(at(const CalDate(2026, 3, 11)).netMinor, 550000);
    expect(at(const CalDate(2026, 2, 19)).netMinor, 580000);
    expect(at(const CalDate(2026, 2, 20)).netMinor, 550000);
    expect(at(const CalDate(2026, 1, 31)).netMinor, 80000);
    expect(at(const CalDate(2026, 1, 9)).netMinor, 100000);
    expect(at(const CalDate(2026, 1, 9)).estimated, isTrue);
    expect(h.where((p) => !p.estimated), hasLength(1));
    // Chronological, one per day, none invented before the first payment.
    expect(h.map((p) => p.date).toList(), [...h.map((p) => p.date)]..sort());
    expect(h.map((p) => p.date).toSet(), hasLength(h.length));
    expect(h.first.date, const CalDate(2026, 1, 9));

    // A second call changes nothing (no duplicates, same values).
    final again = await r.repo.netWorthHistory();
    expect(again, h);
    expect((await db.select(db.netWorthSnapshots).get()), hasLength(h.length));
  });

  test('a real snapshot is never overwritten by the rebuild', () async {
    final r = await rig();
    final db = r.db;
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(id: 'a1', type: 'bank', name: 'Current', balanceAnchorMinor: const Value(0), balanceAnchorAt: Value(DateTime.utc(2026, 1, 1))),
    );
    await tx(db, 't1', DateTime.utc(2026, 3, 1, 8), 10000, 'credit');
    await db.customStatement(
      "INSERT INTO net_worth_snapshots (id, snapshot_date, assets_minor, liabilities_minor, net_worth_minor) VALUES ('s1', '2026-03-05', 777, 0, 777)",
    );
    final h = await r.repo.netWorthHistory();
    final real = h.firstWhere((p) => p.date == const CalDate(2026, 3, 5));
    expect(real.netMinor, 777);
    expect(real.estimated, isFalse);
    // Rebuilt days stop before the first real one.
    expect(h.where((p) => p.estimated).every((p) => p.date < const CalDate(2026, 3, 5)), isTrue);
  });

  test('with no payments there is just today', () async {
    final r = await rig();
    final h = await r.repo.netWorthHistory();
    expect(h, hasLength(1));
    expect(h.single.date, const CalDate(2026, 3, 12));
  });

  test('the recurring store keeps choices, replaces them and clears them', () async {
    final r = await rig();
    final store = DriftRecurringStore(r.db);
    expect(await store.choices(), isEmpty);
    await store.setChoice('acme tv', RecChoice.confirmed, merchant: 'ACME TV');
    await store.setChoice('gym', RecChoice.ignored);
    expect(await store.choices(), {'acme tv': RecChoice.confirmed, 'gym': RecChoice.ignored});
    await store.setChoice('acme tv', RecChoice.ignored);
    await store.setChoice('gym', null);
    expect(await store.choices(), {'acme tv': RecChoice.ignored});
    final row = await r.db.select(r.db.recurringChoices).getSingle();
    expect(row.merchant, 'ACME TV');
  });

  test('Safe to spend stops counting a series once it is ignored', () async {
    final r = await rig();
    final db = r.db;
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(id: 'a1', type: 'bank', name: 'Current', balanceAnchorMinor: const Value(1000000), balanceAnchorAt: Value(DateTime.utc(2025, 1, 1))),
    );
    // A monthly AED 50 charge on the 20th: next one lands later this month (clock: 12 March).
    for (final m in [11, 12, 1, 2]) {
      final y = m >= 11 ? 2025 : 2026;
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: 'g$m', accountId: 'a1', amountMinor: 5000, direction: 'debit', postedAt: DateTime.utc(y, m, 20, 8), source: 'manual',
          merchantRaw: const Value('ACME TV'), merchantNormalized: const Value('ACME TV'),
        ),
      );
    }
    final before = (await r.repo.safeToSpend()).bills;
    expect(before, 50.0);
    await DriftRecurringStore(db).setChoice('acme tv', RecChoice.ignored);
    expect((await r.repo.safeToSpend()).bills, 0.0);
  });
}
