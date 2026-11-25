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
  final catalog = CatalogService(
    db: db,
    bundled: () async => File('assets/catalog/cards.json').readAsStringSync(),
  );
  await catalog.loadBundled();
  final pipeline = IngestPipeline(db, clock: () => _now);
  addTearDown(pipeline.dispose);
  final repo = LocalPulseRepository(db: db, catalog: catalog, pipeline: pipeline, clock: () => _now);
  await repo.addBankAccount(bank: 'Synthetic Bank', name: 'Current', kind: BankAccountKind.current, last4: '5678', balance: 1000);
  await repo.addCard(catalogId: 'emirates-nbd-skywards-infinite', last4: '1234', limit: 20000, statementDay: 1, dueDay: 25);
  var n = 0;
  for (final (place, day) in [
    ('CARREFOUR, DUBAI', 12),
    ('CARREFOUR, DUBAI', 11),
    ('CARREFOUR MOE, DUBAI', 10),
    ('STARBUCKS, DUBAI', 12),
  ]) {
    await pipeline.ingest(IngestInput(
      channel: TxnSource.sms,
      rawText: 'Purchase of AED 45.00 with Credit Card ending 1234 at $place.',
      sender: 'ENBD',
      receivedAt: DateTime.utc(2026, 3, day, 9, n),
      externalId: 'x${n++}',
    ));
  }
  return repo;
}

Future<Map<String, SpendCategory>> _cats(LocalPulseRepository r) async => {
  for (final t in await r.transactions()) '${t.merchant}|${t.id}': t.category,
};

void main() {
  test('preview counts only other matching past transactions', () async {
    final r = await _repo();
    final tx = (await r.transactions()).firstWhere((t) => t.merchant.contains('Carrefour'));
    final p = await r.previewRecategorise(tx.id, SpendCategory.entertainment);
    expect(p!.pastCount, 2);
    expect(p.merchant, 'Carrefour');
  });

  test('once changes one row and creates no rule', () async {
    final r = await _repo();
    final tx = (await r.transactions()).firstWhere((t) => t.merchant == 'Carrefour');
    await r.recategoriseScoped(tx.id, SpendCategory.entertainment, RecategoriseScope.once);
    expect((await r.transactions()).where((t) => t.category == SpendCategory.entertainment), hasLength(1));
    expect(await r.rules(), isEmpty);
  });

  test('future creates a rule but leaves the past alone', () async {
    final r = await _repo();
    final tx = (await r.transactions()).firstWhere((t) => t.merchant == 'Carrefour');
    await r.recategoriseScoped(tx.id, SpendCategory.entertainment, RecategoriseScope.future);
    expect((await r.transactions()).where((t) => t.category == SpendCategory.entertainment), hasLength(1));
    expect(await r.rules(), hasLength(1));
  });

  test('all changes every variant in one go and undo restores everything', () async {
    final r = await _repo();
    final before = await _cats(r);
    final tx = (await r.transactions()).firstWhere((t) => t.merchant == 'Carrefour');
    final undo = await r.recategoriseScoped(tx.id, SpendCategory.entertainment, RecategoriseScope.all);
    final after = await r.transactions();
    expect(after.where((t) => t.category == SpendCategory.entertainment), hasLength(3));
    expect(after.where((t) => t.merchant.contains('Starbucks')).single.category, isNot(SpendCategory.entertainment));
    expect(await r.rules(), hasLength(1));
    expect(undo.pastCount, 2);

    await r.undoRecategorise(undo);
    expect(await _cats(r), before);
    expect(await r.rules(), isEmpty);
  });

  test('undo restores a rule that the change overwrote', () async {
    final r = await _repo();
    final tx = (await r.transactions()).firstWhere((t) => t.merchant == 'Carrefour');
    await r.recategoriseScoped(tx.id, SpendCategory.entertainment, RecategoriseScope.future);
    final undo = await r.recategoriseScoped(tx.id, SpendCategory.shopping, RecategoriseScope.future);
    expect((await r.rules()).single.category, SpendCategory.shopping);
    await r.undoRecategorise(undo);
    final rules = await r.rules();
    expect(rules.single.category, SpendCategory.entertainment);
  });
}
