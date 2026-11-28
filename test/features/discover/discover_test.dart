import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/features/discover/feature_catalog.dart';
import 'package:pulse/features/discover/feature_shortcuts.dart';
import 'package:pulse/features/recurring/recurring_screen.dart';
import 'package:pulse/features/coach/coach_progress.dart';
import 'package:pulse/features/tour/tab_tip.dart';
import 'package:pulse/features/tour/tour_progress.dart';

Future<void> _pump(
  WidgetTester tester,
  String location, {
  Size size = const Size(390, 844),
  double dpr = 3,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  MemoryKvStore? kv,
}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tourKvProvider.overrideWithValue(kv ?? seenAll()),
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
      child: PulseApp(initialLocation: location),
    ),
  );
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

MemoryKvStore seenAll() {
  final kv = MemoryKvStore()..data['tour.seen'] = '1';
  for (final t in TipTab.values) {
    kv.data['tips.seen.${t.key}'] = '1';
  }
  for (final s in CoachScreen.values) {
    kv.data['coach.seen.${s.key}'] = '1';
  }
  return kv;
}

void main() {
  test('search finds features by what people call them', () {
    PulseFeature? first(String q) =>
        pulseFeatures.where((f) => f.matches(q)).firstOrNull;
    expect(first('repeat')?.id, 'recurring');
    expect(first('joint')?.id, 'household');
    expect(first('best moves')?.id, 'combos');
    expect(first('zzzz'), isNull);
    // Where do I turn Gmail on or off, and where is dark mode?
    expect(first('gmail')?.id, 'connections');
    expect(first('dark')?.id, 'look');
    expect(first('salary')?.id, 'salary');
    expect(
      pulseFeatures.where((f) => f.matches('')).length,
      pulseFeatures.length,
    );
  });

  testWidgets('budget surfaces Recurring and Household up top', (tester) async {
    await _pump(tester, '/budget');
    expect(find.byKey(const Key('shortcut-recurring')), findsOneWidget);
    expect(find.byKey(const Key('shortcut-household')), findsOneWidget);
    expect(find.byKey(const Key('shortcut-all')), findsOneWidget);
    await tester.tap(find.byKey(const Key('shortcut-recurring')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(RecurringScreen), findsOneWidget);
  });

  testWidgets('searching "gmail" finds the Connections switch screen', (
    tester,
  ) async {
    await _pump(tester, '/home');
    await tester.tap(find.byKey(const Key('home-all-features')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.enterText(find.byKey(const Key('features-search')), 'gmail');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('feature-connections')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const Key('connection_gmail_switch')), findsOneWidget);
  });

  testWidgets('wealth surfaces Household; Goals is a tile', (tester) async {
    await _pump(tester, '/wealth');
    expect(find.byKey(const Key('shortcut-goals')), findsNothing);
    expect(find.byKey(const Key('shortcut-household')), findsOneWidget);
  });

  testWidgets('All features opens from Home, searches and navigates', (
    tester,
  ) async {
    await _pump(tester, '/home');
    await tester.tap(find.byKey(const Key('home-all-features')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const Key('features-search')), findsOneWidget);
    expect(find.byKey(const Key('feature-household')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('features-search')), 'repeat');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('feature-recurring')), findsOneWidget);
    expect(find.byKey(const Key('feature-household')), findsNothing);
    await tester.tap(find.byKey(const Key('feature-recurring')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byKey(const Key('features-search')), findsNothing);
    expect(find.byType(RecurringScreen), findsOneWidget);
  });

  testWidgets('first Budget visit shows the discovery tip', (tester) async {
    final kv = seenAll()..data.remove('tips.seen.budget');
    await _pump(tester, '/budget', kv: kv);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(tabTipCopy[TipTab.budget]!), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'shortcuts and sheet hold at 360px, text 1.5 (${dark ? 'dark' : 'light'})',
      (tester) async {
        PulseTheme.useGoogleFonts = false;
        tester.view.physicalSize = const Size(360, 640) * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: PulseTheme.light,
            darkTheme: PulseTheme.dark,
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => ListView(
                  children: const [
                    FeatureShortcuts(ids: ['recurring', 'household']),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byKey(const Key('shortcut-recurring')), findsOneWidget);
        expect(find.byKey(const Key('shortcut-all')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('shortcut-all')));
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byKey(const Key('features-search')), findsOneWidget);
        await tester.dragUntilVisible(
          find.byKey(const Key('feature-settings')),
          find.byType(ListView).last,
          const Offset(0, -200),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
