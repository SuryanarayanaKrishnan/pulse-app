import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse/backup/backup_keystore.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/sync/sync_engine.dart';
import 'package:pulse/core/sync/sync_state.dart';
import 'package:pulse/core/sync/sync_transport.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/features/sync/sync_screen.dart';
import 'package:pulse/sync/sync_providers.dart';
import 'package:pulse/sync/sync_service.dart';

import 'support.dart';

class _Rec extends NoopAnalytics {
  final events = <AnalyticsEvent>[];
  @override
  void track(AnalyticsEvent event) => events.add(event);
}

void main() {
  late _Rec analytics;
  late MemoryKvStore kv;
  late MemoryBackupKeyStore keys;
  late MemorySyncTransport server;
  late Device phone;

  setUp(() {
    analytics = _Rec();
    kv = MemoryKvStore();
    keys = MemoryBackupKeyStore();
    server = MemorySyncTransport();
    phone = Device('aaaa', server);
  });

  SyncService real({SyncTransport? transport}) {
    final t = transport ?? server;
    return SyncService(
      kv: kv,
      keys: keys,
      transport: t,
      analytics: analytics,
      engineFor: (k) => SyncEngine(
        bridge: phone.bridge,
        transport: t,
        store: MemorySyncStateStore(),
        dataKey: k,
      ),
    );
  }

  test('without a backup key: not available, and a manual sync fails calmly', () async {
    final svc = real();
    await svc.load();
    expect(svc.status.available, isFalse);
    expect(await svc.syncNow(), isFalse);
    expect(svc.status.lastError, contains('backup'));
    expect(analytics.events.map((e) => e.name), ['sync_started', 'sync_failed']);
    expect(analytics.events.last.properties, {'trigger': 'manual', 'reason': 'keys_missing'});
    svc.dispose();
  });

  test('a good run reports started and completed with no content', () async {
    keys.key = testKey;
    phone.bridge.put('transactions', 't1', {'id': 't1', 'merchant_raw': 'SECRETSHOP'});
    final svc = real();
    await svc.load();
    expect(svc.status.available, isTrue);
    expect(await svc.syncNow(), isTrue);
    expect(svc.status.lastSuccess, isNotNull);
    expect(svc.status.lastError, isNull);
    expect(svc.status.running, isFalse);
    expect(analytics.events.map((e) => e.name), ['sync_started', 'sync_completed']);
    for (final e in analytics.events) {
      expect(e.properties.values.every((v) => v is String || v is int || v is bool), isTrue);
      expect('${e.properties}'.contains('SECRETSHOP'), isFalse);
    }
    expect(analytics.events.last.properties['changes_bucket'], 'few');
    expect(await kv.read(SyncService.lastSuccessKey), isNotNull);
    svc.dispose();
  });

  test('a failing transport is classified, not leaked', () async {
    keys.key = testKey;
    phone.bridge.put('transactions', 't1', {'id': 't1'});
    server.failWrites = TimeoutException('secret detail');
    final svc = real();
    await svc.load();
    expect(await svc.syncNow(), isFalse);
    expect(analytics.events.last.name, 'sync_failed');
    expect(analytics.events.last.properties, {'trigger': 'manual', 'reason': 'offline'});
    expect(svc.status.lastError, isNot(contains('secret')));
    server.failWrites = null;
    expect(await svc.syncNow(), isTrue);
    expect(svc.status.lastError, isNull);
    svc.dispose();
  });

  test('turning it on persists and starts a sync; off stops automatic runs', () async {
    keys.key = testKey;
    final svc = real();
    await svc.load();
    expect(svc.status.enabled, isFalse);
    await svc.setEnabled(true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await kv.read(SyncService.enabledKey), '1');
    expect(analytics.events.any((e) => e.name == 'sync_completed'), isTrue);
    await svc.setEnabled(false);
    expect(svc.status.enabled, isFalse);
    svc.dispose();
  });

  test('error classes map to short reasons', () {
    expect(classifySyncError(const SyncException('too_new')).reason, 'too_new');
    expect(classifySyncError(const SyncException('integrity')).reason, 'integrity');
    expect(classifySyncError(const SyncUnavailable('x')).reason, 'signed_out');
    expect(classifySyncError(StateError('boom')).reason, 'other');
  });

  group('screen', () {
    Future<void> pump(WidgetTester tester, SyncStatus s) async {
      PulseTheme.useGoogleFonts = false;
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            syncStatusProvider.overrideWith(() => _FixedStatus(s)),
            syncServiceProvider.overrideWithValue(null),
          ],
          child: MaterialApp.router(
            theme: PulseTheme.light,
            routerConfig: GoRouter(
              routes: [
                GoRoute(path: '/', builder: (_, _) => SyncScreen(now: DateTime(2026, 1, 1, 12, 10))),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('without backup it explains what is needed', (tester) async {
      await pump(tester, const SyncStatus());
      expect(find.text('Backup comes first'), findsOneWidget);
      expect(find.text('Sync now'), findsNothing);
    });

    testWidgets('with backup it shows status, Sync now and the switch', (tester) async {
      await pump(
        tester,
        SyncStatus(available: true, enabled: true, lastSuccess: DateTime(2026, 1, 1, 12, 7), lastSent: 2, lastReceived: 1),
      );
      expect(find.text('Synced 3 min ago'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('a failed run is explained calmly', (tester) async {
      await pump(
        tester,
        const SyncStatus(available: true, enabled: true, lastError: "You're offline. Changes sync when you're back."),
      );
      expect(find.text('Last attempt did not finish'), findsOneWidget);
      expect(find.textContaining("You're offline"), findsOneWidget);
    });

    test('settings row subtitles', () {
      final now = DateTime(2026, 1, 1, 12);
      expect(syncSubtitle(const SyncStatus(), now), contains('encrypted backup'));
      expect(syncSubtitle(const SyncStatus(available: true), now), 'Off');
      expect(syncSubtitle(const SyncStatus(available: true, enabled: true, running: true), now), 'Syncing...');
      expect(
        syncSubtitle(SyncStatus(available: true, enabled: true, lastSuccess: DateTime(2026, 1, 1, 11)), now),
        'Synced 1 h ago',
      );
    });
  });
}

class _FixedStatus extends SyncStatusNotifier {
  _FixedStatus(this.s);
  final SyncStatus s;
  @override
  SyncStatus build() => s;
}
