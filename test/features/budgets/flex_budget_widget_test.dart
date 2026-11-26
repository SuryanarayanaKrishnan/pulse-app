import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/analytics/event_schema.dart';
import 'package:pulse/core/household/household_keys.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/widgets/widgets.dart' show HeroNumber;
import 'package:pulse/data/demo_household.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/household/household_providers.dart';

class Rec extends NoopAnalytics {
  final events = <AnalyticsEvent>[];
  @override
  void track(AnalyticsEvent event) => events.add(event);
}

Future<List<Override>> _overrides(Rec rec, {bool household = false}) async => [
  repositoryProvider.overrideWithValue(MockPulseRepository(latency: Duration.zero)),
  analyticsProvider.overrideWithValue(rec),
  kvStoreProvider.overrideWithValue(MemoryKvStore()),
  sessionProvider.overrideWith((ref) => SessionController(onboarded: true, signedIn: true, connected: true)),
  if (household) ...[
    householdStoreProvider.overrideWithValue(await demoJoinedHousehold(() async => [])),
    householdKeyStoreProvider.overrideWithValue(MemoryHouseholdKeyStore()..key = Uint8List.fromList(List.filled(32, 7))),
  ],
];

Future<void> pumpBudget(WidgetTester tester, Rec rec, {bool household = false}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: await _overrides(rec, household: household), child: const PulseApp(initialLocation: '/budget')),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> reveal(WidgetTester tester, Finder f, {double alignment = 0.4}) async {
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await Scrollable.ensureVisible(tester.element(f), alignment: alignment);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('flex budget', () {
    testWidgets('opens in flex mode: one number, three groups, bills at their set amounts', (tester) async {
      await pumpBudget(tester, Rec());
      expect(find.byKey(const Key('flex_hero')), findsOneWidget);
      expect(find.text('Flexible left'), findsOneWidget);
      expect(find.text('Spent this month'), findsNothing);
      expect(find.textContaining('Fixed 2'), findsOneWidget);
      expect(find.textContaining('Flexible 7'), findsOneWidget);
      expect(find.textContaining('Non-monthly 2'), findsOneWidget);
      // Flexible is showing; the pool is described.
      expect(find.byKey(const Key('rows_flexible')), findsOneWidget);
      await tester.tap(find.textContaining('Fixed 2'));
      await settle(tester);
      expect(find.byKey(const Key('rows_fixed')), findsOneWidget);
      expect(find.byKey(const Key('plan_rent')), findsOneWidget);
      expect(find.textContaining('paid'), findsWidgets);
    });

    testWidgets('Non-monthly shows sinking funds with the cycle glyph and what has been carried in', (tester) async {
      await pumpBudget(tester, Rec());
      await tester.tap(find.textContaining('Non-monthly 2'));
      await settle(tester);
      expect(find.byKey(const Key('rows_nonmonthly')), findsOneWidget);
      expect(find.byKey(const Key('cycle_travel')), findsOneWidget);
      expect(find.byKey(const Key('carry_travel')), findsOneWidget);
      expect(find.textContaining('carried'), findsWidgets);
      expect(find.textContaining('a year'), findsOneWidget);
    });

    testWidgets('a rolling flexible category shows its carried balance on the row', (tester) async {
      await pumpBudget(tester, Rec());
      expect(find.byKey(const Key('cycle_groceries')), findsOneWidget);
      expect(find.byKey(const Key('carry_groceries')), findsOneWidget);
      expect(find.byKey(const Key('cycle_dining')), findsNothing);
    });

    testWidgets('switching to Categories reports only the mode, and back again', (tester) async {
      final rec = Rec();
      await pumpBudget(tester, rec);
      await tester.tap(find.descendant(of: find.byKey(const Key('budget_mode')), matching: find.text('Categories')));
      await settle(tester);
      expect(find.text('Spent this month'), findsOneWidget);
      expect(find.byKey(const Key('flex_hero')), findsNothing);
      await tester.tap(find.descendant(of: find.byKey(const Key('budget_mode')), matching: find.text('Flex')));
      await settle(tester);
      expect(find.byKey(const Key('flex_hero')), findsOneWidget);
      final sent = rec.events.where((e) => e.name == 'budget_mode_changed').toList();
      expect(sent.map((e) => e.properties), [
        {'mode': 'category'},
        {'mode': 'flex'},
      ]);
    });

    testWidgets('Move money: pick, amount, move; the total holds, Undo takes it back', (tester) async {
      final rec = Rec();
      await pumpBudget(tester, rec);
      double pool() => tester.widget<HeroNumber>(find.byKey(const Key('flex_hero'))).value;
      final before = pool();
      await tester.tap(find.text('Move money').first);
      await settle(tester);
      expect(find.text('Move money'), findsWidgets);
      await tester.ensureVisible(find.byKey(const Key('to_dining')));
      await tester.tap(find.byKey(const Key('to_dining')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('move_amount')), '300.50');
      await tester.pump();
      await tester.tap(find.byKey(const Key('move_go')));
      await settle(tester);

      expect(rec.events.where((e) => e.name == 'money_moved').single.properties, isEmpty);
      expect(find.text('Moved this month'), findsOneWidget);
      expect(find.byKey(const Key('moves_list')), findsOneWidget);
      // Dining got 300.50 more to plan; the pool's headline is unchanged.
      expect(find.text('Flexible left'), findsOneWidget);
      expect(find.textContaining(' moved'), findsWidgets);
      expect(pool(), before);

      await reveal(tester, find.byKey(const Key('moves_list')));
      await tester.tap(find.descendant(of: find.byKey(const Key('moves_list')), matching: find.text('Undo')));
      await settle(tester);
      expect(find.byKey(const Key('moves_list')), findsNothing);
      expect(find.textContaining(' moved'), findsNothing);
    });

    testWidgets('moving more than the source has planned is refused with a reason, nothing is recorded', (tester) async {
      final rec = Rec();
      await pumpBudget(tester, rec);
      await tester.tap(find.text('Move money').first);
      await settle(tester);
      await tester.ensureVisible(find.byKey(const Key('to_dining')));
      await tester.tap(find.byKey(const Key('to_dining')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('move_amount')), '9999999');
      await tester.pump();
      await tester.tap(find.byKey(const Key('move_go')));
      await settle(tester);
      expect(find.byKey(const Key('move_error')), findsOneWidget);
      expect(find.textContaining('more than'), findsOneWidget);
      expect(rec.events.where((e) => e.name == 'money_moved'), isEmpty);
    });

    testWidgets('tapping the red remaining opens Move money aimed at that category, with the overspend filled in', (tester) async {
      await pumpBudget(tester, Rec());
      await reveal(tester, find.byKey(const Key('cover_dining')));
      expect(find.textContaining('over'), findsWidgets);
      await tester.tap(find.byKey(const Key('cover_dining')));
      await settle(tester);
      final field = tester.widget<TextField>(find.byKey(const Key('move_amount')));
      expect(double.parse(field.controller!.text), greaterThan(0));
    });

    testWidgets('the category sheet turns a category Non-monthly with a yearly cost', (tester) async {
      await pumpBudget(tester, Rec());
      await reveal(tester, find.byKey(const Key('plan_shopping')));
      await tester.tap(find.byKey(const Key('plan_shopping')));
      await settle(tester);
      await tester.tap(find.descendant(of: find.byKey(const Key('plan_group')), matching: find.text('Non-monthly')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('plan_cost')), '1200');
      await tester.tap(find.text('Every year'));
      await tester.pump();
      expect(find.textContaining('AED 100 a month'), findsOneWidget);
      await tester.tap(find.byKey(const Key('plan_save')));
      await settle(tester);
      await tester.tap(find.textContaining('Non-monthly 3'));
      await settle(tester);
      expect(find.byKey(const Key('plan_shopping')), findsOneWidget);
      expect(find.byKey(const Key('cycle_shopping')), findsOneWidget);
    });
  });

  group('cash-flow Sankey', () {
    testWidgets('draws income into categories and what is left; tap a flow to see its payments; tap again to clear', (tester) async {
      await pumpBudget(tester, Rec());
      await reveal(tester, find.byKey(const Key('sankey_canvas')), alignment: 0.3);
      final r = tester.getRect(find.byKey(const Key('sankey_canvas')));
      expect(find.byKey(const Key('flow_detail')), findsNothing);
      // The top bar of the right-hand column (the biggest category).
      final tap = Offset(r.right - 104 - 4, r.top + 8 + 24);
      await tester.tapAt(tap);
      await settle(tester);
      expect(find.byKey(const Key('flow_detail')), findsOneWidget);
      await tester.tapAt(tap);
      await settle(tester);
      expect(find.byKey(const Key('flow_detail')), findsNothing);
    });

    testWidgets('the month picker steps back, never past this month, and an empty month says so', (tester) async {
      await pumpBudget(tester, Rec());
      await reveal(tester, find.byKey(const Key('sankey_section')), alignment: 0.1);
      final section = find.byKey(const Key('sankey_section'));
      String label() => tester.widget<Text>(find.descendant(of: section, matching: find.byKey(const Key('month_switcher'))).evaluate().isEmpty
          ? find.text('x')
          : find.descendant(of: find.descendant(of: section, matching: find.byKey(const Key('month_switcher'))), matching: find.byType(Text))).data!;
      final now = DateTime.now();
      final thisMonth = label();
      expect(thisMonth, contains('${now.year}'));
      final prev = find.descendant(of: section, matching: find.byIcon(Icons.chevron_left_rounded));
      final next = find.descendant(of: section, matching: find.byIcon(Icons.chevron_right_rounded));
      for (var i = 0; i < 3; i++) {
        await Scrollable.ensureVisible(tester.element(prev), alignment: 0.2);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(prev);
        await settle(tester);
      }
      expect(label(), isNot(thisMonth));
      expect(find.byKey(const Key('sankey_empty')), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        // The fourth tap is already this month and does nothing.
        await Scrollable.ensureVisible(tester.element(next), alignment: 0.2);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(next);
        await settle(tester);
      }
      expect(label(), thisMonth);
      await reveal(tester, find.byKey(const Key('sankey_canvas')));
      expect(find.byKey(const Key('sankey_empty')), findsNothing);
    });
  });

  group('Mine and Joint', () {
    testWidgets('Joint has its own Move money; Mine is untouched by it', (tester) async {
      final rec = Rec();
      await pumpBudget(tester, rec, household: true);
      await tester.tap(find.text('Joint'));
      await settle(tester);
      expect(find.byKey(const Key('flex_section')), findsNothing);
      await reveal(tester, find.byKey(const Key('joint_move')));
      await tester.tap(find.byKey(const Key('joint_move')));
      await settle(tester);
      expect(find.textContaining('Joint limits'), findsWidgets);
      await tester.ensureVisible(find.byKey(const Key('to_dining')));
      await tester.tap(find.byKey(const Key('to_dining')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('move_amount')), '100');
      await tester.pump();
      await tester.tap(find.byKey(const Key('move_go')));
      await settle(tester);
      expect(rec.events.where((e) => e.name == 'money_moved').length, 1);
      expect(find.textContaining('joint_move_mv_'), findsNothing);

      // Back to Mine: no move listed there.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Mine'));
      await settle(tester);
      expect(find.byKey(const Key('flex_section')), findsOneWidget);
      expect(find.byKey(const Key('moves_list')), findsNothing);
    });
  });

  test('analytics: the mode event carries only the mode; a move carries nothing', () {
    expect(AnalyticsSchema.clean('budget_mode_changed', {'mode': 'flex', 'category': 'dining', 'amount': 5}), {'mode': 'flex'});
    expect(AnalyticsSchema.clean('budget_mode_changed', {'mode': 'Groceries'}), isEmpty);
    expect(AnalyticsSchema.clean('money_moved', {'amount': 5, 'from': 'dining', 'to': 'groceries'}), isEmpty);
  });
}
