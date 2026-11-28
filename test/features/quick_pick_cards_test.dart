import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/widgets/widgets.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/cards/quick_pick_sheet.dart';

/// "Pick your cards" against the real on-device repository: tick a card, tap
/// Add, and the card must be saved and the sheet must close.
void main() {
  testWidgets(
    'ticking a card and adding it saves the card and closes the sheet',
    (tester) async {
      PulseTheme.useGoogleFonts = false;
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

      late LocalPulseRepository repo;
      await tester.runAsync(() async {
        final db = PulseDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final catalog = CatalogService(
          db: db,
          bundled: () async =>
              File('assets/catalog/cards.json').readAsStringSync(),
        );
        await catalog.loadBundled();
        final pipeline = IngestPipeline(db, clock: DateTime.now);
        addTearDown(pipeline.dispose);
        repo = LocalPulseRepository(
          db: db,
          catalog: catalog,
          pipeline: pipeline,
          clock: DateTime.now,
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: PulseTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showQuickPickCards(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('Which cards do you hold?'), findsOneWidget);

      // Tick the first card in the list.
      final rows = find.byType(ListRow);
      expect(rows, findsWidgets);
      await tester.tap(rows.first);
      await tester.pump();
      expect(find.text('Add 1 card'), findsOneWidget);

      await tester.tap(find.text('Add 1 card'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.text('Which cards do you hold?'),
        findsNothing,
        reason: 'sheet should close after saving',
      );
      final saved = await tester.runAsync(() => repo.myCards());
      expect(saved, hasLength(1));
    },
  );
}
