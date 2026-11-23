import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/apple_shortcut.dart';
import 'package:pulse/capture/capture_config.dart';
import 'package:pulse/capture/capture_platform.dart';
import 'package:pulse/capture/capture_service.dart';
import 'package:pulse/capture/captured_event.dart';
import 'package:pulse/capture/ingest_queue.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/data/api/ingest_api.dart';

class RecordingAnalytics extends NoopAnalytics {
  final events = <String>[];
  @override
  void track(AnalyticsEvent e) =>
      events.add('${e.name}:${e.properties['permission'] ?? ''}');
}

class FakePlatform implements CapturePlatform {
  CaptureStatus current = const CaptureStatus(supported: true);
  CaptureStatus afterRequest = const CaptureStatus(
    supported: true,
    smsReceive: true,
    smsRead: true,
  );
  final buffer = <CapturedEvent>[];
  final acked = <String>[];
  int backfills = 0;
  int? backfillDays;
  final controller = StreamController<void>.broadcast();
  CaptureConfig? configured;

  @override
  bool get supported => true;
  @override
  Stream<void> get onPending => controller.stream;
  @override
  Future<CaptureStatus> status() async => current;
  @override
  Future<CaptureStatus> requestSmsPermissions() async => current = afterRequest;
  @override
  Future<void> openNotificationAccessSettings() async {}
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> configure(CaptureConfig config) async => configured = config;
  @override
  Future<int> backfillSms({required int days}) async {
    backfills++;
    backfillDays = days;
    buffer.add(sms('old', DateTime(2026, 9, 1)));
    return 1;
  }

  @override
  Future<List<CapturedEvent>> peekPending() async => List.of(buffer);
  @override
  Future<void> ackPending(List<String> ids) async {
    acked.addAll(ids);
    buffer.removeWhere((e) => ids.contains(e.id));
  }
}

CapturedEvent sms(String id, DateTime ts) => CapturedEvent(
  id: id,
  kind: 'sms',
  body: 'AED 45.00 spent at STARBUCKS card 4821',
  sender: 'ADCBAlert',
  timestamp: ts,
);

