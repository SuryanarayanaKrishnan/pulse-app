import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/wallet/add_sheets.dart';

/// Search finds the issuers surya looked for (Tabby, HSBC), and a card the
/// catalog does not list can still be added by hand.
void main() {
  Future<LocalPulseRepository> repo(WidgetTester tester) async {
    late LocalPulseRepository r;
    await tester.runAsync(() async {
      final db = PulseDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final catalog = CatalogService(db: db, bundled: () async => File('assets/catalog/cards.json').readAsStringSync());
      await catalog.loadBundled();
      final pipeline = IngestPipeline(db, clock: DateTime.now);
      addTearDown(pipeline.dispose);
      r = LocalPulseRepository(db: db, catalog: catalog, pipeline: pipeline, clock: DateTime.now);
    });
    return r;
  }

  Future<void> open(WidgetTester tester, LocalPulseRepository r) async {
    PulseTheme.useGoogleFonts = false;
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(r)],
        child: MaterialApp(theme: PulseTheme.light, home: const Scaffold(body: AddCardSheet())),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  for (final q in ['tabby', 'hsbc']) {
    testWidgets('searching "$q" finds a card', (tester) async {
      await open(tester, await repo(tester));
      await tester.enterText(find.byType(TextField).first, q);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('No match'), findsNothing);
      expect(find.textContaining(q, findRichText: true), findsWidgets);
    });
  }

  testWidgets('"I can\'t find my card" leads to a form that creates the card', (tester) async {
    final r = await repo(tester);
    await open(tester, r);
    await tester.enterText(find.byType(TextField).first, 'zzzz');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('No match'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cant_find_card')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byKey(const Key('custom_card_issuer')), 'Some Bank');
    await tester.enterText(find.byKey(const Key('custom_card_name')), 'Gold');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Continue'));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.textContaining('Some Bank Gold'), findsWidgets);
    expect(find.text('Last 4 digits'), findsOneWidget); // on to the digits step
  });
}
