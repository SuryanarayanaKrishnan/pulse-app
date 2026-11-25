import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/analytics/event_schema.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/goals.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/goal_models.dart';
import 'package:pulse/data/local/goal_store.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/goals/goal_detail_screen.dart';
import 'package:pulse/features/goals/goal_sheet.dart';

class Rec extends NoopAnalytics {
  final events = <AnalyticsEvent>[];
  @override
  void track(AnalyticsEvent event) => events.add(event);
}

class Rig {
  Rig([MemoryGoalStore? store]) : store = store ?? MemoryGoalStore();
  final MemoryGoalStore store;
  final rec = Rec();
  List<Override> get overrides => [
    goalStoreProvider.overrideWithValue(store),
    analyticsProvider.overrideWithValue(rec),
    repositoryProvider.overrideWithValue(MockPulseRepository(latency: Duration.zero, goals: store)),
  ];
}

Future<void> pump(WidgetTester tester, Rig rig, Widget home) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: rig.overrides, child: MaterialApp(theme: PulseTheme.light, home: home)),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

GoalRecord goal({
  String id = 'g1',
  int target = 1200000,
  int start = 0,
  CalDate? date,
  int? monthly,
  GoalKind kind = GoalKind.save,
  DateTime? completedAt,
}) => GoalRecord(
  id: id,
  name: 'Trip to Japan',
  kind: kind,
  iconKey: 'travel',
  targetMinor: target,
  startMinor: start,
  targetDate: date,
  monthlyMinor: monthly,
  completedAt: completedAt,
  createdAt: DateTime.now().subtract(const Duration(days: 200)),
);

CalDate daysAgo(int n) {
  final d = DateTime.now().subtract(Duration(days: n));
  return CalDate(d.year, d.month, d.day);
}

GoalContribution contrib(String id, int amount, int ago, {String goalId = 'g1'}) =>
    GoalContribution(id: id, goalId: goalId, amountMinor: amount, date: daysAgo(ago));

