import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/widgets/widgets.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/home/dashboard/dashboard_controller.dart';
import 'package:pulse/features/home/dashboard/dashboard_layout.dart';

late MockPulseRepository repo;

Future<void> pumpHome(WidgetTester t, {bool allReviewed = false}) async {
  PulseTheme.useGoogleFonts = false;
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  repo = MockPulseRepository(latency: Duration.zero);
  if (allReviewed)
    await repo.setReviewed([
      for (final x in await repo.transactions()) x.id,
    ], true);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        analyticsProvider.overrideWithValue(NoopAnalytics()),
        kvStoreProvider.overrideWithValue(
          MemoryKvStore()
            ..data[DashboardController.storageKey] = DashboardLayout.defaults()
                .withLegacyExtras()
                .encode(),
        ),
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
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('Home shows how many are waiting and opens the stack', (t) async {
    await pumpHome(t);
    final n = (await repo.transactions()).where((x) => !x.reviewed).length;
    expect(n, greaterThan(0));
    await t.scrollUntilVisible(
      find.text('$n to review'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('$n to review'), findsOneWidget);
    // Lift it clear of the floating tab bar before tapping.
    await t.ensureVisible(find.text('$n to review'));
    await t.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await t.pumpAndSettle();
    await t.tap(find.text('$n to review'));
    await t.pumpAndSettle();
    expect(find.text('$n left'), findsOneWidget);
    expect(find.text('Looks right'), findsOneWidget);
    // Clearing one updates the Home count on the way back.
    await t.tap(find.text('Looks right'));
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Close'));
    await t.pumpAndSettle();
    expect(find.text('${n - 1} to review'), findsOneWidget);
  });

  testWidgets('Home is quiet about an empty inbox', (t) async {
    await pumpHome(t, allReviewed: true);
    expect(find.text('Inbox zero'), findsOneWidget);
    expect(find.textContaining('to review'), findsNothing);
  });

  testWidgets(
    'a sheet opened from a tab covers the tab bar, so its buttons are reachable',
    (t) async {
      await pumpHome(t);
      expect(
        find.text('Wealth').hitTestable(),
        findsOneWidget,
        reason: 'tab bar is usable before',
      );
      await t.tap(find.text('Which card should I use?'));
      await t.pumpAndSettle();
      expect(find.byType(SheetScaffold), findsOneWidget);
      expect(
        find.text('Wealth').hitTestable(),
        findsNothing,
        reason: 'the sheet and its barrier sit above the tab bar',
      );
    },
  );
}
