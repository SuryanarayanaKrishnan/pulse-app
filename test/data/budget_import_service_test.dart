import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/budget_suggest.dart';
import 'package:pulse/core/engine/sheet_import.dart';
import 'package:pulse/data/budget_import_service.dart';
import 'package:pulse/data/budget_plan_service.dart';
import 'package:pulse/data/local/budget_plan_store.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';

String fx(String n) => File('test/fixtures/sheets/$n').readAsStringSync();

Future<(LocalPulseRepository, BudgetImportService, BudgetPlanService)> _setup() async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = PulseDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final catalog = CatalogService(db: db, bundled: () async => File('assets/catalog/cards.json').readAsStringSync());
  await catalog.loadBundled();
  final pipeline = IngestPipeline(db, clock: DateTime.now);
  addTearDown(pipeline.dispose);
  final repo = LocalPulseRepository(db: db, catalog: catalog, pipeline: pipeline);
  final plan = BudgetPlanService(
    store: LocalBudgetPlanStore(db),
    transactions: () => repo.transactions(),
    clock: () => DateTime(2026, 10, 15),
  );
  return (repo, BudgetImportService(repo: repo, plan: plan), plan);
}

void main() {
  test('importing the sheet sets limits, creates what is missing, brings history; twice changes nothing', () async {
    final (repo, svc, plan) = await _setup();
    final a = analyzeSheets({
      'Budget': parseCsv(fx('budget_grid.csv')),
      'Ledger': parseCsv(fx('ledger.csv')),
    });
    final maps = await svc.proposeMappings(a);
    String target(String label) => switch (maps.firstWhere((m) => m.label.label == label).target) {
      ExistingTarget(:final category) => category.id,
      NewTarget(:final name) => 'new:$name',
      SkipTarget() => 'skip',
    };
    expect(target('Rent'), 'rent');
    expect(target('Car loan'), 'car_loan');
    expect(target('Groceries'), 'groceries');
    expect(target('Parking'), 'transport');
    expect(target('Salary'), 'salary');
    expect(target('Overall fun'), 'entertainment');

    final r1 = await svc.apply(a, maps);
    expect(r1.limitsSet, greaterThan(0));
    expect(r1.transactionsAdded, 4);

    // The car loan stepped up in August: one limit before, a new one from August.
    final rent = await plan.view(DateTime(2026, 10, 1));
    expect(rent.row('rent')!.plannedMinor, 200000);
    expect(rent.row('car_loan')!.plannedMinor, 120000);
    expect((await plan.view(DateTime(2026, 3, 1))).row('car_loan')!.plannedMinor, 90000);

    // History landed in the ledger, dated as in the sheet.
    final txs = await repo.transactions();
    expect(txs, hasLength(4));
    final g = txs.firstWhere((t) => t.category.id == 'groceries');
    expect(g.date.month, 8);
    expect(g.amount, 1234.5);
    expect(txs.firstWhere((t) => t.category.id == 'salary').isIncome, isTrue);

    final r2 = await svc.apply(a, maps);
    expect(r2.transactionsAdded, 0);
    expect(await repo.transactions(), hasLength(4));
  });

  test('keeping own names makes a category per line; skip leaves a line out', () async {
    final (repo, svc, plan) = await _setup();
    final a = analyzeSheets({'Budget': parseCsv(fx('budget_grid.csv'))});
    final maps = await svc.proposeMappings(a, keepOwnNames: true);
    final parking = maps.firstWhere((m) => m.label.label == 'Parking');
    expect(parking.target, isA<NewTarget>());
    final fun = maps.firstWhere((m) => m.label.label == 'Overall fun');
    fun.target = const SkipTarget();
    final r = await svc.apply(a, maps, importHistory: false);
    expect(r.categoriesCreated, 2); // Rent and Parking; Overall fun was skipped
    expect((await repo.categories()).map((c) => c.label), containsAll(['Rent', 'Parking']));
    expect((await repo.categories()).map((c) => c.label), isNot(contains('Overall fun')));
    expect((await plan.view(DateTime(2026, 10, 1))).rows.length, 4);
  });

  test('actual rows without a ledger become one dated entry per month', () async {
    final (repo, svc, _) = await _setup();
    final a = analyzeSheets({'Budget': parseCsv(fx('budget_grid.csv'))});
    final maps = await svc.proposeMappings(a);
    final r = await svc.apply(a, maps);
    // Salary 3 + rent 3 + car loan 3 + groceries 3 + parking 3 + fun 2 months of actuals.
    expect(r.transactionsAdded, 17);
    final txs = await repo.transactions();
    expect(txs.where((t) => t.merchant.endsWith('(from your sheet)')), hasLength(17));
  });

  test('a suggestion is saved as limits from this month', () async {
    final (_, svc, plan) = await _setup();
    final s = suggestBudget(const SuggestInput(incomeMinor: 1500000));
    final n = await svc.applySuggestion(s, DateTime(2026, 10, 1));
    expect(n, s.lines.length);
    final v = await plan.view(DateTime(2026, 10, 1));
    expect(v.row('rent')!.plannedMinor, s.line('rent')!.amountMinor);
  });
}
