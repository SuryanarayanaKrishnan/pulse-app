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
import 'package:pulse/features/tour/tab_tip.dart';
import 'package:pulse/features/tour/tour_progress.dart';

Future<void> pumpApp(
  WidgetTester tester,
  Size logical,
  double dpr, {
  MemoryKvStore? kv,
  bool dark = false,
}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = logical * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tourKvProvider.overrideWithValue(kv ?? MemoryKvStore()),
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
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> waitForTip(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    // One at a time, at every frame.
    expect(
      find.byKey(const Key('tab_tip')).evaluate().length,
      lessThanOrEqualTo(1),
    );
  }
}

void main() {
  const sizes = {
    '390x844': (Size(390, 844), 3.0),
    '360x640': (Size(360, 640), 2.0),
  };
  final tabs = <TipTab, (String, List<Finder> Function())>{
    TipTab.home: (
      'Home',
      () => [
        find.text('Safe to spend today'),
        find.text('Good morning').hitTestable(),
      ],
    ),
    TipTab.cards: (
      'Cards',
      () => [find.byIcon(Icons.bolt_rounded), find.byIcon(Icons.add_rounded)],
    ),
    TipTab.splits: ('Splits', () => [find.byIcon(Icons.add_rounded)]),
    TipTab.wealth: ('Wealth', () => [find.byIcon(Icons.add_rounded)]),
  };

  for (final MapEntry(key: label, value: (size, dpr)) in sizes.entries) {
    for (final MapEntry(key: tab, value: (name, keys)) in tabs.entries) {
      testWidgets('$name tip at $label sits clear of content, one at a time', (
        tester,
      ) async {
        // The other tips are already seen, so this tab's is the one due.
        final kv = MemoryKvStore();
        for (final t in TipTab.values) {
          if (t != tab) kv.data['tips.seen.${t.key}'] = '1';
        }
        await pumpApp(tester, size, dpr, kv: kv);
        if (tab != TipTab.home) {
          await tester.tap(find.text(name).last);
        }
        await waitForTip(tester);
        // It is docked, and it is the only one.
        expect(find.text(tabTipCopy[tab]!), findsOneWidget);
        expect(find.byKey(const Key('tab_tip')), findsOneWidget);
        final tip = tester.getRect(find.byKey(const Key('tab_tip')));
        final screen = Offset.zero & size;
        expect(
          screen.contains(tip.topLeft) &&
              screen.contains(tip.bottomRight - const Offset(.1, .1)),
          isTrue,
        );

        // Layout space is reserved: the tab content ends where the tip begins.
        final body = tester.getRect(
          find
              .descendant(
                of: find.byType(TipDock),
                matching: find.byType(Scrollable).first,
              )
              .first,
        );
        expect(
          body.bottom,
          lessThanOrEqualTo(tip.top + .5),
          reason: 'content is pushed, not covered',
        );

        // And none of the key widgets on this tab is under it.
        for (final f in keys()) {
          for (final e in f.evaluate()) {
            final r = tester.getRect(find.byElementPredicate((x) => x == e));
            expect(r.overlaps(tip), isFalse, reason: '$f at $r vs tip $tip');
          }
        }
        // The tab bar is not covered either, and the tip points at its tab.
        final bar = tester.getRect(find.text(name).last);
        expect(tip.bottom, lessThanOrEqualTo(bar.top));
        // Tapping the content still works with the tip showing.
        await tester.tap(find.byKey(const Key('tab_tip')));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byKey(const Key('tab_tip')), findsNothing);
        expect(
          ProviderScope.containerOf(tester.element(find.byType(PulseApp)))
              .read(tourProgressProvider)
              .tipSeen(tab),
          isTrue,
        );
      });
    }
  }
}
