import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/types.dart' show TxnSource;
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';

/// Right/wrong card and the value report through the real on-device pipeline,
/// with synthetic payments only.
void main() {
  final now = DateTime.utc(2026, 3, 12, 8);
  late PulseDatabase db;
  late IngestPipeline pipeline;
  late LocalPulseRepository repo;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = PulseDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = CatalogService(
      db: db,
      bundled: () async => File('assets/catalog/cards.json').readAsStringSync(),
    );
    await catalog.loadBundled();
    pipeline = IngestPipeline(db, clock: () => now);
    addTearDown(pipeline.dispose);
    repo = LocalPulseRepository(
      db: db,
      catalog: catalog,
      pipeline: pipeline,
      clock: () => now,
    );
  });

  Future<IngestOutcome> pay(
    String last4,
    int minor,
    String merchant,
    String id,
  ) => pipeline.ingest(
    IngestInput(
      channel: TxnSource.googleWallet,
      externalId: id,
      receivedAt: now,
      appName: 'Wallet',
      fields: IngestFields(
        amountMinor: minor,
        merchant: merchant,
        last4: last4,
        postedAt: now,
      ),
    ),
  );

  test(
    'wrong card on groceries is flagged with the AED missed; right card is not',
    () async {
      await repo.addCard(
        catalogId: 'adcb-lulu-platinum',
        last4: '1111',
        limit: 20000,
      );
      await repo.addCard(
        catalogId: 'emirates-nbd-go4it',
        last4: '2222',
        limit: 20000,
      );

      final wrong = (await pay(
        '2222',
        50000,
        'Carrefour',
        'w1',
      )).reward!.check!;
      expect(wrong.right, isFalse);
      expect(wrong.bestTitle, contains('Lulu'));
      expect(wrong.bestMinor, greaterThan(wrong.earnedMinor));
      expect(
        wrong.estimated,
        isTrue,
        reason: 'seeded catalog terms are unverified',
      );

      final right = (await pay(
        '1111',
        50000,
        'Carrefour',
        'r1',
      )).reward!.check!;
      expect(right.right, isTrue);
      expect(right.paidTitle, contains('Lulu'));
    },
  );

  test('a single card has nothing to compare', () async {
    await repo.addCard(
      catalogId: 'emirates-nbd-go4it',
      last4: '2222',
      limit: 20000,
    );
    expect((await pay('2222', 50000, 'Carrefour', 's1')).reward!.check, isNull);
  });

  test(
    'the value report ranks owned cards and is empty without cards',
    () async {
      expect((await repo.cardValueReport()).isEmpty, isTrue);
      await repo.addCard(
        catalogId: 'adcb-lulu-platinum',
        last4: '1111',
        limit: 20000,
      );
      await repo.addCard(
        catalogId: 'emirates-nbd-go4it',
        last4: '2222',
        limit: 20000,
      );
      await pay('1111', 50000, 'Carrefour', 'a1');
      final r = await repo.cardValueReport();
      expect(r.ranking, hasLength(2));
      expect(r.ranking.first.title, contains('Lulu'));
      expect(r.ranking.first.windowRewardsMinor, greaterThan(0));
      expect(r.extras.keys, hasLength(2));
      expect(r.extras.values.every((e) => e.estimated), isTrue);
    },
  );
}
