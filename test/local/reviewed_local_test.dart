import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/recategorise.dart';
import 'package:pulse/core/engine/types.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';
import 'package:pulse/data/models.dart';

final _now = DateTime.utc(2026, 3, 12, 8);

Future<LocalPulseRepository> _repo() async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = PulseDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final catalog = CatalogService(db: db, bundled: () async => File('test/fixtures/catalog/cards_small.json').readAsStringSync());
  await catalog.loadBundled();
  final pipeline = IngestPipeline(db, clock: () => _now);
  addTearDown(pipeline.dispose);
  final repo = LocalPulseRepository(db: db, catalog: catalog, pipeline: pipeline, clock: () => _now);
  await repo.addCard(catalogId: 'emirates-nbd-skywards-infinite', last4: '1234', limit: 20000, statementDay: 1, dueDay: 25);
  for (final (i, place) in ['CARREFOUR, DUBAI', 'STARBUCKS, DUBAI'].indexed) {
    await pipeline.ingest(IngestInput(
      channel: TxnSource.sms,
      rawText: 'Purchase of AED 45.00 with Credit Card ending 1234 at $place.',
      sender: 'ENBD',
      receivedAt: DateTime.utc(2026, 3, 12, 9, i),
      externalId: 'r$i',
    ));
  }
  return repo;
}

void main() {
  test('captured payments start unreviewed, typed ones are reviewed', () async {
    final r = await _repo();
    expect((await r.transactions()).every((t) => !t.reviewed), isTrue);
    final manual = await r.addManualTransaction(merchant: 'Lunch', amount: 30, category: SpendCategory.dining);
    expect(manual.reviewed, isTrue);
  });

  test('setReviewed marks and unmarks, only the named rows', () async {
    final r = await _repo();
    final ids = [for (final t in await r.transactions()) t.id];
    await r.setReviewed([ids.first], true);
    final after = {for (final t in await r.transactions()) t.id: t.reviewed};
    expect(after[ids.first], isTrue);
    expect(after[ids.last], isFalse);
    await r.setReviewed([ids.first], false);
    expect((await r.transactions()).every((t) => !t.reviewed), isTrue);
    await r.setReviewed(const [], true); // nothing to do, no error
  });

  test('changing a category counts as reviewing it', () async {
    final r = await _repo();
    final txs = await r.transactions();
    final a = txs.firstWhere((t) => t.merchant == 'Carrefour');
    final b = txs.firstWhere((t) => t.merchant == 'Starbucks');
    await r.recategorise(a.id, SpendCategory.shopping);
    await r.recategoriseScoped(b.id, SpendCategory.entertainment, RecategoriseScope.once);
    final after = await r.transactions();
    expect(after.every((t) => t.reviewed), isTrue);
  });

  test('a rule-made category is more confident than a bare guess', () async {
    final r = await _repo();
    final before = (await r.transactions()).firstWhere((t) => t.merchant == 'Carrefour').confidence;
    expect(before, lessThan(0.95));
  });
}
