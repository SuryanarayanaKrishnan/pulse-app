import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';
import 'package:pulse/data/local/splits_store.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/splits_util.dart';

final _now = DateTime.utc(2026, 3, 12, 8);

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
  test('splitting your own payment links the split to it', () async {
    final repo = await _repo();
    final tx = await repo.addManualTransaction(
      merchant: 'Dinner',
      amount: 120,
      category: SpendCategory.other,
    );
    final g = await repo.createSplitGroup(
      name: 'Flat',
      members: const [NewGroupMember(name: 'Ali')],
    );
    await repo.addSplitExpense(
      g.id,
      SplitExpense(
        id: 'new1',
        title: tx.merchant,
        paidBy: 'me',
        amount: tx.amount,
        participants: g.members.map((m) => m.id).toList(),
        date: tx.date,
        transactionId: tx.id,
      ),
    );
    final groups = await repo.splitGroups();
    final (grp, e) = splitForTransaction(groups, tx.id)!;
    expect(grp.id, g.id);
    expect(e.amount, 120);
    expect(shareOf(e, 'me'), 60);
    // No extra transaction: only the payment you already had.
    expect((await repo.transactions()).length, 1);
  });

  test('a bill a friend paid adds your share once', () async {
    final repo = await _repo();
    final g = await repo.createSplitGroup(
      name: 'Trip',
      members: const [NewGroupMember(name: 'Sara')],
    );
    final sara = g.members.last.id;
    await repo.addSplitExpense(
      g.id,
      SplitExpense(
        id: 'new1',
        title: 'Hotel',
        paidBy: sara,
        amount: 300,
        participants: g.members.map((m) => m.id).toList(),
        date: _now,
      ),
    );
    // Loading again (what a sync does) must not add it twice.
    await repo.splitGroups();
    await repo.splitGroups();
    final txs = await repo.transactions();
    expect(txs.length, 1);
    expect(txs.single.merchant, 'Hotel');
    expect(txs.single.amount, 150);
    expect(txs.single.isIncome, isFalse);

    final groups = await repo.splitGroups();
    final (_, e) = splitForTransaction(groups, txs.single.id)!;
    expect(e.title, 'Hotel');

    // Deleting it sticks.
    await repo.deleteTransaction(txs.single.id);
    await repo.splitGroups();
    expect(await repo.transactions(), isEmpty);
  });

  test('shareOf: equal and explicit', () {
    final eq = SplitExpense(
      id: 'a',
      title: 't',
      paidBy: 'me',
      amount: 100,
      participants: const ['me', 'x', 'y'],
      date: _now,
    );
    expect(shareOf(eq, 'me'), 33.33);
    expect(shareOf(eq, 'z'), 0);
    final ex = SplitExpense(
      id: 'b',
      title: 't',
      paidBy: 'x',
      amount: 100,
      participants: const ['me', 'x'],
      date: _now,
      shares: const {'me': 70, 'x': 30},
    );
    expect(shareOf(ex, 'me'), 70);
  });
}
