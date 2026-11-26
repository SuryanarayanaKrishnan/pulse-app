import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/capture/apple_shortcut.dart';
import 'package:pulse/capture/capture_config.dart';
import 'package:pulse/capture/capture_platform.dart';
import 'package:pulse/capture/capture_service.dart';
import 'package:pulse/capture/capture_source.dart';
import 'package:pulse/capture/captured_event.dart';
import 'package:pulse/capture/ingest_queue.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/capture/screenshot_text.dart';
import 'package:pulse/capture/shortcut_links.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/router/router.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/features/auth/session.dart';

class _Platform implements CapturePlatform {
  final buffer = <CapturedEvent>[];
  @override
  bool get supported => true;
  @override
  Stream<void> get onPending => const Stream.empty();
  @override
  Future<CaptureStatus> status() async => const CaptureStatus(supported: true);
  @override
  Future<CaptureStatus> requestSmsPermissions() async => status();
  @override
  Future<void> openNotificationAccessSettings() async {}
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> configure(CaptureConfig config) async {}
  @override
  Future<int> backfillSms({required int days}) async => 0;
  @override
  Future<List<CapturedEvent>> peekPending() async => List.of(buffer);
  @override
  Future<void> ackPending(List<String> ids) async =>
      buffer.removeWhere((e) => ids.contains(e.id));
}

ShortcutTransaction _tx({bool screenshot = false, bool nudge = false}) {
  final t = ShortcutTransaction(
    amountMinor: 1200,
    merchant: 'TEST',
    currency: 'AED',
    timestamp: DateTime(2026, 11, 25),
  );
  return screenshot ? t.asScreenshot(nudge: nudge) : t;
}

IngestQueue _queue(KvStore kv) =>
    IngestQueue(store: kv, sender: (_) async => SendOutcome.sent);