void main() {
  late FakePlatform platform;
  late MemoryKvStore kv;
  late RecordingAnalytics analytics;
  late List<String> uploaded;
  late CaptureService service;

  setUp(() {
    platform = FakePlatform();
    kv = MemoryKvStore();
    analytics = RecordingAnalytics();
    uploaded = [];
    final queue = IngestQueue(
      store: kv,
      sender: (i) async {
        uploaded.add(i.id);
        return SendOutcome.sent;
      },
    );
    service = CaptureService(
      platform: platform,
      queue: queue,
      kv: kv,
      analytics: analytics,
      flushInterval: const Duration(days: 1),
    );
  });
  tearDown(() => service.dispose());

  test('CapturedEvent maps to ingest payloads', () {
    final s = sms(
      's1',
      DateTime.utc(2026, 11, 20, 8),
    ).toPending(DateTime.utc(2026, 11, 20, 9));
    expect(s.channel, IngestChannel.sms);
    expect(s.payload['sender'], 'ADCBAlert');
    expect(s.payload['external_id'], 's1');
    expect(s.payload['received_at'], '2026-11-20T08:00:00.000Z');
    expect(s.payload.containsKey('app_name'), isFalse);

    final n = CapturedEvent.fromMap({
      'id': 'n1',
      'kind': 'notification',
      'body': 'AED 12 at Cafe',
      'title': 'Google Wallet',
      'app': 'com.google.android.apps.walletnfcrel',
      'ts': 1763625600000,
    }).toPending(DateTime.utc(2026));
    expect(n.channel, IngestChannel.notification);
    expect(n.payload['title'], 'Google Wallet');
    expect(n.payload['app_name'], 'com.google.android.apps.walletnfcrel');
    expect(n.payload.containsKey('sender'), isFalse);
  });

  test(
    'start configures, drains the native buffer, acks and uploads',
    () async {
      platform.buffer.add(sms('a', DateTime(2026, 11, 20)));
      await service.start();
      expect(platform.configured, isNotNull);
      expect(platform.acked, ['a']);
      expect(uploaded, ['a']);
    },
  );

  test('live events trigger a drain', () async {
    await service.start();
    platform.buffer.add(sms('live', DateTime(2026, 11, 21)));
    platform.controller.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(uploaded, ['live']);
  });

  test(
    'requesting SMS permission tracks analytics then backfills once',
    () async {
      await service.start();
      expect(platform.backfills, 0, reason: 'no READ_SMS yet');
      final s = await service.requestSmsPermissions();
      expect(s.smsGranted, isTrue);
      expect(
        analytics.events,
        containsAll([
          'permission_granted:sms_receive',
          'permission_granted:sms_read',
        ]),
      );
      expect(platform.backfills, 1);
      expect(platform.backfillDays, 90);
      expect(uploaded, ['old']);
      // Second request and restart do not backfill again.
      await service.requestSmsPermissions();
      await service.backfillIfNeeded();
      expect(platform.backfills, 1);
    },
  );

  test('denied permission is tracked and does not backfill', () async {
    platform.afterRequest = const CaptureStatus(
      supported: true,
      smsPermanentlyDenied: true,
    );
    final s = await service.requestSmsPermissions();
    expect(s.smsPermanentlyDenied, isTrue);
    expect(
      analytics.events,
      containsAll([
        'permission_denied:sms_receive',
        'permission_denied:sms_read',
      ]),
    );
    expect(platform.backfills, 0);
  });

  test(
    'notification access result is tracked when returning from settings',
    () async {
      const before = CaptureStatus(supported: true);
      platform.current = const CaptureStatus(
        supported: true,
        notificationAccess: true,
      );
      final s = await service.onReturnedFromNotificationSettings(before);
      expect(s.notificationAccess, isTrue);
      expect(analytics.events, ['permission_granted:notification_access']);

      platform.current = const CaptureStatus(supported: true);
      await service.onReturnedFromNotificationSettings(before);
      expect(analytics.events.last, 'permission_denied:notification_access');
    },
  );

  test('unsupported platforms do nothing', () async {
    final q = IngestQueue(store: kv, sender: (_) async => SendOutcome.sent);
    final s = CaptureService(
      platform: const UnsupportedCapturePlatform(),
      queue: q,
      kv: kv,
      analytics: analytics,
    );
    await s.start();
    expect((await s.status()).supported, isFalse);
    expect(await s.backfillIfNeeded(), 0);
  });

  group('Apple Shortcut deep link', () {
    test('parses amount, merchant and card', () {
      final t = ShortcutTransaction.tryParse(
        Uri.parse(
          'pulse://ingest?amount=45.50&merchant=Starbucks%20Mall&card=Emirates%20NBD%20%E2%80%A2%E2%80%A2%E2%80%A2%E2%80%A2%204821&ts=1763625600',
        ),
      )!;
      expect(t.amountMinor, 4550);
      expect(t.merchant, 'Starbucks Mall');
      expect(t.last4, '4821');
      expect(t.currency, 'AED');
      expect(t.direction, 'debit');
      expect(t.timestamp.toUtc(), DateTime.utc(2025, 11, 20, 8));
    });

    test('amount formats', () {
      int? minor(String a) {
        final p = ShortcutTransaction.parseAmount(a);
        return p == null ? null : (p.$1 * 100).round();
      }

      expect(minor('AED 1,234.50'), 123450);
      expect(minor('1.234,50'), 123450);
      expect(minor('45,50'), 4550);
      expect(minor('1,200'), 120000);
      expect(minor('abc'), isNull);
      expect(minor('0'), isNull);
      expect(ShortcutTransaction.parseAmount('USD 12.00')!.$2, 'USD');
    });

    test('rejects other hosts and missing amounts', () {
      expect(
        ShortcutTransaction.tryParse(Uri.parse('pulse://settings')),
        isNull,
      );
      expect(
        ShortcutTransaction.tryParse(Uri.parse('pulse://ingest?merchant=x')),
        isNull,
      );
      expect(
        ShortcutTransaction.tryParse(Uri.parse('pulse:///ingest?amount=5')),
        isNotNull,
      );
    });

    test('builds a structured apple-shortcut payload with a stable id', () {
      final uri = Uri.parse(
        'pulse://ingest?amount=12&merchant=Cafe&card=Visa%201234&ts=1763625600',
      );
      final a = ShortcutTransaction.tryParse(uri)!;
      final b = ShortcutTransaction.tryParse(uri)!;
      expect(a.externalId, b.externalId);
      expect(a.externalId.length, lessThanOrEqualTo(128));
      final p = a.toPending(DateTime.utc(2026));
      expect(p.channel, IngestChannel.appleShortcut);
      final f = p.payload['fields']! as Map;
      expect(f['amount_minor'], 1200);
      expect(f['merchant'], 'Cafe');
      expect(f['last4'], '1234');
      expect(p.payload['raw_text'], contains('Cafe'));
    });
  });

  test('ingest token is generated once and persisted', () async {
    final store = IngestTokenStore(kv);
    final t = await store.token();
    expect(t, startsWith('pls_'));
    expect(t.length, greaterThan(40));
    expect(await IngestTokenStore(kv).token(), t);
    expect(await store.rotate(), isNot(t));
  });
}
