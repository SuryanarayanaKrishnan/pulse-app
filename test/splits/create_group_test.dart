import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Icons, TextField;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/bugreport/shake_host.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';
import 'package:pulse/data/local/splits_store.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';

class _Rec implements Analytics {
  final events = <AnalyticsEvent>[];
  @override
  void track(AnalyticsEvent e) => events.add(e);
  @override
  Future<void> init() async {}
  @override
  void screen(String name) {}
  @override
  void identify(String userId) {}
  @override
  void reset() {}
}

/// The on-device ledger with no backend (`shared` is null), like dev mode.
class _Failing extends LocalPulseRepository {
  _Failing({
    required super.db,
    required super.catalog,
    required super.pipeline,
  });
  @override
  Future<SplitGroup> createSplitGroup({
    required String name,
    String emoji = '👥',
    List<NewGroupMember> members = const [],
  }) => Future.error(StateError('disk is full'));
}

Future<LocalPulseRepository> _repo(
  WidgetTester t, {
  bool failing = false,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = PulseDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final catalog = CatalogService(
    db: db,
    bundled: () async => File('assets/catalog/cards.json').readAsStringSync(),
  );
  await t.runAsync(catalog.loadBundled);
  final pipeline = IngestPipeline(db);
  addTearDown(pipeline.dispose);
  return failing
      ? _Failing(db: db, catalog: catalog, pipeline: pipeline)
      : LocalPulseRepository(db: db, catalog: catalog, pipeline: pipeline);
}

Future<void> _pump(WidgetTester t, LocalPulseRepository repo, _Rec rec) async {
  PulseTheme.useGoogleFonts = false;
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        shakeSourceProvider.overrideWithValue(() => const Stream.empty()),
        repositoryProvider.overrideWithValue(repo),
        analyticsProvider.overrideWithValue(rec),
        sessionProvider.overrideWith(
          (ref) => SessionController(
            onboarded: true,
            signedIn: true,
            connected: true,
          ),
        ),
      ],
      child: const PulseApp(initialLocation: '/splits'),
    ),
  );
  await _settle(t);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _createViaSheet(WidgetTester t) async {
  expect(find.text('New group'), findsOneWidget);
  await t.enterText(find.byKey(const Key('group-name')), 'Dubai trip');
  await t.enterText(find.byKey(const Key('group-person')), 'Sara');
  await t.tap(find.byKey(const Key('group-person-add')));
  await t.pump();
  expect(find.text('Sara'), findsWidgets);
  await t.tap(find.text('Create group').last);
  await _settle(t);
}

void main() {
  testWidgets(
    'empty ledger, no backend: header + opens the create sheet and the group appears',
    (t) async {
      final rec = _Rec();
      await _pump(t, await _repo(t), rec);
      expect(find.text('No groups yet'), findsOneWidget);

      await t.tap(find.byIcon(Icons.add_rounded));
      await _settle(t);
      await _createViaSheet(t);

      expect(find.text('No groups yet'), findsNothing);
      expect(find.text('Dubai trip'), findsOneWidget);
      expect(find.text('2 people · AED 0'), findsOneWidget);
      expect(rec.events.map((e) => e.name), contains('split_group_created'));
    },
  );

  testWidgets('the empty-state Create group button does the same', (t) async {
    final rec = _Rec();
    await _pump(t, await _repo(t), rec);
    await t.tap(find.text('Create group'));
    await _settle(t);
    await _createViaSheet(t);
    expect(find.text('Dubai trip'), findsOneWidget);
  });

  testWidgets('a new group can take an expense with no backend', (t) async {
    final repo = await _repo(t);
    await _pump(t, repo, _Rec());
    await t.tap(find.text('Create group'));
    await _settle(t);
    await _createViaSheet(t);

    await t.tap(find.byIcon(Icons.add_rounded));
    await _settle(t);
    await t.tap(find.text('Add expense'));
    await _settle(t);
    await t.enterText(find.byType(TextField).at(0), 'Dinner');
    await t.enterText(find.byType(TextField).at(1), '100');
    await t.tap(find.text('Add expense').last);
    await _settle(t);
    final groups = await t.runAsync(repo.splitGroups);
    expect(groups!.single.expenses.single.amount, 100);
    expect(find.text('2 people · AED 100'), findsOneWidget);
  });

  testWidgets(
    'a failing create shows an error and logs an analytics-safe event',
    (t) async {
      final rec = _Rec();
      await _pump(t, await _repo(t, failing: true), rec);
      await t.tap(find.byIcon(Icons.add_rounded));
      await _settle(t);
      await _createViaSheet(t);

      expect(find.byKey(const Key('group-error')), findsOneWidget);
      expect(
        find.text('Could not create the group. Please try again.'),
        findsWidgets,
      );
      final failed = rec.events.singleWhere(
        (e) => e.name == 'split_action_failed',
      );
      expect(failed.properties, {'action': 'create_group', 'reason': 'other'});
      expect(
        find.text('Dubai trip'),
        findsOneWidget,
      ); // still in the form, not lost
    },
  );

  testWidgets('creating without a name says so', (t) async {
    await _pump(t, await _repo(t), _Rec());
    await t.tap(find.text('Create group'));
    await _settle(t);
    await t.tap(find.text('Create group').last);
    await t.pump();
    expect(find.text('Give the group a name.'), findsOneWidget);
  });
}
