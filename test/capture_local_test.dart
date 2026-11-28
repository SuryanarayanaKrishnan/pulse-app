import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/apple_shortcut.dart';
import 'package:pulse/capture/capture_confirmation.dart';
import 'package:pulse/capture/capture_platform.dart';
import 'package:pulse/capture/capture_service.dart';
import 'package:pulse/capture/captured_event.dart';
import 'package:pulse/capture/ingest_queue.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/screenshot_text.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';
import 'package:pulse/data/models.dart';

import 'capture_test.dart' show FakePlatform;

/// The whole capture path with no server: native buffer -> offline queue ->
/// on-device pipeline -> encrypted ledger.
class Rig {
  late PulseDatabase db;
  late IngestPipeline pipeline;
  late LocalPulseRepository repo;
  late IngestQueue queue;
  late CaptureService service;
  final kv = MemoryKvStore();

  Future<void> init(CapturePlatform platform) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = PulseDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = CatalogService(
      db: db,
      bundled: () async =>
          File('test/fixtures/catalog/cards_small.json').readAsStringSync(),
    );
    await catalog.loadBundled();
    pipeline = IngestPipeline(db, clock: () => DateTime.utc(2026, 3, 12, 8));
    addTearDown(pipeline.dispose);
    repo = LocalPulseRepository(
      db: db,
      catalog: catalog,
      pipeline: pipeline,
      clock: () => DateTime.utc(2026, 3, 12, 8),
    );
    await repo.addCard(
      catalogId: 'emirates-nbd-skywards-infinite',
      last4: '1234',
      limit: 20000,
    );
    queue = IngestQueue(
      store: kv,
      sender: localIngestSender(pipeline),
      clock: () => DateTime.utc(2026, 3, 12, 9),
    );
    service = CaptureService(
      platform: platform,
      queue: queue,
      kv: kv,
      analytics: NoopAnalytics(),
      clock: () => DateTime.utc(2026, 3, 12, 9),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Android SMS goes native buffer -> queue -> local pipeline, OTP never queued', () async {
    final platform = FakePlatform()
      ..buffer.addAll([
        CapturedEvent(
          id: 'a',
          kind: 'sms',
          sender: 'ENBD',
          body: 'Purchase of AED 45.00 with Credit Card ending 1234 at CARREFOUR, DUBAI.',
          timestamp: DateTime.utc(2026, 3, 12, 9),
        ),
        CapturedEvent(
          id: 'otp',
          kind: 'sms',
          sender: 'ENBD',
          body: 'Your OTP is 123456. Do not share. Purchase of AED 45.00 card ending 1234',
          timestamp: DateTime.utc(2026, 3, 12, 9),
        ),
      ]);
    final r = Rig();
    await r.init(platform);
    await r.service.drain();
    final txs = await r.repo.transactions();
    expect(txs, hasLength(1));
    expect(txs.single.merchant, 'Carrefour');
    expect(txs.single.source, TxSource.sms);
    expect(await r.queue.items(), isEmpty, reason: 'delivered to the pipeline');
    expect(
      platform.acked,
      containsAll(['a', 'otp']),
      reason: 'the OTP is acked so native drops it too',
    );
    final raw = await r.db.select(r.db.rawIngests).get();
    expect(raw.map((e) => e.payload).join(), isNot(contains('123456')));
  });

  test('a wallet notification lands under the wallet channel', () async {
    final platform = FakePlatform()
      ..buffer.add(
        CapturedEvent(
          id: 'n1',
          kind: 'notification',
          app: 'com.google.android.apps.walletnfcrel',
          title: 'Payment',
          body: 'Purchase of AED 12.00 at STARBUCKS with card ending 1234',
          timestamp: DateTime.utc(2026, 3, 12, 9),
        ),
      );
    final r = Rig();
    await r.init(platform);
    await r.service.drain();
    expect(await r.db.select(r.db.transactions).get(), hasLength(1));
    expect(
      (await r.db.select(r.db.transactions).get()).single.source,
      'google_wallet',
    );
  });

  test('the iOS inbox items become payments without a server', () async {
    const channel = MethodChannel('pulse/shortcut_inbox');
    final acked = <String>[];
    final inbox = <Map<String, Object?>>[
      {
        'id': 'u1',
        'amount': 'AED 45.50',
        'merchant': 'Spinneys',
        'card': 'Emirates NBD •••• 1234',
        'ts': DateTime.utc(2026, 3, 12, 9).millisecondsSinceEpoch ~/ 1000,
      },
      {'id': 'bad', 'merchant': 'No amount here'},
    ];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'peekPending':
              return List.of(inbox);
            case 'ackPending':
              final ids = ((call.arguments as Map)['ids'] as List)
                  .cast<String>();
              acked.addAll(ids);
              inbox.removeWhere((e) => ids.contains(e['id']));
              return null;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final platform = AppleInboxCapturePlatform();
    expect(platform.supported, isTrue);
    expect(
      (await platform.status()).supported,
      isFalse,
      reason: 'no SMS permissions on iOS',
    );
    final r = Rig();
    await r.init(platform);
    await r.service.drain();
    expect(acked, containsAll(['u1', 'bad']));
    final txs = await r.repo.transactions();
    expect(txs, hasLength(1));
    expect(txs.single.amount, 45.5);
    expect(txs.single.merchant, 'Spinneys');
    expect(txs.single.category, SpendCategory.groceries);
    expect(txs.single.source, TxSource.applePayShortcut);
    expect(txs.single.accountLabel, 'Emirates NBD ••1234');
    // Draining again changes nothing.
    await r.service.drain();
    expect(await r.repo.transactions(), hasLength(1));
  });

  test(
    'a screenshot capture shows a confirmation and Undo removes it',
    () async {
      final r = Rig();
      await r.init(const UnsupportedCapturePlatform());
      final confirmer = RecordingCaptureConfirmer();
      final send = localIngestSender(r.pipeline, confirmer: confirmer);
      final tx = parseScreenshotText(
        'AED 45.50 spent at CAFE NERO on card ending 1234',
        now: DateTime.utc(2026, 3, 12, 8),
      )!;
      expect(tx.viaScreenshot, isTrue);
      await send(tx.toPending(DateTime.utc(2026, 3, 12, 9)));
      expect(confirmer.shown, hasLength(1));
      expect(confirmer.shown.single.title, 'Logged AED 45.50');
      expect(confirmer.shown.single.body, 'CAFE NERO · card 1234');
      expect(await r.repo.transactions(), hasLength(1));
      expect(
        await undoCapturedTransaction(r.db, confirmer.shown.single.txId),
        isTrue,
      );
      expect(await r.repo.transactions(), isEmpty);
      // A normal Apple Pay capture is not announced.
      final pay = ShortcutTransaction.tryParse(
        Uri.parse('pulse://ingest?amount=10&merchant=Shop&card=1234'),
        now: DateTime.utc(2026, 3, 12, 8),
      )!;
      await send(pay.toPending(DateTime.utc(2026, 3, 12, 9)));
      expect(confirmer.shown, hasLength(1));
    },
  );
}
