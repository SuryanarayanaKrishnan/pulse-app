import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';
import 'package:pulse/data/models.dart';

final _now = DateTime.utc(2026, 3, 12, 8); // 12 March, Dubai

Future<LocalPulseRepository> _repo() async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = PulseDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final catalog = CatalogService(
    db: db,
    bundled: () async =>
        File('test/fixtures/catalog/cards_small.json').readAsStringSync(),
  );
  await catalog.loadBundled();
  final pipeline = IngestPipeline(db, clock: () => _now);
  addTearDown(pipeline.dispose);
  return LocalPulseRepository(
    db: db,
    catalog: catalog,
    pipeline: pipeline,
    clock: () => _now,
  );
}

void main() {
  test(
    'a manual payment takes a date and a note, and income counts as income',
    () async {
      final r = await _repo();
      final lunch = await r.addManualTransaction(
        merchant: 'Lunch',
        amount: 30,
        category: SpendCategory.dining,
        date: DateTime(2026, 3, 3, 12),
        note: '  with Sam ',
      );
      expect(lunch.note, 'with Sam');
      expect(lunch.date.day, 3);
      expect(lunch.isIncome, isFalse);
      final gift = await r.addManualTransaction(
        merchant: 'Gift',
        amount: 200,
        category: SpendCategory.salary,
      );
      expect(gift.isIncome, isTrue);
    },
  );

  test('notes can be set, changed and cleared', () async {
    final r = await _repo();
    final t = await r.addManualTransaction(
      merchant: 'Taxi',
      amount: 20,
      category: SpendCategory.transport,
    );
    expect(t.note, isNull);
    await r.setTransactionNote(t.id, 'airport run');
    expect((await r.transactions()).single.note, 'airport run');
    await r.setTransactionNote(t.id, '   ');
    expect((await r.transactions()).single.note, isNull);
  });

  test('a deleted payment leaves the list and the totals', () async {
    final r = await _repo();
    final a = await r.addManualTransaction(
      merchant: 'A',
      amount: 10,
      category: SpendCategory.dining,
    );
    await r.addManualTransaction(
      merchant: 'B',
      amount: 15,
      category: SpendCategory.dining,
    );
    await r.deleteTransaction(a.id);
    expect([for (final t in await r.transactions()) t.merchant], ['B']);
    expect((await r.transactionsPage()).items.map((t) => t.merchant), ['B']);
  });

  test('a typed salary shows up on payday and not before', () async {
    final r = await _repo();
    await r.setManualSalary(const ManualSalary(amountMinor: 1500000, day: 25));
    expect(await r.transactions(), isEmpty, reason: '25th has not come yet');
    await r.setManualSalary(const ManualSalary(amountMinor: 1500000, day: 5));
    final txs = await r.transactions();
    expect(txs, hasLength(1));
    expect(txs.single.isIncome, isTrue);
    expect(txs.single.category, SpendCategory.salary);
    expect(txs.single.amount, 15000);
    // Asking again does not add a second one.
    expect(await r.transactions(), hasLength(1));
    expect((await r.manualSalary())!.day, 5);
  });

  test(
    'a detected salary replaces the typed one and updates the amount',
    () async {
      final r = await _repo();
      await r.setManualSalary(const ManualSalary(amountMinor: 1500000, day: 5));
      expect(await r.transactions(), hasLength(1));
      await r.addManualTransaction(
        merchant: 'Acme FZ-LLC',
        amount: 16000,
        category: SpendCategory.salary,
      );
      final txs = await r.transactions();
      expect(txs, hasLength(1));
      expect(txs.single.merchant, 'Acme FZ-LLC');
      expect((await r.manualSalary())!.amountMinor, 1600000);
    },
  );

  test('deleting the typed salary credit keeps it deleted; removing the setting clears it', () async {
    final r = await _repo();
    await r.setManualSalary(const ManualSalary(amountMinor: 1500000, day: 5));
    final id = (await r.transactions()).single.id;
    await r.deleteTransaction(id);
    expect(await r.transactions(), isEmpty);
    await r.setManualSalary(null);
    expect(await r.manualSalary(), isNull);
    expect(await r.transactions(), isEmpty);
  });
}
