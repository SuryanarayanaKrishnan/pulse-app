import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';

Future<void> _pump(WidgetTester tester, {String? location}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets(
    'home is calm: safe to spend, which card, nothing else by default',
    (tester) async {
      await _pump(tester);
      expect(find.text('Safe to spend today'), findsOneWidget);
      expect(find.text('Which card should I use?'), findsOneWidget);
      // Everything else is opt-in.
      expect(find.textContaining('Financial health'), findsNothing);
      expect(find.text('Recent'), findsNothing);
      expect(find.text('Best moves'), findsNothing);
      expect(find.text('Family'), findsNothing);
      expect(find.text('Monthly close'), findsNothing);
      expect(find.byKey(const Key('capture_nudge')), findsNothing);
      // At most one insight card sits under the card advice, and each kind is
      // drawn once.
      expect(
        find.byKey(const Key('cap_watch')).evaluate().length,
        lessThanOrEqualTo(1),
      );
      expect(
        find.byKey(const Key('overrun_home_line')).evaluate().length,
        lessThanOrEqualTo(1),
      );
      // The way to more is one obvious button.
      expect(find.byKey(const Key('home-add-widget')), findsOneWidget);
    },
  );

  testWidgets('which card sheet recommends a card for a category', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Which card should I use?'));
    await tester.pumpAndSettle();
    expect(find.text('Live rates, after this month\'s caps'), findsOneWidget);
    await tester.tap(find.text('Dining & Delivery').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Next best'), findsOneWidget);
  });

  testWidgets('budget tab shows status, automatic share and cashflow', (
    tester,
  ) async {
    await _pump(tester, location: '/budget');
    expect(
      find.textContaining(RegExp('On track|Nearing limit|Over')),
      findsWidgets,
    );
    expect(find.textContaining('automatic'), findsOneWidget);
    // The cash-flow forecast is one page of the chart card.
    final dot = find.byKey(const Key('chart-dot-forecast'));
    await tester.dragUntilVisible(
      dot,
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await Scrollable.ensureVisible(tester.element(dot), alignment: 0.4);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(dot);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Cash-flow forecast'), findsOneWidget);
    expect(find.textContaining('Projected on'), findsOneWidget);
  });

  testWidgets('wallet stack opens card detail, swipes and returns', (
    tester,
  ) async {
    await _pump(tester, location: '/cards');
    expect(find.text('Total due'), findsOneWidget);
    expect(find.text('Your cards'), findsOneWidget);
    await tester.tap(find.text('Emirates NBD').first);
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Emirates NBD Skywards Infinite'), findsOneWidget);
    expect(find.text('Earned this month'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.text('Mashreq Cashback Card'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsNothing);
    expect(find.text('Your cards'), findsOneWidget);
  });

  testWidgets('accounts segment shows total balance and opens an account', (
    tester,
  ) async {
    await _pump(tester, location: '/cards');
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('Total balance'), findsOneWidget);
    await tester.tap(find.text('Emirates NBD').first);
    await tester.pumpAndSettle();
    expect(find.text('Emirates NBD Current'), findsWidgets);
    expect(find.text('In this month'), findsOneWidget);
  });

  testWidgets('ranked page sorts and shows best card per category', (
    tester,
  ) async {
    await _pump(tester, location: '/cards-ranked');
    expect(find.text('Best card for each category'), findsOneWidget);
    await tester.tap(find.text('Return'));
    await tester.pumpAndSettle();
    expect(find.textContaining('a month of the annual fee'), findsOneWidget);
  });

  testWidgets('simulated card tap shows the rewards moment', (tester) async {
    await _pump(tester, location: '/settings/help');
    await tester.dragUntilVisible(
      find.text('Simulate a card tap'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.ensureVisible(find.text('Simulate a card tap'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Simulate a card tap'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('at Talabat'), findsOneWidget);
    await tester.tap(find.textContaining('at Talabat'));
    await tester.pumpAndSettle();
    expect(find.text('Rewards earned'), findsOneWidget);
    expect(find.textContaining('Cap reached'), findsWidgets);
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('family lists members and the family vault opens', (
    tester,
  ) async {
    await _pump(tester, location: '/family');
    expect(find.text('Just you so far'), findsOneWidget);
    expect(find.text('Khalid'), findsNothing);
    expect(find.text('Invite someone'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Family vault'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.tap(find.text('Family vault'));
    await tester.pumpAndSettle();
    expect(
      find.text('A calm place for the things your family would need to find.'),
      findsOneWidget,
    );
  });
}
