import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/kv_store.dart';
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

  Future<Transaction> pay(String place) async {
    final before = (await repo.transactions()).map((t) => t.id).toSet();
    await pipeline.ingest(
      IngestInput(
        channel: TxnSource.sms,
        rawText:
            'Purchase of AED 45.00 with Credit Card ending 1234 at $place.',
        sender: 'ENBD',
        receivedAt: _now.add(Duration(minutes: n)),
        externalId: 'm${n++}',
      ),
    );
    return (await repo.transactions()).firstWhere(
      (t) => !before.contains(t.id),
    );
  }

  test(
    'an unknown merchant is uncategorised until you choose, then follows you',
    () async {
      final first = await pay('ZED CORNER SHOP, DUBAI');
      expect(first.category.id, 'other');
      expect(first.learned, isFalse);

      await memory.confirm(first.merchant, 'groceries', weight: fixWeight);

      final next = await pay('ZED CORNER SHOP, DUBAI');
      expect(next.category.id, 'groceries');
      expect(next.learned, isTrue);

      // A different spelling of the same merchant lands the same way.
      final variant = await pay('POS PURCHASE ZED CORNER SHOP DXB 4471');
      expect(variant.category.id, 'groceries');
      expect(variant.learned, isTrue);
    },
  );

  test(
    'your choice beats the built-in dictionary; forgetting restores it',
    () async {
      final base = await pay('CARREFOUR, DUBAI');
      expect(base.category.id, 'groceries');
      expect(base.learned, isFalse);

      await memory.confirm('Carrefour', 'shopping', weight: fixWeight);
      final mine = await pay('CARREFOUR, DUBAI');
      expect(mine.category.id, 'shopping');
      expect(mine.learned, isTrue);

      await memory.forget('Carrefour');
      final back = await pay('CARREFOUR, DUBAI');
      expect(back.category.id, 'groceries');
      expect(back.learned, isFalse);
    },
  );

  test(
    'a single plain confirmation does not yet change future payments',
    () async {
      await memory.confirm('Zed Corner Shop', 'groceries');
      final next = await pay('ZED CORNER SHOP, DUBAI');
      expect(next.learned, isFalse);
    },
  );
}
