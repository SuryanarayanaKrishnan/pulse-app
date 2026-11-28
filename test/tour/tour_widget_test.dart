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
  'Always the right card',
  'It fills itself in',
  'Everything adds up',
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
      'with sample data or a fresh start', (tester) async {
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
    expect(find.textContaining('Restore it'), findsOneWidget);
    expect(find.text('Try with sample data'), findsOneWidget);
    // One page of value, no further intro pages.
    expect(find.text('Continue'), findsNothing);
    expect(find.textContaining('Start fresh'), findsOneWidget);
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
    // A dock in front of [tab], with every tab's target registered.
    Widget host(
      KvStore kv,
      ValueNotifier<TipTab> tab, {
      bool reduced = false,
    }) => _app(
      ValueListenableBuilder<TipTab>(
        valueListenable: tab,
        builder: (_, t, _) => Scaffold(
          body: TipDock(
            current: t,
            delay: const Duration(milliseconds: 50),
            visibleFor: const Duration(seconds: 3),
            child: Column(
              children: [
                for (final k in TipTab.values)
                  TabTip(
                    tab: k,
                    child: SizedBox(height: 40, child: Text('target ${k.key}')),
                  ),
              ],
            ),
          ),
        ),
      ),
      kv: kv,
      reduced: reduced,
    );

    Finder tip(TipTab t) => find.text(tabTipCopy[t]!);
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('one tip at a time, once per tab, queued for later tabs', (
      tester,
    ) async {
      _phone(tester);
      final kv = MemoryKvStore();
      final tab = ValueNotifier(TipTab.home);
      await tester.pumpWidget(host(kv, tab));
      await settle(tester);
      // Only the tab in front shows its tip.
      expect(tip(TipTab.home), findsOneWidget);
      for (final t in TipTab.values.skip(1)) {
        expect(tip(t), findsNothing, reason: t.key);
        expect(kv.data['tips.seen.${t.key}'], isNull, reason: 'queued');
      }
      expect(find.byKey(const Key('tab_tip')), findsOneWidget);
      // Tapping the tip dismisses it.
      await tester.tap(find.byKey(const Key('tab_tip')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('tab_tip')), findsNothing);
      // Next tab, next tip.
      tab.value = TipTab.cards;
      await tester.pump();
      await settle(tester);
      expect(tip(TipTab.cards), findsOneWidget);
      expect(find.byKey(const Key('tab_tip')), findsOneWidget);
      // Leaving the tab takes its tip away; coming back does not repeat it.
      tab.value = TipTab.home;
      await tester.pump();
      await settle(tester);
      expect(find.byKey(const Key('tab_tip')), findsNothing);
      expect(kv.data['tips.seen.home'], '1');
      expect(kv.data['tips.seen.cards'], '1');

      // A fresh start: already seen, nothing shows.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(host(kv, ValueNotifier(TipTab.cards)));
      await settle(tester);
      expect(find.byKey(const Key('tab_tip')), findsNothing);
    });

    testWidgets(
      'the X and auto-hide dismiss; reduced motion has no animation',
      (tester) async {
        _phone(tester);
        final kv = MemoryKvStore();
        await tester.pumpWidget(
          host(kv, ValueNotifier(TipTab.splits), reduced: true),
        );
        await settle(tester);
        expect(tip(TipTab.splits), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        expect(find.byKey(const Key('tab_tip')), findsNothing);
        // Auto-hide.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          host(MemoryKvStore(), ValueNotifier(TipTab.wealth)),
        );
        await settle(tester);
        expect(tip(TipTab.wealth), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byKey(const Key('tab_tip')), findsNothing);
      },
    );

    testWidgets(
      'touching the marked thing dismisses its tip and does not block it',
      (tester) async {
        _phone(tester);
        var taps = 0;
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: TipDock(
                current: TipTab.cards,
                delay: const Duration(milliseconds: 50),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: TabTip(
                    tab: TipTab.cards,
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
            ),
            kv: MemoryKvStore(),
          ),
        );
        await settle(tester);
        expect(tip(TipTab.cards), findsOneWidget);
        await tester.tap(find.text('go'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(taps, 1);
        expect(find.byKey(const Key('tab_tip')), findsNothing);
      },
    );

    testWidgets('reset tips lets them show again', (tester) async {
      _phone(tester);
      final kv = MemoryKvStore()..data['tips.seen.home'] = '1';
      await tester.pumpWidget(host(kv, ValueNotifier(TipTab.home)));
      await settle(tester);
      expect(tip(TipTab.home), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );
      await container.read(tourProgressProvider.notifier).resetTips();
      await settle(tester);
      expect(tip(TipTab.home), findsOneWidget);
      await tester.pump(const Duration(seconds: 12));
    });
  });

  testWidgets(
    'real shell: Home tip docks above the tab bar, then the Budget one follows',
    (tester) async {
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
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(tabTipCopy[TipTab.home]!), findsOneWidget);
      expect(find.byKey(const Key('tab_tip')), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const Key('tab_tip'))).bottom,
        lessThanOrEqualTo(tester.getTopLeft(find.text('Home').last).dy),
      );
      expect(find.text('Safe to spend today'), findsOneWidget);
      expect(kv.data['tips.seen.home'], '1');
      // Move to Budget: its own tip, home's stays seen.
      await tester.tap(find.text('Budget'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(tabTipCopy[TipTab.home]!), findsNothing);
      expect(find.text(tabTipCopy[TipTab.budget]!), findsOneWidget);
      await tester.pump(const Duration(seconds: 12));
    },
  );
}
