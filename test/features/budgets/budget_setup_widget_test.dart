import 'dart:io';
import 'dart:typed_data';

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
import 'package:pulse/features/budgets/budget_import_screen.dart';

class Rec extends NoopAnalytics {
  final events = <AnalyticsEvent>[];
  @override
  void track(AnalyticsEvent event) => events.add(event);
}

Future<void> open(
  WidgetTester tester,
  String location,
  Rec rec, {
  Future<Uint8List> Function(String)? fetch,
}) async {
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
        analyticsProvider.overrideWithValue(rec),
        kvStoreProvider.overrideWithValue(MemoryKvStore()),
        sessionProvider.overrideWith(
          (ref) => SessionController(
            onboarded: true,
            signedIn: true,
            connected: true,
          ),
        ),
        if (fetch != null) sheetFetcherProvider.overrideWithValue(fetch),
      ],
      child: PulseApp(initialLocation: location),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets(
    'setup: income in, a full budget out, tap to change a line, use it',
    (tester) async {
      final rec = Rec();
      await open(tester, '/budget-setup', rec);
      expect(find.text('Start with your take-home'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('setup_income')), '15000');
      await tester.pump(const Duration(milliseconds: 300));
      final rent = find.byKey(const Key('setup_rent'));
      await tester.scrollUntilVisible(
        rent,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(rent, findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('amount_rent')))
            .controller!
            .text,
        '4500',
      );
      expect(find.text('Typical for the UAE'), findsWidgets);

      await tester.enterText(find.byKey(const Key('amount_rent')), '5200');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('What you told us'), findsOneWidget);
      // Totals follow the edit without any confirm step.
      expect(find.byType(Slider), findsWidgets);

      await tester.tap(find.byKey(const Key('setup_apply')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 1));
      expect(
        rec.events.where((e) => e.name == 'budget_suggested'),
        hasLength(1),
      );
    },
  );

  testWidgets('import: a shared link is read, lines are mapped, import runs', (
    tester,
  ) async {
    final rec = Rec();
    // A CSV served for the link: not a workbook, read as text.
    final csv = Uint8List.fromList(
      File('test/fixtures/sheets/budget_grid.csv').readAsBytesSync(),
    );
    String? asked;
    await open(
      tester,
      '/budget-import',
      rec,
      fetch: (id) async {
        asked = id;
        return csv;
      },
    );
    await tester.enterText(find.byKey(const Key('import_link')), 'not a link');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('That does not look like a Google Sheets link.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('import_link')),
      'https://docs.google.com/spreadsheets/d/1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789/edit?usp=sharing',
    );
    await tester.tap(find.text('Read the sheet'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));
    expect(asked, '1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789');
    expect(find.textContaining('We found 6 lines'), findsOneWidget);
    expect(find.byKey(const Key('map_Rent')), findsOneWidget);
    expect(find.text('Rent & Housing'), findsOneWidget);

    await tester.tap(find.byKey(const Key('import_apply')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1));
    final e = rec.events.where((x) => x.name == 'budget_imported').single;
    expect(e.properties, {'source': 'link', 'history': false, 'items': 'few'});
  });

  testWidgets('budget empty state offers both ways in', (tester) async {
    await open(tester, '/budget', Rec());
    // The mock has data, so the entry points live in Manage.
    final build = find.byKey(const Key('manage_build'));
    final more = find.byKey(const Key('manage_more'));
    await tester.scrollUntilVisible(
      more,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    if (build.evaluate().isEmpty) {
      // Lift it clear of the floating tab bar.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
    }
    await tester.scrollUntilVisible(
      build,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(build, findsOneWidget);
    expect(find.byKey(const Key('manage_import')), findsOneWidget);
  });
}