void main() {
  group('evaluateTest', () {
    final t0 = DateTime(2026, 1, 1, 12);
    test('idle until started', () {
      expect(
        evaluateTest(startedAt: null, lastSeen: t0, now: t0),
        TestState.idle,
      );
    });
    test('waiting, then failed at the timeout', () {
      expect(
        evaluateTest(
          startedAt: t0,
          lastSeen: null,
          now: t0.add(const Duration(seconds: 29)),
          timeout: const Duration(seconds: 30),
        ),
        TestState.waiting,
      );
      expect(
        evaluateTest(
          startedAt: t0,
          lastSeen: null,
          now: t0.add(const Duration(seconds: 30)),
          timeout: const Duration(seconds: 30),
        ),
        TestState.failed,
      );
    });
    test('an event from before the test does not pass it', () {
      expect(
        evaluateTest(
          startedAt: t0,
          lastSeen: t0.subtract(const Duration(minutes: 5)),
          now: t0.add(const Duration(seconds: 1)),
        ),
        TestState.waiting,
      );
    });
    test('an event after the start passes even past the timeout', () {
      expect(
        evaluateTest(
          startedAt: t0,
          lastSeen: t0.add(const Duration(seconds: 5)),
          now: t0.add(const Duration(minutes: 5)),
        ),
        TestState.passed,
      );
    });
    test('bank SMS waits 30s, others 90s', () {
      expect(CaptureSource.bankSms.testTimeout.inSeconds, 30);
      expect(CaptureSource.wallet.testTimeout.inSeconds, 90);
    });
  });

  group('shortcut links', () {
    test('only real iCloud share links count', () {
      expect(parseShortcutLink(''), isNull);
      expect(
        parseShortcutLink('https://www.icloud.com/shortcuts/REPLACE_WITH_ID'),
        isNull,
      );
      expect(parseShortcutLink('http://www.icloud.com/shortcuts/abc'), isNull);
      expect(parseShortcutLink('https://evil.com/shortcuts/abc'), isNull);
      expect(parseShortcutLink('https://www.icloud.com/shortcuts/'), isNull);
      expect(
        parseShortcutLink('https://www.icloud.com/shortcuts/abc123'),
        isNotNull,
      );
    });
    test('default env has no links set', () {
      const l = ShortcutLinks.fromEnv();
      for (final s in CaptureSource.values) {
        expect(l.has(s), isFalse);
      }
    });
    test('real deep links', () {
      expect(ShortcutDeepLinks.open.toString(), 'shortcuts://');
      expect(
        ShortcutDeepLinks.run('Capture to Pulse').toString(),
        'shortcuts://run-shortcut?name=Capture+to+Pulse',
      );
    });
  });

  group('sources', () {
    test('events are classified by path', () {
      expect(
        CapturedEvent.fromShortcut('a', _tx()).source,
        CaptureSource.wallet,
      );
      expect(
        CapturedEvent.fromShortcut('a', _tx(screenshot: true)).source,
        CaptureSource.screenshot,
      );
      expect(
        CapturedEvent.fromShortcut(
          'a',
          _tx(screenshot: true, nudge: true),
        ).source,
        CaptureSource.nudge,
      );
      expect(
        CapturedEvent(
          id: 's',
          kind: 'sms',
          body: 'x',
          timestamp: DateTime(2026),
        ).source,
        CaptureSource.bankSms,
      );
    });
    test('nudge flag survives screenshot parsing', () {
      const text = 'Order placed. AED 45.00 at Noon';
      expect(parseScreenshotText(text)!.viaNudge, isFalse);
      expect(parseScreenshotText(text, nudge: true)!.viaNudge, isTrue);
    });
    test('service records first and last seen per source', () async {
      final kv = MemoryKvStore();
      final platform = _Platform();
      var now = DateTime.utc(2026, 11, 25, 10);
      final svc = CaptureService(
        platform: platform,
        queue: _queue(kv),
        kv: kv,
        analytics: NoopAnalytics(),
        clock: () => now,
      );
      platform.buffer.add(
        CapturedEvent(
          id: 's1',
          kind: 'sms',
          body: 'Purchase of AED 12.00 at TEST using card ending 0000',
          timestamp: now,
        ),
      );
      await svc.drain();
      expect(await svc.sourceFirstSeen(CaptureSource.bankSms), now);
      expect(await svc.sourceFirstSeen(CaptureSource.wallet), isNull);
      now = now.add(const Duration(minutes: 1));
      platform.buffer.add(
        CapturedEvent(
          id: 's2',
          kind: 'sms',
          body: 'AED 3.00 at X',
          timestamp: now,
        ),
      );
      await svc.drain();
      expect(
        await svc.sourceFirstSeen(CaptureSource.bankSms),
        DateTime.utc(2026, 11, 25, 10),
      );
      expect(await svc.sourceLastSeen(CaptureSource.bankSms), now);
    });
  });

  group('setup screens', () {
    var clock = DateTime.utc(2026);
    Future<(Object, _Platform, List<Uri>)> pump(
      WidgetTester tester, {
      required String at,
      ShortcutLinks? links,
    }) async {
      PulseTheme.useGoogleFonts = false;
      tester.view.physicalSize = const Size(1170, 4400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final session = SessionController(
        onboarded: true,
        signedIn: true,
        connected: true,
      );
      final router = buildRouter(
        session: session,
        analytics: NoopAnalytics(),
        initialLocation: at,
      );
      addTearDown(() {
        router.dispose();
        session.dispose();
      });
      final platform = _Platform();
      clock = DateTime.utc(2026, 11, 25, 10);
      final opened = <Uri>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            kvStoreProvider.overrideWithValue(MemoryKvStore()),
            captureClockProvider.overrideWithValue(() => clock),
            capturePlatformProvider.overrideWithValue(platform),
            urlOpenerProvider.overrideWithValue((u) async {
              opened.add(u);
              return true;
            }),
            if (links != null) shortcutLinksProvider.overrideWithValue(links),
          ],
          child: MaterialApp.router(
            theme: PulseTheme.dark,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      return (0, platform, opened);
    }

    testWidgets('no link: falls back to Shortcuts and shortest steps', (
      tester,
    ) async {
      final (_, _, opened) = await pump(tester, at: Routes.applePaySetup);
      expect(find.text('Open Shortcuts'), findsOneWidget);
      await tester.tap(find.byKey(const Key('install_wallet')));
      await tester.pump();
      expect(opened.single.toString(), 'shortcuts://');
      expect(find.textContaining('Record Payment'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('with a link: one tap opens the iCloud share link', (
      tester,
    ) async {
      final (_, _, opened) = await pump(
        tester,
        at: Routes.applePaySetup,
        links: const ShortcutLinks({
          CaptureSource.wallet: 'https://www.icloud.com/shortcuts/abc',
        }),
      );
      expect(find.text('Add Shortcut'), findsOneWidget);
      await tester.tap(find.byKey(const Key('install_wallet')));
      await tester.pump();
      expect(opened.single.toString(), 'https://www.icloud.com/shortcuts/abc');
      expect(find.textContaining('Pulse Wallet Payment'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Test it: waiting, then passes when the payment arrives', (
      tester,
    ) async {
      final (_, platform, _) = await pump(tester, at: Routes.applePaySetup);
      await tester.tap(find.byKey(const Key('test_wallet')));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('test_status_wallet'))).data,
        contains('Waiting'),
      );
      clock = clock.add(const Duration(seconds: 5));
      platform.buffer.add(CapturedEvent.fromShortcut('w1', _tx()));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('test_status_wallet'))).data,
        contains('It works'),
      );
      expect(find.text('1 of 4 working'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Test it shows a failure hint after the timeout', (
      tester,
    ) async {
      await pump(tester, at: Routes.applePaySetup);
      await tester.tap(find.byKey(const Key('test_wallet')));
      await tester.pump();
      clock = clock.add(const Duration(seconds: 95));
      await tester.pump(const Duration(seconds: 95));
      expect(
        tester.widget<Text>(find.byKey(const Key('test_status_wallet'))).data,
        contains('No payment arrived'),
      );
      expect(find.text('Test again'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Bank SMS guide: one step per screen, test fails after 30s', (
      tester,
    ) async {
      await pump(tester, at: Routes.bankSmsSetup);
      expect(find.text('Step 1 of 6'), findsOneWidget);
      expect(find.byKey(const Key('bank_sms_back')), findsNothing);
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('bank_sms_next')));
        await tester.pump();
      }
      expect(find.text('Step 6 of 6'), findsOneWidget);
      expect(find.textContaining('AED 12.00 at TEST'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bank_sms_test')));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('bank_sms_status'))).data,
        contains('Waiting'),
      );
      clock = clock.add(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 31));
      expect(
        tester.widget<Text>(find.byKey(const Key('bank_sms_status'))).data,
        contains('Nothing arrived after 30 seconds'),
      );
      expect(find.text('Skip for now'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Bank SMS guide step 2 opens Shortcuts', (tester) async {
      final (_, _, opened) = await pump(tester, at: Routes.bankSmsSetup);
      await tester.tap(find.byKey(const Key('bank_sms_next')));
      await tester.pump();
      expect(find.textContaining('Automation at the bottom'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bank_sms_open')));
      await tester.pump();
      expect(opened.single.toString(), 'shortcuts://');
      await tester.pumpWidget(const SizedBox());
    });
  });
}
