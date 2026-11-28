import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/engine/superapps.dart';
import 'package:pulse/core/engine/types.dart';
import 'package:pulse/core/learning/merchant_memory.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';
import 'package:pulse/data/models.dart';

final _now = DateTime.utc(2026, 3, 12, 8);

void main() {
  late LocalPulseRepository repo;
  late IngestPipeline pipeline;
  late MerchantMemory memory;
  var n = 0;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = PulseDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = CatalogService(
      db: db,
      bundled: () async =>
          File('test/fixtures/catalog/cards_small.json').readAsStringSync(),
    );
    await catalog.loadBundled();
    memory = MerchantMemory(MemoryKvStore());
    pipeline = IngestPipeline(db, clock: () => _now, memory: memory);
    addTearDown(pipeline.dispose);
    repo = LocalPulseRepository(
      db: db,
      catalog: catalog,
      pipeline: pipeline,
      clock: () => _now,
    );
    await repo.addCard(
      catalogId: 'emirates-nbd-skywards-infinite',
      last4: '1234',
      limit: 20000,
      statementDay: 1,
      dueDay: 25,
    );
  });

  Future<IngestOutcome> pay(
    String place,
    String amount, {
    TxnSource channel = TxnSource.sms,
    int minutes = 0,
  }) => pipeline.ingest(
    IngestInput(
      channel: channel,
      rawText:
          'Purchase of AED $amount with Credit Card ending 1234 at $place.',
      sender: channel == TxnSource.sms ? 'ENBD' : null,
      receivedAt: _now.add(Duration(minutes: minutes)),
      externalId: 'm${n++}',
    ),
  );

  Future<List<Transaction>> all() => repo.transactions();

  test('a bare super-app name is a guess and offers chips', () async {
    await pay('CAREEM', '45.00');
    final t = (await all()).single;
    expect(t.guess, isTrue);
    expect(t.reviewed, isFalse);
    expect(chipsFor(t.merchant), contains('dining'));
  });

  test('a named sub-service is not a guess', () async {
    await pay('CAREEM FOOD', '45.00');
    final t = (await all()).single;
    expect(t.guess, isFalse);
    expect(t.category.id, 'dining');
  });

  test('a second channel merges and upgrades the vague bank name', () async {
    await pay('NOON.COM', '120.00');
    final out = await pay(
      'NOON FOOD',
      '120.00',
      channel: TxnSource.appleShortcut,
      minutes: 3,
    );
    expect(out.status, IngestStatus.merged);
    final rows = await all();
    expect(rows, hasLength(1));
    expect(rows.single.category.id, 'dining');
    expect(rows.single.guess, isFalse);
  });

  test('two same-amount purchases on one channel stay two rows', () async {
    await pay('NOON.COM', '120.00');
    await pay('NOON.COM', '120.00', minutes: 5);
    expect(await all(), hasLength(2));
  });

  test('habit is learned per size band, other sizes stay guesses', () async {
    for (var i = 0; i < 3; i++) {
      await memory.confirmHabit('careem', 1200, _now, 'transport');
    }
    await pay('CAREEM', '12.00');
    await pay('CAREEM', '95.00', minutes: 10);
    final rows = await all();
    final small = rows.firstWhere((t) => t.amount == 12);
    final big = rows.firstWhere((t) => t.amount == 95);
    expect(small.category.id, 'transport');
    expect(small.guess, isFalse);
    expect(big.guess, isTrue);
  });
}
