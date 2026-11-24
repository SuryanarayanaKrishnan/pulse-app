import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/onboarding/onboarding_screen.dart';
import 'package:pulse/features/tour/tab_tip.dart';
import 'package:pulse/features/tour/tour_progress.dart';
import 'package:pulse/features/tour/tour_screen.dart';

import 'tour_flow_test.dart' show RecordingAnalytics;

Widget _app(
  Widget home, {
  required KvStore kv,
  Analytics? analytics,
  bool reduced = false,
  ThemeMode mode = ThemeMode.light,
}) {
  PulseTheme.useGoogleFonts = false;
  return ProviderScope(
    overrides: [
      tourKvProvider.overrideWithValue(kv),
      analyticsProvider.overrideWithValue(analytics ?? NoopAnalytics()),
      sessionProvider.overrideWith((ref) => SessionController()),
    ],
    child: MaterialApp(
      theme: PulseTheme.light,
      darkTheme: PulseTheme.dark,
      themeMode: mode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: home,
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Tap anywhere; the page slide needs one frame to start, then its length.
Future<void> _advance(WidgetTester tester) async {
  await tester.tapAt(const Offset(200, 500));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

const _headlines = [
  'Your number for today',
  'The right card, every tap',
  'It fills itself in',
  'Everything, as one number',
];

void main() {
  testWidgets('tour renders each moment and ends in onFinished(true)', (
    tester,
  ) async {
    _phone(tester);
    final a = RecordingAnalytics();
    bool? result;
    await tester.pumpWidget(
      _app(
        TourScreen(onFinished: (v) => result = v),
        kv: MemoryKvStore(),
        analytics: a,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < _headlines.length; i++) {
      expect(find.text(_headlines[i]), findsOneWidget, reason: 'step $i');
      expect(find.text('Skip'), findsOneWidget);
      // Every moment is a looping animation of 5 seconds or less.
      await tester.pump(const Duration(milliseconds: 2400));
      if (i < _headlines.length - 1) {
        await _advance(tester);
      }
    }
    expect(find.text('Get started'), findsOneWidget);
    expect(result, isNull);
    await tester.tap(find.text('Get started'));
    await tester.pump();
    expect(result, isTrue);
    expect(a.events.first, 'tour_started');
    expect(a.events.last, 'tour_completed');
    expect(a.events.where((e) => e.startsWith('tour_step_viewed')).length, 4);
  });

  testWidgets('skip leaves at once and reports the step', (tester) async {
    _phone(tester);
    final a = RecordingAnalytics();
    bool? result;
    await tester.pumpWidget(
      _app(
        TourScreen(onFinished: (v) => result = v),
        kv: MemoryKvStore(),
        analytics: a,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await _advance(tester);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(result, isFalse);
    expect(a.events.last, 'tour_skipped:right_card');
  });

  testWidgets('swiping moves between moments', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(TourScreen(onFinished: (_) {}), kv: MemoryKvStore()),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.fling(find.text(_headlines[0]), const Offset(-400, 0), 1500);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text(_headlines[1]), findsOneWidget);
  });

  testWidgets('animations loop normally and hold still with reduced motion', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(TourScreen(onFinished: (_) {}), kv: MemoryKvStore()),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pumpWidget(
      _app(TourScreen(onFinished: (_) {}), kv: MemoryKvStore(), reduced: true),
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Nothing is still moving: the settled frame is shown and stays.
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('AED 199'), findsOneWidget);
    // Advancing jumps rather than slides.
    await tester.tapAt(const Offset(200, 500));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text(_headlines[1]), findsOneWidget);
    expect(find.text('Next time: earn AED 9.30'), findsOneWidget);
  });

  testWidgets('settled frames show the final figures', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _app(TourScreen(onFinished: (_) {}), kv: MemoryKvStore(), reduced: true),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(const Offset(200, 500));
      await tester.pumpAndSettle();
    }
    expect(find.text('AED 482,300'), findsOneWidget);
  });

  testWidgets('onboarding: tour first on a fresh install, then the intro '
      'with Restore from backup', (tester) async {
    _phone(tester);
    final kv = MemoryKvStore();
    await tester.pumpWidget(
      _app(const OnboardingScreen(), kv: kv, reduced: true),
    );
    await tester.pumpAndSettle();
    expect(find.text(_headlines[0]), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Budgets that build themselves'), findsOneWidget);
    expect(find.textContaining('Restore from backup'), findsOneWidget);
    expect(kv.data['tour.seen'], '1');
  });

  testWidgets('onboarding: a returning user goes straight to the intro', (
    tester,
  ) async {
    _phone(tester);
    final kv = MemoryKvStore()..data['tour.seen'] = '1';
    await tester.pumpWidget(
      _app(const OnboardingScreen(), kv: kv, reduced: true),
    );
    await tester.pumpAndSettle();
    expect(find.text(_headlines[0]), findsNothing);
    expect(find.text('Budgets that build themselves'), findsOneWidget);
  });

  group('tab tips', () {
    Widget host(KvStore kv) => _app(
      Scaffold(
        body: Column(
          children: [
            for (final t in TipTab.values)
              TabTip(
                key: ValueKey(t),
                tab: t,
                delay: const Duration(milliseconds: 50),
                visibleFor: const Duration(seconds: 3),
                child: SizedBox(height: 40, child: Text('target ${t.key}')),
              ),
          ],
        ),
      ),
      kv: kv,
    );

    testWidgets('each tab tip appears once, then never again', (tester) async {
      _phone(tester);
      final kv = MemoryKvStore();
      await tester.pumpWidget(host(kv));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 600));
      // Home through Wealth all float one tip each.
      for (final t in TipTab.values) {
        expect(find.text(tabTipCopy[t]!), findsOneWidget, reason: t.key);
        expect(kv.data['tips.seen.${t.key}'], '1');
      }
      // Tapping a tip dismisses it, content stays.
      await tester.tap(find.text(tabTipCopy[TipTab.wealth]!));
      await tester.pump();
      expect(find.text(tabTipCopy[TipTab.wealth]!), findsNothing);
      expect(find.text('target wealth'), findsOneWidget);
      // Fade on their own.
      await tester.pump(const Duration(seconds: 4));
      for (final t in TipTab.values) {
        expect(find.text(tabTipCopy[t]!), findsNothing);
      }

      // A fresh start: already seen, nothing shows.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(host(kv));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 600));
      for (final t in TipTab.values) {
        expect(find.text(tabTipCopy[t]!), findsNothing);
      }
    });

    testWidgets('touching the marked thing dismisses its tip and does not '
        'block it', (tester) async {
      _phone(tester);
      var taps = 0;
      final kv = MemoryKvStore();
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: TabTip(
                tab: TipTab.cards,
                delay: const Duration(milliseconds: 50),
                child: GestureDetector(
                  onTap: () => taps++,
                  child: const SizedBox(
                    width: 100,
                    height: 40,
                    child: Text('go'),
                  ),
                ),
              ),
            ),
          ),
          kv: kv,
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(tabTipCopy[TipTab.cards]!), findsOneWidget);
      await tester.tap(find.text('go'));
      await tester.pump();
      expect(taps, 1);
      expect(find.text(tabTipCopy[TipTab.cards]!), findsNothing);
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets('reset tips lets them show again', (tester) async {
      _phone(tester);
      final kv = MemoryKvStore()..data['tips.seen.home'] = '1';
      await tester.pumpWidget(host(kv));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(tabTipCopy[TipTab.home]!), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );
      await container.read(tourProgressProvider.notifier).resetTips();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(tabTipCopy[TipTab.home]!), findsOneWidget);
      await tester.pump(const Duration(seconds: 12));
    });
  });

  testWidgets('real shell: Home tip appears once, points at the hero', (
    tester,
  ) async {
    _phone(tester);
    final kv = MemoryKvStore();
    PulseTheme.useGoogleFonts = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tourKvProvider.overrideWithValue(kv),
          repositoryProvider.overrideWithValue(
            MockPulseRepository(latency: Duration.zero),
          ),
          analyticsProvider.overrideWithValue(NoopAnalytics()),
          sessionProvider.overrideWith(
            (ref) => SessionController(
              onboarded: true,
              signedIn: true,
              connected: true,
            ),
          ),
        ],
        child: const PulseApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(tabTipCopy[TipTab.home]!), findsOneWidget);
    expect(find.text('Safe to spend today'), findsOneWidget);
    expect(kv.data['tips.seen.home'], '1');
    // Move to Budget: its own tip, home's stays seen.
    await tester.tap(find.text('Budget'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text(tabTipCopy[TipTab.budget]!), findsOneWidget);
    await tester.pump(const Duration(seconds: 12));
  });
}
