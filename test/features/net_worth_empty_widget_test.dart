import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/data/recurring_providers.dart';
import 'package:pulse/features/auth/session.dart';

Future<void> openWealth(WidgetTester tester, List<Asset> assets) async {
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
        recurringTodayProvider.overrideWithValue(const CalDate(2026, 11, 24)),
        assetsProvider.overrideWith((ref) async => assets),
      ],
      child: const PulseApp(initialLocation: '/wealth'),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('Wealth with no assets shows a calm empty state, no exception', (
    tester,
  ) async {
    await openWealth(tester, const []);
    expect(tester.takeException(), isNull);
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Add to Wealth'), findsOneWidget);
  });

  testWidgets('Wealth with assets worth zero does not divide by zero', (
    tester,
  ) async {
    await openWealth(tester, const [
      Asset(id: 'a1', name: 'Empty account', kind: AssetKind.cash, value: 0),
      Asset(id: 'a2', name: 'Spare', kind: AssetKind.other, value: 0),
    ]);
    expect(tester.takeException(), isNull);
    expect(find.text('Allocation'), findsOneWidget);
    // No 0% rows: with nothing to split there is a hint instead.
    expect(find.text('0%'), findsNothing);
    expect(
      find.textContaining('to see how your money is split'),
      findsOneWidget,
    );
    expect(find.textContaining('NaN'), findsNothing);
    expect(find.textContaining('Infinity'), findsNothing);
  });

  testWidgets('Wealth with only liabilities does not throw', (tester) async {
    await openWealth(tester, const [
      Asset(id: 'l1', name: 'Loan', kind: AssetKind.liability, value: 5000),
    ]);
    expect(tester.takeException(), isNull);
  });
}
