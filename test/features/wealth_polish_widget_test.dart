import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/budget_plan_service.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';

/// In-memory editable assets over the mock repository.
class _Editable extends MockPulseRepository {
  _Editable(List<Asset> start, {this.cards, this.txs, this.budget})
    : _assets = [...start],
      super(latency: Duration.zero);
  final List<Asset> _assets;
  final List<CreditCard>? cards;
  final List<Transaction>? txs;
  final BudgetOverview? budget;
  final deleted = <String>[];

  @override
  Future<List<Asset>> assets() async => List.of(_assets);
  @override
  Future<void> deleteAsset(String id) async {
    deleted.add(id);
    _assets.removeWhere((a) => a.id == id);
  }

  @override
  Future<void> updateAsset(
    String id, {
    required String name,
    required double value,
  }) async {
    final i = _assets.indexWhere((a) => a.id == id);
    final old = _assets[i];
    _assets[i] = Asset(
      id: id,
      name: name,
      kind: old.kind,
      value: value,
      editable: true,
    );
  }

  @override
  Future<List<CreditCard>> myCards() async => cards ?? await super.myCards();
  @override
  Future<List<Transaction>> transactions() async =>
      txs ?? await super.transactions();
  @override
  Future<BudgetOverview> budgetOverview() async =>
      budget ?? await super.budgetOverview();
}

Future<void> _reveal(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

/// Taps the Wealth tile for [kind] and waits for its page.
Future<void> _drill(WidgetTester tester, String kind) async {
  final tile = find.byKey(Key('wealth-tile-$kind'));
  await _reveal(tester, tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> _open(
  WidgetTester tester,
  MockPulseRepository repo,
  String location, {
  List<Override> extra = const [],
}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        analyticsProvider.overrideWithValue(NoopAnalytics()),
        kvStoreProvider.overrideWithValue(MemoryKvStore()),
        sessionProvider.overrideWith(
          (ref) => SessionController(
            onboarded: true,
            signedIn: true,
            connected: true,
          ),
        ),
        ...extra,
      ],
      child: PulseApp(initialLocation: location),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
}

const _flat = Asset(
  id: 'm1',
  name: 'Marina flat',
  kind: AssetKind.realEstate,
  value: 1000000,
  editable: true,
);

void main() {
  testWidgets('swipe a Wealth row to delete it, after a confirmation', (
    tester,
  ) async {
    final repo = _Editable(const [_flat]);
    await _open(tester, repo, '/wealth');
    await _drill(tester, 'realEstate');
    expect(find.text('Marina flat'), findsOneWidget);

    await _reveal(tester, find.byKey(const Key('swipe_m1')));
    await tester.drag(find.byKey(const Key('swipe_m1')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Delete Marina flat?'), findsOneWidget);
    expect(
      repo.deleted,
      isEmpty,
      reason: 'nothing is deleted before the user confirms',
    );

    await tester.tap(find.byKey(const Key('confirm_delete_asset')));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['m1']);
    expect(find.text('Marina flat'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeping a row on the confirmation leaves it alone', (
    tester,
  ) async {
    final repo = _Editable(const [_flat]);
    await _open(tester, repo, '/wealth');
    await _drill(tester, 'realEstate');
    await _reveal(tester, find.byKey(const Key('swipe_m1')));
    await tester.drag(find.byKey(const Key('swipe_m1')), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);
    expect(find.text('Marina flat'), findsOneWidget);
  });

  testWidgets('tap a Wealth row to rename it and change its value', (
    tester,
  ) async {
    final repo = _Editable(const [_flat]);
    await _open(tester, repo, '/wealth');
    await _drill(tester, 'realEstate');
    await _reveal(tester, find.text('Marina flat'));
    await tester.tap(find.text('Marina flat'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('edit_asset_name')),
      'Dubai flat',
    );
    await tester.enterText(
      find.byKey(const Key('edit_asset_value')),
      '1200000',
    );
    await tester.tap(find.byKey(const Key('edit_asset_save')));
    await tester.pumpAndSettle();
    expect(find.text('Dubai flat'), findsOneWidget);
    expect(find.text('Marina flat'), findsNothing);
  });

  testWidgets('rows that are not editable do not swipe', (tester) async {
    final repo = _Editable(const [
      Asset(id: 'g1', name: 'Gold bar', kind: AssetKind.gold, value: 5000),
    ]);
    await _open(tester, repo, '/wealth');
    expect(find.byKey(const Key('swipe_g1')), findsNothing);
  });

  testWidgets(
    'an empty Activity list welcomes the user instead of blaming a filter',
    (tester) async {
      await _open(tester, _Editable(const [], txs: const []), '/activity');
      expect(find.text('Your spending will show up here'), findsOneWidget);
      expect(find.textContaining('different search'), findsNothing);
    },
  );

  testWidgets(
    'Budget with spending but no budget has no on-track or over wording',
    (tester) async {
      final empty = _Editable(
        const [],
        budget: const BudgetOverview(
          planned: 0,
          spent: 25,
          daysLeft: 6,
          daysInMonth: 30,
          lines: [],
          trend: [],
          topMerchants: [],
          byCard: {},
          byAccount: {},
          autoCaptured: 0,
          manual: 1,
        ),
      );
      await _open(
        tester,
        empty,
        '/budget',
        // Hold the plan back so the classic (non-flex) hero is what shows.
        extra: [
          budgetPlanProvider.overrideWith(
            (ref) => Completer<BudgetPlanView>().future,
          ),
        ],
      );
      expect(find.text('No budget set yet · 6 days left'), findsOneWidget);
      expect(find.textContaining('On track'), findsNothing);
      expect(find.textContaining('over'), findsNothing);
    },
  );

  testWidgets('cards with no due day show no due dates', (tester) async {
    final base = await MockPulseRepository(latency: Duration.zero).myCards();
    final noDue = [for (final c in base) c.copyWith(hasDueDate: false)];
    await _open(tester, _Editable(const [], cards: noDue), '/cards');
    expect(
      find.text('Add a due day to a card to see when to pay'),
      findsOneWidget,
    );
    expect(find.text('Upcoming dues'), findsNothing);
    expect(find.textContaining('341'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
