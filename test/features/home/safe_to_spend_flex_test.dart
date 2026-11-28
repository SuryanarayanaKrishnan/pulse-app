import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/insights.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';

ProviderContainer demo() {
  final c = ProviderContainer(
    overrides: [
      repositoryProvider.overrideWithValue(
        MockPulseRepository(latency: Duration.zero),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test(
    'demo: Safe to spend is derived from the Budget Flexible left',
    () async {
      final c = demo();
      final plan = await c.read(currentFlexPlanProvider.future);
      final s = await c.read(safeToSpendProvider.future);
      final flexLeft = plan.flex.remainingMinor / 100;
      expect(flexLeft, greaterThan(0));
      expect(s.basis, SafeBasis.flex);
      expect(s.budgetLeft, flexLeft);
      // Flexible left minus bills still to come minus goal set-asides.
      expect(s.available, closeTo(flexLeft - s.bills - s.goals, 0.001));
      expect(
        s.available,
        greaterThan(0),
        reason: 'budget remains, so never a zero',
      );
      expect(s.available, lessThanOrEqualTo(flexLeft));
      expect(s.today, closeTo(s.available / s.daysLeft, 0.001));
    },
  );

  test(
    'withBudget keeps every other figure and only swaps the budget limb',
    () {
      const base = SafeToSpend(
        today: 0,
        available: 0,
        bills: 300,
        cardDues: 1000,
        goals: 200,
        daysLeft: 10,
        cash: 50000,
        budgetLeft: 100,
      );
      final s = base.withBudget(2600, SafeBasis.flex);
      expect(s.available, 2100);
      expect(s.today, 210);
      expect(s.bills, 300);
      expect(s.cardDues, 1000);
      expect(s.goals, 200);
    },
  );

  test('cash still caps Safe to spend below flexible left', () {
    const base = SafeToSpend(
      today: 0,
      available: 0,
      bills: 0,
      cardDues: 4000,
      goals: 0,
      daysLeft: 5,
      cash: 4500,
      budgetLeft: 0,
    );
    expect(base.withBudget(9000, SafeBasis.flex).available, 500);
  });

  testWidgets(
    'Home shows a calm positive number and the sheet explains the link to Budget',
    (tester) async {
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
            kvStoreProvider.overrideWithValue(MemoryKvStore()),
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
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PulseApp)),
      );
      final s = await container.read(safeToSpendProvider.future);
      expect(s.available, greaterThan(0));
      expect(find.text('Safe to spend today'), findsOneWidget);
      expect(find.textContaining('AED 0 '), findsNothing);
      await tester.tap(find.text('Safe to spend today'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sts_budget_left')), findsOneWidget);
      expect(find.text('Flexible left'), findsOneWidget);
      expect(find.byKey(const Key('sts_explain')), findsOneWidget);
    },
  );
}
