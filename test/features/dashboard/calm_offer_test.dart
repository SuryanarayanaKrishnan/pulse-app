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
import 'package:pulse/features/home/dashboard/dashboard_controller.dart';
import 'package:pulse/features/home/dashboard/dashboard_layout.dart';

late MemoryKvStore kv;

Future<void> pumpWithSavedHome(WidgetTester tester) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  kv = MemoryKvStore();
  // A layout saved before the calm default existed.
  kv.data[DashboardController.storageKey] = const DashboardLayout(
    activeId: 'everyday',
    dashboards: [
      Dashboard(
        id: 'everyday',
        name: 'Everyday',
        widgets: [
          DashWidget(DashKind.safeToSpend),
          DashWidget(DashKind.netWorth, WidgetSize.compact),
        ],
      ),
    ],
  ).encode();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(
          MockPulseRepository(latency: Duration.zero),
        ),
        analyticsProvider.overrideWithValue(NoopAnalytics()),
        kvStoreProvider.overrideWithValue(kv),
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
  // The offer sheet slides in after the first frame.
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
}

DashboardLayout stored() =>
    DashboardLayout.decode(kv.data[DashboardController.storageKey]);

void main() {
  testWidgets(
    'an existing Home is offered the calm one, yes is the main button',
    (tester) async {
      await pumpWithSavedHome(tester);
      expect(find.text('Try the calmer Home?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('calm-offer-yes')));
      await tester.pumpAndSettle();
      expect(find.text('Try the calmer Home?'), findsNothing);
      expect(stored().active.widgets.map((w) => w.kind), [
        DashKind.safeToSpend,
      ]);
      expect(kv.data[DashboardController.calmMigrationKey], '1');
    },
  );

  testWidgets('keeping my Home leaves it as it was and never asks again', (
    tester,
  ) async {
    await pumpWithSavedHome(tester);
    await tester.tap(find.byKey(const Key('calm-offer-no')));
    await tester.pumpAndSettle();
    final kinds = stored().active.widgets.map((w) => w.kind);
    expect(kinds, contains(DashKind.netWorth));
    expect(kinds, contains(DashKind.review));
    expect(kv.data[DashboardController.calmMigrationKey], '1');
  });

  testWidgets('a brand-new install is never asked', (tester) async {
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
        child: const PulseApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Try the calmer Home?'), findsNothing);
  });
}
