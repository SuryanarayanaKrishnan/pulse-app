import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';

/// A phone that once took a newer, smaller remote catalog must still get every
/// bundled card (surya could not find HSBC or Tabby on build 10), and an
/// unlisted card can be added by hand.
void main() {
  late PulseDatabase db;
  final bundled = File('assets/catalog/cards.json').readAsStringSync();

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = PulseDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  test('a newer remote catalog without some cards does not hide the bundled ones', () async {
    final doc = jsonDecode(bundled) as Map<String, Object?>;
    final remote = {
      ...doc,
      'version': (doc['version'] as int) + 5,
      'cards': [
        for (final c in doc['cards'] as List)
          if (!'${(c as Map)['id']}'.startsWith('hsbc') && c['id'] != 'tabby-card') c,
      ],
    };
    final svc = CatalogService(db: db, bundled: () async => jsonEncode(remote));
    await svc.loadBundled(); // the phone already holds the newer, smaller catalog
    final ids0 = {for (final r in await db.select(db.catalogCards).get()) r.id};
    expect(ids0, isNot(contains('tabby-card')));

    final healed = CatalogService(db: db, bundled: () async => bundled);
    await healed.loadBundled();
    final ids = {for (final r in await db.select(db.catalogCards).get()) r.id};
    expect(ids, contains('tabby-card'));
    expect(ids.where((i) => i.startsWith('hsbc')), isNotEmpty);
  });

  test('a stored card is never overwritten by the bundled copy', () async {
    final svc = CatalogService(db: db, bundled: () async => bundled);
    await svc.loadBundled();
    await (db.update(db.catalogCards)..where((c) => c.id.equals('tabby-card'))).write(
      const CatalogCardsCompanion(name: Value('Newer name')),
    );
    await CatalogService(db: db, bundled: () async => bundled).loadBundled();
    final row = await (db.select(db.catalogCards)..where((c) => c.id.equals('tabby-card'))).getSingle();
    expect(row.name, 'Newer name');
  });

  test('"I can\'t find my card": an unlisted card is created and can be added to the wallet', () async {
    final catalog = CatalogService(db: db, bundled: () async => bundled);
    await catalog.loadBundled();
    final now = DateTime.utc(2026, 11, 28, 8);
    final pipeline = IngestPipeline(db, clock: () => now);
    addTearDown(pipeline.dispose);
    final repo = LocalPulseRepository(db: db, catalog: catalog, pipeline: pipeline, clock: () => now);

    final card = await repo.addCustomCatalogCard(issuer: ' Some Bank ', name: 'Gold');
    expect(card.id, startsWith('custom-'));
    expect((await repo.cardCatalog()).map((c) => c.id), contains(card.id));
    await repo.addCard(catalogId: card.id, last4: '4242');
    expect((await repo.myCards()).map((c) => c.id), isNotEmpty);
    await expectLater(repo.addCustomCatalogCard(issuer: '', name: 'x'), throwsA(anything));
  });
}