void main() {
  group('create', () {
    testWidgets('a save goal needs a name and a target, then saves and reports only its type', (tester) async {
      final rig = Rig();
      await pump(tester, rig, const Scaffold(body: GoalSheet()));

      final save = find.byKey(const Key('goal_save'));
      Future<void> tapSave() async {
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pump(const Duration(milliseconds: 100));
      }

      await tapSave();
      expect(await rig.store.goals(), isEmpty, reason: 'nothing yet: no name, no target');

      await tester.ensureVisible(find.byKey(const ValueKey('goal_icon_travel')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('goal_icon_travel')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('goal_name')), 'Trip to Japan');
      await tester.enterText(find.byKey(const Key('goal_target')), '20000');
      await tester.enterText(find.byKey(const Key('goal_start')), '3000');
      await tester.enterText(find.byKey(const Key('goal_monthly')), '1500');
      await tapSave();

      final g = (await rig.store.goals()).single;
      expect(g.name, 'Trip to Japan');
      expect(g.kind, GoalKind.save);
      expect(g.targetMinor, 2000000);
      expect(g.startMinor, 300000);
      expect(g.monthlyMinor, 150000);
      expect(g.iconKey, 'travel');
      expect(g.targetDate, isNull);

      final sent = rig.rec.events.where((e) => e.name == 'goal_created').single;
      expect(sent.properties, {'type': 'save'});
      expect(AnalyticsSchema.clean(sent.name, sent.properties), sent.properties);
    });

    testWidgets('a pay down goal is created from the balance owed and reports type paydown', (tester) async {
      final rig = Rig();
      await pump(tester, rig, const Scaffold(body: GoalSheet()));
      await tester.tap(find.text('Pay down'));
      await tester.pump();
      expect(find.byKey(const Key('goal_target')), findsNothing);
      await tester.enterText(find.byKey(const Key('goal_name')), 'Clear the card');
      await tester.enterText(find.byKey(const Key('goal_start')), '9000');
      await tester.pump();
      final save = find.byKey(const Key('goal_save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump(const Duration(milliseconds: 100));

      final g = (await rig.store.goals()).single;
      expect(g.kind, GoalKind.paydown);
      expect(g.startMinor, 900000);
      expect(g.targetMinor, 0);
      expect(rig.rec.events.single.properties, {'type': 'paydown'});
    });

    test('analytics: neither event can carry a name or an amount', () {
      expect(AnalyticsSchema.clean('goal_created', {'type': 'save', 'name': 'Trip', 'amount': 5}), {'type': 'save'});
      expect(AnalyticsSchema.clean('goal_created', {'type': 'Japan'}), isEmpty);
      expect(AnalyticsSchema.clean('goal_completed', {'amount': 5}), isEmpty);
    });
  });

  group('detail', () {
    testWidgets('shows progress, a calm on-track line, the plan and the history', (tester) async {
      final rig = Rig(
        MemoryGoalStore(
          goals: [goal(date: addMonths(CalDate.parse(daysAgo(0).toIso()), 6), monthly: 150000)],
          contributions: [contrib('c1', 300000, 80), contrib('c2', 300000, 55), contrib('c3', 300000, 35)],
        ),
      );
      await pump(tester, rig, const GoalDetailScreen(goalId: 'g1'));

      expect(tester.widget<Text>(find.byKey(const Key('goal_current'))).data, 'AED 9,000');
      expect(find.text('of AED 12,000'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('goal_pace'))).data, 'On track');
      expect(find.textContaining('At this pace you finish around'), findsOneWidget);
      expect(find.text('Projected finish'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('goal_reserved'))).data, 'AED 1,500');
      await tester.scrollUntilVisible(find.byKey(const ValueKey('hist_c3')), 200, scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const ValueKey('hist_c3')), findsOneWidget);
    });

    testWidgets('a slow pace is "a little behind", never alarming', (tester) async {
      final rig = Rig(
        MemoryGoalStore(
          goals: [goal(target: 6000000, date: addMonths(CalDate.parse(daysAgo(0).toIso()), 6))],
          contributions: [contrib('c1', 100000, 10)],
        ),
      );
      await pump(tester, rig, const GoalDetailScreen(goalId: 'g1'));
      expect(tester.widget<Text>(find.byKey(const Key('goal_pace'))).data, 'A little behind');
      expect(find.textContaining('would close the gap'), findsOneWidget);
    });

    testWidgets('pausing stops the set-aside and says so', (tester) async {
      final rig = Rig(MemoryGoalStore(goals: [goal(monthly: 150000)]));
      await pump(tester, rig, const GoalDetailScreen(goalId: 'g1'));
      expect(tester.widget<Text>(find.byKey(const Key('goal_reserved'))).data, 'AED 1,500');

      await tester.ensureVisible(find.byKey(const Key('goal_pause')));
      await tester.tap(find.byKey(const Key('goal_pause')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect((await rig.store.goals()).single.paused, isTrue);
      expect(tester.widget<Text>(find.byKey(const Key('goal_reserved'))).data, 'AED 0');
      expect(tester.widget<Text>(find.byKey(const Key('goal_pace'))).data, 'Paused');
      // safe to spend no longer holds it back
      final container = ProviderScope.containerOf(tester.element(find.byType(GoalDetailScreen)));
      final s = await container.read(repositoryProvider).safeToSpend();
      expect(s.goals, 0);
      expect(s.goalLines, isEmpty);
    });
  });

  group('contributions', () {
    testWidgets('add money updates progress, history and the set-aside', (tester) async {
      final rig = Rig(MemoryGoalStore(goals: [goal(monthly: 150000)]));
      await pump(tester, rig, const GoalDetailScreen(goalId: 'g1'));

      await tester.tap(find.byKey(const Key('goal_add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('contribution_amount')), '500');
      await tester.enterText(find.byKey(const Key('contribution_note')), 'Bonus');
      await tester.pump();
      await tester.tap(find.byKey(const Key('contribution_save')));
      await tester.pumpAndSettle();

      expect((await rig.store.contributions()).single.amountMinor, 50000);
      expect(tester.widget<Text>(find.byKey(const Key('goal_current'))).data, 'AED 500');
      await tester.scrollUntilVisible(find.textContaining('Bonus'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Bonus'), findsOneWidget);
      // 1,500 planned less the 500 already put in this month
      expect(tester.widget<Text>(find.byKey(const Key('goal_reserved'))).data, 'AED 1,000');
    });

    testWidgets('withdraw takes money back, but never more than the goal holds', (tester) async {
      final rig = Rig(MemoryGoalStore(goals: [goal(start: 100000)]));
      await pump(tester, rig, const GoalDetailScreen(goalId: 'g1'));

      await tester.tap(find.byKey(const Key('goal_withdraw')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('contribution_amount')), '5000');
      await tester.pump();
      expect(find.textContaining('the most you can take back'), findsOneWidget);
      await tester.tap(find.byKey(const Key('contribution_save')));
      await tester.pump();
      expect(await rig.store.contributions(), isEmpty);

      await tester.enterText(find.byKey(const Key('contribution_amount')), '400');
      await tester.pump();
      await tester.tap(find.byKey(const Key('contribution_save')));
      await tester.pumpAndSettle();
      expect((await rig.store.contributions()).single.amountMinor, -40000);
      expect(tester.widget<Text>(find.byKey(const Key('goal_current'))).data, 'AED 600');
    });

    testWidgets('a pay down goal logs payments and counts down', (tester) async {
      final rig = Rig(MemoryGoalStore(goals: [goal(kind: GoalKind.paydown, target: 0, start: 900000)]));
      await pump(tester, rig, const GoalDetailScreen(goalId: 'g1'));
      expect(find.text('Log a payment'), findsOneWidget);
      expect(find.byKey(const Key('goal_withdraw')), findsNothing);
      await tester.tap(find.byKey(const Key('goal_add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('contribution_amount')), '3000');
      await tester.pump();
      await tester.tap(find.byKey(const Key('contribution_save')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('goal_current'))).data, 'AED 6,000');
      expect(find.text('left of AED 9,000'), findsOneWidget);
    });

    testWidgets('reaching the target reports goal_completed once', (tester) async {
      final rig = Rig(MemoryGoalStore(goals: [goal(target: 100000, start: 50000)]));
      await pump(tester, rig, const GoalDetailScreen(goalId: 'g1'));
      await tester.tap(find.byKey(const Key('goal_add')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('contribution_amount')), '500');
      await tester.pump();
      await tester.tap(find.byKey(const Key('contribution_save')));
      await tester.pumpAndSettle();

      expect(rig.rec.events.where((e) => e.name == 'goal_completed'), hasLength(1));
      expect((await rig.store.goals()).single.completedAt, isNotNull);
      expect(tester.widget<Text>(find.byKey(const Key('goal_pace'))).data, 'Reached');
      expect(find.byKey(const Key('goal_add')), findsNothing);
    });
  });
}
