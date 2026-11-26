import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/entitlement/entitlement.dart';
import 'package:pulse/core/router/router.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/cards/cards_screen.dart';
import 'package:pulse/features/cards/ranked_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      repositoryProvider.overrideWithValue(
        MockPulseRepository(latency: Duration.zero),
      ),
      analyticsProvider.overrideWithValue(NoopAnalytics()),
      entitlementServiceProvider.overrideWithValue(
        MockEntitlementService(delay: Duration.zero),
      ),
      sessionProvider.overrideWith(
        (ref) =>
            SessionController(onboarded: true, signedIn: true, connected: true),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const PulseApp(initialLocation: '/cards'),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'ranked cards opens over the Cards tab and Back returns to it, one page painted',
    (tester) async {
      await _pump(tester);
      expect(find.text('YOUR WALLET'), findsOneWidget);
      final ctx = tester.element(find.text('YOUR WALLET'));
      // A snackbar is showing, as in the report.
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Moved AED 200'),
          duration: Duration(days: 1),
        ),
      );
      await tester.pump();

      // Double tap on "Ranked" must not stack two pages.
      final ranked = find.text('Ranked');
      await tester.ensureVisible(ranked);
      await tester.tap(ranked);
      await tester.tap(ranked, warnIfMissed: false);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.pumpAndSettle();
      expect(find.byType(RankedCardsScreen), findsOneWidget);
      expect(find.byType(CardsScreen), findsNothing); // tab page not painted
      expect(
        GoRouter.of(tester.element(find.byType(RankedCardsScreen)))
            .state
            .uri
            .path,
        Routes.cardsRanked,
      );

      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(RankedCardsScreen), findsNothing);
      expect(find.byType(CardsScreen), findsOneWidget);
      expect(
        find.text('Cards worth having').evaluate().length,
        lessThanOrEqualTo(1),
      );
      expect(find.text('Card combos').evaluate().length, lessThanOrEqualTo(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Back on ranked cards opened without history goes to the Cards tab, not Home',
    (tester) async {
      await _pump(tester);
      final ctx = tester.element(find.text('YOUR WALLET'));
      GoRouter.of(ctx).go(Routes.cardsRanked);
      await tester.pumpAndSettle();
      expect(find.byType(RankedCardsScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(RankedCardsScreen), findsNothing);
      expect(find.byType(CardsScreen), findsOneWidget);
    },
  );
}
