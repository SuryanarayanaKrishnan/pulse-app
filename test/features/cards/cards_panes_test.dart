import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/widgets/widgets.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/core/engine/catalog.dart';
import 'package:pulse/core/engine/welcome_offers.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/data/welcome_offers_providers.dart';
import 'package:pulse/features/auth/session.dart';

Future<void> pumpCards(
  WidgetTester tester, {
  List<Override> overrides = const [],
}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        repositoryProvider.overrideWithValue(
          MockPulseRepository(latency: Duration.zero),
        ),
        analyticsProvider.overrideWithValue(NoopAnalytics()),
        kvStoreProvider.overrideWithValue(MemoryKvStore()),
        sessionProvider.overrideWith(
          (ref) => SessionController(
            onboarded: true,
            signedIn: true,
            connected: true,
          ),
        ),
      ],
      child: const PulseApp(initialLocation: '/cards'),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('Cards opens on the wallet; combos and credit are one tap away', (
    tester,
  ) async {
    await pumpCards(tester);
    expect(find.byKey(const Key('cards-pane')), findsOneWidget);
    expect(find.text('Your cards'), findsOneWidget);
    // Not stacked below the wallet any more.
    expect(find.text('Utilisation'), findsNothing);
    expect(find.text('Discover'), findsNothing);

    await tester.tap(find.text('Credit'));
    await tester.pumpAndSettle();
    expect(find.text('Utilisation'), findsWidgets);
    expect(find.text('Your cards'), findsNothing);

    await tester.tap(find.text('Combos'));
    await tester.pumpAndSettle();
    expect(find.text('Utilisation'), findsNothing);
  });

  testWidgets('Offers pane lists welcome bonuses with a deadline and source', (
    tester,
  ) async {
    final c = CatalogCard(
      id: 'x-card',
      issuer: 'Testbank',
      name: 'Gold',
      network: 'visa',
      annualFeeMinor: 0,
      minSalaryMinor: null,
      rewardStructure: const {
        'unit': 'cashback',
        'base_rate': 0.01,
        'rules': [],
      },
      perks: const {},
      verifiedOn: DateTime(2026, 11, 20),
      source: 'https://bank.example/gold',
    );
    await pumpCards(
      tester,
      overrides: [
        welcomeOffersProvider.overrideWith(
          (ref) async => [
            WelcomeOffer(
              card: c,
              text: 'AED 500 cashback',
              evidence: OfferEvidence.bank,
              valueAed: 500,
              validUntil: DateTime(2026, 12, 30),
              daysLeft: 32,
              sourceUrl: c.source,
              checkedOn: c.verifiedOn,
            ),
          ],
        ),
      ],
    );
    await tester.tap(find.text('Offers'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('Apply by'), findsWidgets);
    await tester.tap(find.byType(ListRow).first);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Deadline'), findsOneWidget);
  });
}
