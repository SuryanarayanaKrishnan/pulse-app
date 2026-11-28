import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';

Future<void> pumpCards(WidgetTester tester) async {
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

    await tester.tap(find.text('Best combos'));
    await tester.pumpAndSettle();
    expect(find.text('Utilisation'), findsNothing);
  });
}
