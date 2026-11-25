import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/analytics/event_schema.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/home/dashboard/dashboard_controller.dart';
import 'package:pulse/features/home/dashboard/dashboard_layout.dart';

class Rec implements Analytics {
  final events = <AnalyticsEvent>[];
  @override
  void track(AnalyticsEvent e) => events.add(e);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

late MemoryKvStore kv;
late Rec rec;

Future<void> pumpHome(WidgetTester tester, {DashboardLayout? saved}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  kv = MemoryKvStore();
  rec = Rec();
  if (saved != null) kv.data[DashboardController.storageKey] = saved.encode();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(
          MockPulseRepository(latency: Duration.zero),
        ),
        analyticsProvider.overrideWithValue(rec),
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
}

DashboardLayout stored() =>
    DashboardLayout.decode(kv.data[DashboardController.storageKey]);

/// Scrolls [f] clear of the floating tab bar.
Future<void> reveal(WidgetTester tester, Finder f) async {
  await Scrollable.ensureVisible(tester.element(f), alignment: 0.3);
  await tester.pumpAndSettle();
}

Future<void> customise(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Customise'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Home shows the saved dashboard and the chips switch between them',
    (tester) async {
      await pumpHome(tester);
      expect(find.text('Safe to spend today'), findsOneWidget);
      expect(find.text('Everyday'), findsOneWidget);
      expect(find.text('Month end'), findsOneWidget);
      expect(find.text('Which card should I use?'), findsOneWidget);
      expect(find.text('Cash flow'), findsNothing);

      await tester.tap(find.text('Month end'));
      await tester.pumpAndSettle();
      expect(find.text('Safe to spend today'), findsNothing);
      expect(find.text('Cash flow'), findsOneWidget);
      expect(stored().activeId, 'month_end');
    },
  );

  testWidgets('a saved layout is restored on launch', (tester) async {
    final l = const DashboardLayout(
      activeId: 'mine',
      dashboards: [
        Dashboard(
          id: 'mine',
          name: 'Mine',
          widgets: [DashWidget(DashKind.cashFlow)],
        ),
      ],
    );
    await pumpHome(tester, saved: l);
    expect(find.text('Cash flow'), findsOneWidget);
    expect(find.text('Safe to spend today'), findsNothing);
    // One dashboard: no chip row.
    expect(find.text('Mine'), findsNothing);
  });

  testWidgets('Customise opens a calm editor with Done, and Done returns', (
    tester,
  ) async {
    await pumpHome(tester);
    await customise(tester);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Add a widget'), findsOneWidget);
    expect(find.text('Safe to spend'), findsOneWidget); // edit tile label
    expect(find.text('New'), findsOneWidget);
    expect(find.bySemanticsLabel('Customise'), findsNothing);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsNothing);
    expect(find.text('Safe to spend today'), findsOneWidget);
  });

  testWidgets('remove and add widgets save and report only the kind', (
    tester,
  ) async {
    await pumpHome(tester);
    await customise(tester);

    await tester.tap(find.bySemanticsLabel('Remove Net worth'));
    await tester.pumpAndSettle();
    expect(stored().active.has(DashKind.netWorth), isFalse);
    expect(find.bySemanticsLabel('Remove Net worth'), findsNothing);

    // It is now offered under "Add a widget".
    await reveal(tester, find.text('Net worth'));
    await tester.tap(find.text('Net worth'));
    await tester.pumpAndSettle();
    expect(stored().active.widgets.last.kind, DashKind.netWorth);

    final sent = rec.events
        .where((e) => e.name == 'dashboard_customised')
        .toList();
    expect(
      [for (final e in sent) e.properties['action']],
      ['removed', 'added'],
    );
    for (final e in sent) {
      expect(e.properties['widget'], 'net_worth');
      expect(AnalyticsSchema.clean(e.name, e.properties), e.properties);
    }
  });

  testWidgets('tapping a size switches compact and regular', (tester) async {
    await pumpHome(tester);
    await customise(tester);
    expect(stored().active.widgets.first.size, WidgetSize.regular);
    await tester.tap(find.bySemanticsLabel(RegExp('^Safe to spend size')));
    await tester.pumpAndSettle();
    expect(stored().active.widgets.first.size, WidgetSize.compact);
    expect(
      find.text('Compact'),
      findsNWidgets(4),
    ); // + net worth, splits, goals
    await tester.tap(find.bySemanticsLabel(RegExp('^Safe to spend size')));
    await tester.pumpAndSettle();
    expect(stored().active.widgets.first.size, WidgetSize.regular);
  });

  testWidgets('dragging a handle reorders and saves', (tester) async {
    await pumpHome(tester);
    await customise(tester);
    final before = [for (final w in stored().active.widgets) w.kind];
    expect(before.first, DashKind.safeToSpend);

    final handle = find.byIcon(Icons.drag_indicator_rounded).first;
    final g = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 12; i++) {
      await g.moveBy(const Offset(0, 14));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();

    final after = [for (final w in stored().active.widgets) w.kind];
    expect(after.first, isNot(DashKind.safeToSpend));
    expect(after.indexOf(DashKind.safeToSpend), greaterThan(0));
    expect(after.toSet(), before.toSet());
    final e = rec.events.singleWhere((e) => e.name == 'dashboard_customised');
    expect(e.properties, {'action': 'moved', 'widget': 'safe_to_spend'});
  });

  testWidgets('a new dashboard can be named, then renamed and deleted', (
    tester,
  ) async {
    await pumpHome(tester);
    await customise(tester);
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Holiday');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(stored().active.name, 'Holiday');
    expect(stored().dashboards.length, 3);
    expect(find.text('Nothing here yet. Add a widget below.'), findsOneWidget);
    // The name is never sent as analytics.
    expect(rec.events.where((e) => e.name == 'dashboard_customised'), isEmpty);

    await reveal(tester, find.text('Rename'));
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Rome');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(stored().active.name, 'Rome');

    await reveal(tester, find.text('Delete dashboard'));
    await tester.tap(find.text('Delete dashboard'));
    await tester.pumpAndSettle();
    expect(stored().dashboards.map((d) => d.name), ['Everyday', 'Month end']);
  });
}
