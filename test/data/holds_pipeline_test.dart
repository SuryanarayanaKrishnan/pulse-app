import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/holds.dart';
import 'package:pulse/core/engine/types.dart' show TxnSource;
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';

/// One EV charge, three ways the bank and the merchant can talk about it.
void main() {
  var now = DateTime.utc(2026, 11, 25, 16);
  late PulseDatabase db;
  late IngestPipeline pipeline;

  setUp(() async {
    now = DateTime.utc(2026, 11, 25, 16);
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = PulseDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = CatalogService(
      db: db,
      bundled: () async =>
          File('test/fixtures/catalog/cards_small.json').readAsStringSync(),
    );
    await catalog.loadBundled();
    pipeline = IngestPipeline(db, clock: () => now);
    addTearDown(pipeline.dispose);
    final repo = LocalPulseRepository(
      db: db,
      catalog: catalog,
      pipeline: pipeline,
      clock: () => now,
    );
    await repo.addCard(
      catalogId: 'emirates-nbd-go4it',
      last4: '2222',
      limit: 20000,
    );
  });

  var n = 0;
  Future<IngestOutcome> pay(
    int minor,
    String merchant, {
    Duration after = Duration.zero,
    TxnSource ch = TxnSource.googleWallet,
  }) => pipeline.ingest(
    IngestInput(
      channel: ch,
      externalId: 'p${n++}',
      receivedAt: now.add(after),
      appName: 'Wallet',
      fields: IngestFields(
        amountMinor: minor,
        merchant: merchant,
        last4: '2222',
        postedAt: now.add(after),
      ),
    ),
  );

  Future<IngestOutcome> mail(String text, {Duration after = Duration.zero}) =>
      pipeline.ingest(
        IngestInput(
          channel: TxnSource.notification,
          externalId: 'm${n++}',
          sender: 'noreply@regeny.ae',
          rawText: text,
          receivedAt: now.add(after),
        ),
      );

  Future<List<TxRow>> live() =>
      (db.select(db.transactions)..where((t) => t.deletedAt.isNull())).get();

  const hold =
      'a pre-authorization hold has been placed on your card in the amount of AED100.0 For Regeny EV charging.';
  const settle =
      'the final settlement amount of AED14.85 has been processed for your Regeny EV charging session. The remaining amount from pre-authorization of AED100 will be released shortly.';
  const release =
      'the pre-authorization hold of AED100.0 for your Regeny EV charging session has been successfully released.';

  test(
    'hold alert then final charge: one row, the real amount, counted once',
    () async {
      final h = await pay(10000, 'REGENY EV CHARGING');
      expect(h.status, IngestStatus.stored);
      var rows = await live();
      expect(rows.single.excludeFromBudget, isTrue);
      expect(rows.single.tags, contains(holdTag));

      final f = await pay(
        1485,
        'REGENY EV CHARGING',
        after: const Duration(hours: 2),
      );
      expect(f.status, IngestStatus.merged);
      rows = await live();
      expect(rows, hasLength(1));
      expect(rows.single.amountMinor, 1485);
      expect(rows.single.excludeFromBudget, isFalse);
      expect(rows.single.tags, isNot(contains(holdTag)));
    },
  );

  test(
    'hold alert then settlement email reduces the hold to the final amount',
    () async {
      await pay(10000, 'REGENY EV CHARGING');
      final o = await mail(settle, after: const Duration(hours: 2));
      expect(o.status, IngestStatus.holdUpdated);
      final rows = await live();
      expect(rows.single.amountMinor, 1485);
      expect(rows.single.excludeFromBudget, isFalse);
    },
  );

  test(
    'final charge alert first, then settlement email: the hold row goes away',
    () async {
      await pay(10000, 'REGENY EV CHARGING');
      // The bank sends the final charge and the email comes later; both settle the same hold.
      await pay(1485, 'REGENY EV CHARGING', after: const Duration(hours: 2));
      await mail(settle, after: const Duration(hours: 3));
      final rows = await live();
      expect(rows, hasLength(1));
      expect(rows.single.amountMinor, 1485);
    },
  );

  test('a hold email for a charge already stored marks it pending, a release voids it', () async {
    await pay(10000, 'REGENY EV CHARGING');
    await mail(hold);
    expect((await live()).single.tags, contains(holdTag));
    await mail(release, after: const Duration(hours: 1));
    expect(await live(), isEmpty);
  });

  test('a late hold alert after the settlement email is not spend', () async {
    await mail(settle);
    final late = await pay(
      10000,
      'REGENY EV CHARGING',
      after: const Duration(hours: 1),
    );
    expect(late.status, IngestStatus.ignored);
    await pay(
      1485,
      'REGENY EV CHARGING',
      after: const Duration(hours: 1),
      ch: TxnSource.sms,
    );
    expect((await live()).single.amountMinor, 1485);
  });

  test('the same hold seen on two channels is still one row', () async {
    await pay(10000, 'REGENY EV CHARGING');
    final again = await pay(
      10000,
      'REGENY EV CHARGING',
      after: const Duration(minutes: 5),
      ch: TxnSource.appleShortcut,
    );
    expect(again.status, IngestStatus.merged);
    expect(await live(), hasLength(1));
  });

  test('an unsettled hold stops counting after a week', () async {
    await pay(10000, 'REGENY EV CHARGING');
    now = now.add(const Duration(days: 8));
    await pay(2500, 'Starbucks', after: Duration.zero);
    final rows = await live();
    expect(rows.map((r) => r.merchantRaw), ['Starbucks']);
  });

  test('ordinary merchants are untouched: a round AED 100 and a later 14.85 stay two purchases', () async {
    await pay(10000, 'Spinneys');
    await pay(1485, 'Spinneys', after: const Duration(hours: 2));
    final rows = await live();
    expect(rows, hasLength(2));
    expect(rows.every((r) => !r.excludeFromBudget), isTrue);
  });
}
