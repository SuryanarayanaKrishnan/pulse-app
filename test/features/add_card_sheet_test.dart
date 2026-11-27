import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/widgets/widgets.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/data/repository.dart';
import 'package:pulse/features/wallet/add_sheets.dart';

/// Add card: only the card is required, save works on the phone and in sample
/// data, and any problem shows inside the sheet.
void main() {
  Future<PulseRepository> local(WidgetTester tester) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    late LocalPulseRepository repo;
    await tester.runAsync(() async {
      final db = PulseDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final catalog = CatalogService(db: db, bundled: () async => File('assets/catalog/cards.json').readAsStringSync());
      await catalog.loadBundled();
      final pipeline = IngestPipeline(db, clock: DateTime.now);
      addTearDown(pipeline.dispose);
      repo = LocalPulseRepository(db: db, catalog: catalog, pipeline: pipeline, clock: DateTime.now);
    });
    return repo;
  }

  Future<void> open(WidgetTester tester, PulseRepository repo) async {
    PulseTheme.useGoogleFonts = false;
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [repositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: PulseTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPulseSheet<void>(context, builder: (_) => const AddCardSheet()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.tap(find.byType(ListRow).first);
    await settle(tester);
  }

  Future<void> tapAdd(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('add_card_save')));
    await settle(tester);
  }

  testWidgets('card only: saves with no digits, limit or dates, and closes', (tester) async {
    final repo = await local(tester);
    await open(tester, repo);
    expect(find.byKey(const Key('add_card_limit')), findsNothing);
    expect(find.textContaining("fill the credit limit, statement day and due day"), findsOneWidget);
    await tapAdd(tester);
    expect(find.byKey(const Key('add_card_save')), findsNothing, reason: 'sheet closed');
    expect(await tester.runAsync(() => repo.myCards()), hasLength(1));
  });

  testWidgets('manual details have labels and are saved', (tester) async {
    final repo = await local(tester);
    await open(tester, repo);
    await tester.tap(find.byKey(const Key('add_card_manual')));
    await tester.pump();
    for (final l in ['Credit limit', 'Owed today', 'Statement day', 'Due day']) {
      expect(find.text(l), findsOneWidget);
    }
    await tester.enterText(find.byKey(const Key('add_card_last4')), '1234');
    await tester.enterText(find.byKey(const Key('add_card_limit')), '20000');
    await tester.enterText(find.byKey(const Key('add_card_owed')), '105');
    await tester.enterText(find.byKey(const Key('add_card_statement_day')), '12');
    await tester.enterText(find.byKey(const Key('add_card_due_day')), '30');
    await tapAdd(tester);
    final saved = (await tester.runAsync(() => repo.myCards()))!;
    expect(saved.single.last4, '1234');
    expect(saved.single.limit, 20000);
  });

  testWidgets('three digits: a message in the sheet, nothing saved', (tester) async {
    final repo = await local(tester);
    await open(tester, repo);
    await tester.enterText(find.byKey(const Key('add_card_last4')), '123');
    await tapAdd(tester);
    expect(find.byKey(const Key('add_card_error')), findsOneWidget);
    expect(await tester.runAsync(() => repo.myCards()), isEmpty);
  });

  testWidgets('day 45: a message in the sheet', (tester) async {
    final repo = await local(tester);
    await open(tester, repo);
    await tester.tap(find.byKey(const Key('add_card_manual')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('add_card_due_day')), '45');
    await tapAdd(tester);
    expect(find.textContaining('1 to 31'), findsWidgets);
    expect(find.byKey(const Key('add_card_error')), findsOneWidget);
  });

  testWidgets('sample data: adding a card works and the sheet closes', (tester) async {
    final repo = MockPulseRepository(latency: Duration.zero);
    await open(tester, repo);
    await tapAdd(tester);
    expect(find.byKey(const Key('add_card_save')), findsNothing);
  });

  group('edit card', () {
    Future<void> openEdit(WidgetTester tester, PulseRepository repo, CreditCard card) async {
      PulseTheme.useGoogleFonts = false;
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: PulseTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showPulseSheet<void>(context, builder: (_) => EditCardSheet(card: card)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    testWidgets('shows what is set, saves changes and the card reads them back', (tester) async {
      final repo = await local(tester);
      final card = (await tester.runAsync(() async {
        await repo.addCard(catalogId: 'adcb-lulu-platinum', last4: '1111', limit: 20000, statementDay: 12, dueDay: 30);
        return (await repo.myCards()).single;
      }))!;
      expect(card.statementDay, 12);
      expect(card.dueDay, 30);
      await openEdit(tester, repo, card);
      expect(find.widgetWithText(TextField, '1111'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('edit_card_limit')), '35000');
      await tester.enterText(find.byKey(const Key('edit_card_due_day')), '5');
      await tester.tap(find.byKey(const Key('edit_card_save')));
      await settle(tester);
      expect(find.byKey(const Key('edit_card_save')), findsNothing, reason: 'closed');
      final after = (await tester.runAsync(() => repo.myCards()))!.single;
      expect(after.limit, 35000);
      expect(after.dueDay, 5);
      expect(after.statementDay, 12);
      expect(after.last4, '1111');
    });

    testWidgets('clearing a field removes it; a bad day shows a message and saves nothing', (tester) async {
      final repo = await local(tester);
      final card = (await tester.runAsync(() async {
        await repo.addCard(catalogId: 'adcb-lulu-platinum', last4: '1111', limit: 20000, statementDay: 12);
        return (await repo.myCards()).single;
      }))!;
      await openEdit(tester, repo, card);
      await tester.enterText(find.byKey(const Key('edit_card_statement_day')), '40');
      await tester.tap(find.byKey(const Key('edit_card_save')));
      await settle(tester);
      expect(find.byKey(const Key('edit_card_error')), findsOneWidget);
      expect((await tester.runAsync(() => repo.myCards()))!.single.statementDay, 12);
      await tester.enterText(find.byKey(const Key('edit_card_statement_day')), '');
      await tester.enterText(find.byKey(const Key('edit_card_last4')), '');
      await tester.tap(find.byKey(const Key('edit_card_save')));
      await settle(tester);
      final after = (await tester.runAsync(() => repo.myCards()))!.single;
      expect(after.statementDay, isNull);
      expect(after.last4, '----');
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pump(const Duration(milliseconds: 300));
  }
}
