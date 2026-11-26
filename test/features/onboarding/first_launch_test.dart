import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/onboarding/start_choice.dart';
import 'package:pulse/features/tour/tour_progress.dart';

/// Pumps the real app root in on-device mode (no backend). The tour is
/// already seen, so the intro is what a first launch lands on.
Future<void> _pump(
  WidgetTester tester, {
  required SessionController session,
  MemoryKvStore? kv,
  Size size = const Size(390, 844),
  double dpr = 3,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final store = kv ?? (MemoryKvStore()..data['tour.seen'] = '1');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tourKvProvider.overrideWithValue(store),
        repositoryProvider.overrideWithValue(
          MockPulseRepository(latency: Duration.zero),
        ),
        analyticsProvider.overrideWithValue(NoopAnalytics()),
        sessionProvider.overrideWith((ref) => session),
      ],
      child: const PulseApp(),
    ),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  final signInText = find.textContaining(
    RegExp('Continue with (Apple|Google)|Email me a code'),
  );

  testWidgets('on-device: one choice, no sign-in, no restore question', (
    tester,
  ) async {
    final store = MemoryKvStore();
    await _pump(
      tester,
      session: SessionController(requireSignIn: false, store: store),
    );
    expect(find.byKey(const Key('start-fresh')), findsOneWidget);
    expect(find.byKey(const Key('try-sample')), findsOneWidget);
    expect(signInText, findsNothing);
    expect(find.text('Restore from backup'), findsNothing);
  });

  testWidgets('sample data goes straight home and is remembered', (
    tester,
  ) async {
    final store = MemoryKvStore();
    final kv = MemoryKvStore()..data['tour.seen'] = '1';
    await _pump(
      tester,
      kv: kv,
      session: SessionController(requireSignIn: false, store: store),
    );
    await tester.tap(find.byKey(const Key('try-sample')));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Safe to spend today'), findsOneWidget);
    expect(signInText, findsNothing);
    expect(kv.data[startChoiceKey], 'sample');
    expect(store.data['session.onboarded'], '1');
    expect(store.data['session.connected'], '1');
  });

  testWidgets('start fresh goes to connect, never to sign-in', (tester) async {
    final kv = MemoryKvStore()..data['tour.seen'] = '1';
    await _pump(
      tester,
      kv: kv,
      session: SessionController(requireSignIn: false),
    );
    await tester.tap(find.byKey(const Key('start-fresh')));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Connect your money'), findsOneWidget);
    expect(signInText, findsNothing);
    expect(kv.data[startChoiceKey], 'fresh');
  });

  testWidgets('a returning person is never asked again', (tester) async {
    final store = MemoryKvStore()
      ..data['session.onboarded'] = '1'
      ..data['session.connected'] = '1';
    final session = await SessionController.load(store, requireSignIn: false);
    await _pump(tester, session: session);
    expect(find.text('Safe to spend today'), findsOneWidget);
    expect(find.byKey(const Key('start-fresh')), findsNothing);
    expect(signInText, findsNothing);
  });

  testWidgets('a feature that needs an account can still ask for sign-in', (
    tester,
  ) async {
    final session = SessionController(
      onboarded: true,
      connected: true,
      requireSignIn: false,
    );
    await _pump(tester, session: session);
    expect(find.text('Safe to spend today'), findsOneWidget);
    session.requestSignIn();
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Email me a code'), findsOneWidget);
  });

  testWidgets('with a backend, sign-in still comes after the intro', (
    tester,
  ) async {
    await _pump(tester, session: SessionController(requireSignIn: true));
    await tester.tap(find.byKey(const Key('start-fresh')));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Email me a code'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'intro fits 360px at text scale 1.5 (${dark ? 'dark' : 'light'})',
      (tester) async {
        await _pump(
          tester,
          session: SessionController(requireSignIn: false),
          size: const Size(360, 640),
          dpr: 2,
          textScale: 1.5,
          brightness: dark ? Brightness.dark : Brightness.light,
        );
        expect(tester.takeException(), isNull);
        // Both choices stay reachable by scrolling.
        await tester.ensureVisible(find.byKey(const Key('try-sample')));
        expect(find.byKey(const Key('try-sample')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
