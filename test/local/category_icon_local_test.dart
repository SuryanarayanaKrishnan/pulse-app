import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';
import 'package:pulse/data/models.dart';

Future<LocalPulseRepository> _repo() async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = PulseDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final catalog = CatalogService(db: db, bundled: () async => File('assets/catalog/cards.json').readAsStringSync());
  await catalog.loadBundled();
  final pipeline = IngestPipeline(db, clock: DateTime.now);
  addTearDown(pipeline.dispose);
  return LocalPulseRepository(db: db, catalog: catalog, pipeline: pipeline);
}

void main() {
  test('a custom category keeps the icon it was created with', () async {
    final r = await _repo();
    final made = await r.createCategory(name: 'Pets', iconKey: 'paw');
    expect(made.iconKey, 'paw');
    final listed = (await r.categories()).firstWhere((c) => c.id == made.id);
    expect(listed.iconKey, 'paw');
    expect(listed.custom, isTrue);
  });

  test('without a pick it stays null (generic tag); defaults are untouched', () async {
    final r = await _repo();
    final made = await r.createCategory(name: 'Misc things');
    expect(made.iconKey, isNull);
    expect((await r.categories()).where((c) => !c.custom).map((c) => c.iconKey), everyElement(isNull));
  });

  test('setCategoryIcon changes a custom category and ignores defaults', () async {
    final r = await _repo();
    final made = await r.createCategory(name: 'Pets', iconKey: 'paw');
    final changed = await r.setCategoryIcon(made, 'leaf');
    expect(changed.iconKey, 'leaf');
    expect((await r.categories()).firstWhere((c) => c.id == made.id).iconKey, 'leaf');
    await r.setCategoryIcon(SpendCategory.groceries, 'leaf');
    expect((await r.categories()).firstWhere((c) => c.id == 'groceries').iconKey, isNull);
  });

  test('a transaction in a custom category carries its icon to the row', () async {
    final r = await _repo();
    final made = await r.createCategory(name: 'Pets', iconKey: 'paw');
    final tx = await r.addManualTransaction(merchant: 'Vet', amount: 120, category: made);
    expect(tx.category.iconKey, 'paw');
  });
}
