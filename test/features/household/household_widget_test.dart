import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/household/household_keys.dart';
import 'package:pulse/core/household/household_models.dart';
import 'package:pulse/core/household/household_scope.dart';
import 'package:pulse/core/household/household_store.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/widgets/widgets.dart' show PrimaryButton;
import 'package:pulse/data/demo_household.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/features/transactions/tx_detail_sheet.dart';
import 'package:pulse/features/household/ownership_widgets.dart';
import 'package:pulse/household/household_providers.dart';

class Rec extends NoopAnalytics {
  final events = <AnalyticsEvent>[];
  @override
  void track(AnalyticsEvent event) => events.add(event);
}

HRow _tx(String id, String merchant, int amount, {String cat = 'groceries'}) => HRow(
  table: HTable.transactions,
  id: id,
  values: {
    'category_id': cat,
    'amount_minor': amount,
    'currency': 'AED',
    'direction': 'debit',
    'merchant': merchant,
    'posted_at': DateTime.now().toUtc().toIso8601String(),
    'excluded': false,
  },
);

HRow _line(String id, String name, int value, {bool liability = false, bool priv = false}) => HRow(
  table: HTable.lines,
  id: id,
  isPrivate: priv,
  values: {'name': name, 'liability': liability, 'value_minor': value, 'currency': 'AED'},
);

class Rig {
  Rig({this.joined = false}) {
    own = [
      _tx('t1', 'Carrefour', 25000),
      _tx('t2', 'Surprise ring', 90000, cat: 'shopping'),
      _line('account:a1', 'Salary account', 20000000),
      _line('secret', 'Hidden savings', 7000000, priv: true),
    ];
  }
  final bool joined;
  late List<HRow> own;
  final rec = Rec();
  final keys = MemoryHouseholdKeyStore();
  late MemoryHouseholdStore store;

  Future<List<Override>> overrides() async {
    if (joined) {
      store = await demoJoinedHousehold(() async => own);
      keys.key = Uint8List.fromList(List.filled(32, 7));
    } else {
      store = MemoryHouseholdStore(own: own);
    }
    return [
      householdStoreProvider.overrideWithValue(store),
      householdKeyStoreProvider.overrideWithValue(keys),
      analyticsProvider.overrideWithValue(rec),
      repositoryProvider.overrideWithValue(MockPulseRepository(latency: Duration.zero)),
      kvStoreProvider.overrideWithValue(MemoryKvStore()),
      sessionProvider.overrideWith((ref) => SessionController(onboarded: true, signedIn: true, connected: true)),
    ];
  }
}

Future<void> _size(WidgetTester tester) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> pumpApp(WidgetTester tester, Rig rig, String location) async {
  await _size(tester);
  await tester.pumpWidget(
    ProviderScope(overrides: await rig.overrides(), child: PulseApp(initialLocation: location)),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
}

Future<void> pumpWidgetUnderTest(WidgetTester tester, Rig rig, Widget home) async {
  await _size(tester);
  await tester.pumpWidget(
    ProviderScope(overrides: await rig.overrides(), child: MaterialApp(theme: PulseTheme.light, home: home)),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Scrolls a list row clear of the floating tab bar.
Future<void> reveal(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200);
  await Scrollable.ensureVisible(tester.element(f), alignment: 0.4);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  group('Settings > Household', () {
    testWidgets('Settings shows a Household row that opens the screen', (tester) async {
      await pumpApp(tester, Rig(), '/settings');
      final row = find.byKey(const Key('settings_household'));
      await reveal(tester, row);
      expect(find.text('Plan money together, privately'), findsOneWidget);
      await tester.tap(row);
      await settle(tester);
      expect(find.text('Start a household'), findsOneWidget);
      expect(find.text('Private stays private'), findsOneWidget);
    });

    testWidgets('start a household: names, creates, reports only the event', (tester) async {
      final rig = Rig();
      await pumpApp(tester, rig, '/household');
      await tester.tap(find.byKey(const Key('household_start')));
      await settle(tester);
      expect(tester.widget<PrimaryButton>(find.byKey(const Key('household_create'))).onPressed, isNull, reason: 'needs your name');
      await tester.enterText(find.byKey(const Key('household_myname')), 'Maya');
      await tester.pump();
      await tester.tap(find.byKey(const Key('household_create')));
      await settle(tester);
      expect(find.text('Our household'), findsWidgets);
      expect(find.byKey(const Key('member_Maya')), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect([for (final e in rig.rec.events) e.name], ['household_created']);
      expect(rig.rec.events.single.properties, isEmpty);
      expect(await rig.keys.load(), isNotNull);
    });

    testWidgets('invite shows a QR and a code that decodes back to the household', (tester) async {
      final rig = Rig(joined: true);
      await pumpApp(tester, rig, '/household');
      await tester.tap(find.byKey(const Key('household_invite')));
      await settle(tester);
      expect(find.byKey(const Key('invite_qr')), findsOneWidget);
      final code = tester.widget<SelectableText>(find.byKey(const Key('invite_code'))).data!;
      expect(code, startsWith('PULSE-HH1-'));
    });

    testWidgets('join: a mistyped code is refused calmly; a good one joins', (tester) async {
      final rig = Rig();
      await pumpApp(tester, rig, '/household');
      await tester.tap(find.byKey(const Key('household_join')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('join_code')), 'PULSE-HH1-AAAAA-BBBBB');
      await tester.enterText(find.byKey(const Key('join_myname')), 'Omar');
      await tester.pump();
      await tester.tap(find.byKey(const Key('join_go')));
      await settle(tester);
      expect(find.textContaining("doesn't look right"), findsOneWidget);
      expect(await rig.store.config(), isNull);
      expect(rig.rec.events, isEmpty);

      // A real invite, made by another phone's service.
      final other = Rig();
      await other.overrides();
      final inviter = ProviderContainer(overrides: await other.overrides());
      addTearDown(inviter.dispose);
      await inviter.read(householdServiceProvider).create(householdName: 'Us', myName: 'Maya');
      final code = (await inviter.read(householdServiceProvider).inviteCode())!;

      await tester.enterText(find.byKey(const Key('join_code')), code);
      await tester.pump();
      await tester.tap(find.byKey(const Key('join_go')));
      await settle(tester);
      expect(find.byKey(const Key('member_Omar')), findsOneWidget);
      expect([for (final e in rig.rec.events) e.name], ['household_member_joined']);
    });

    testWidgets('leave asks first, then forgets the household', (tester) async {
      final rig = Rig(joined: true);
      await pumpApp(tester, rig, '/household');
      expect(find.text('Maya & Omar'), findsOneWidget);
      final leave = find.byKey(const Key('household_leave'));
      await reveal(tester, leave);
      await tester.tap(leave);
      await settle(tester);
      expect(find.text('Leave this household?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(await rig.store.config(), isNotNull);
      await tester.tap(leave);
      await settle(tester);
      await tester.tap(find.byKey(const Key('leave_confirm')));
      await settle(tester);
      expect(await rig.store.config(), isNull);
      expect(await rig.keys.load(), isNull);
      expect(find.text('Start a household'), findsOneWidget);
    });

    testWidgets('a shared bill can be added with a split and shows what each pays', (tester) async {
      final rig = Rig(joined: true);
      await pumpApp(tester, rig, '/household');
      expect(find.byKey(const Key('bill_b_rent')), findsOneWidget);
      expect(find.textContaining('your share AED 3,250'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bill_b_rent')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('bill_amount')), '700');
      await tester.pump();
      await tester.tap(find.byKey(const Key('bill_save')));
      await settle(tester);
      expect((await rig.store.bills()).firstWhere((b) => b.id == 'b_rent').amountMinor, 70000);
    });
  });

  group('assign and private', () {
    testWidgets('the sheet marks an item as the partner\'s, shared, or private', (tester) async {
      final rig = Rig(joined: true);
      await pumpWidgetUnderTest(
        tester,
        rig,
        Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => showOwnershipSheet(c, table: 'transactions', id: 't1', title: 'Carrefour'),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
      expect(find.text('Who is this for?'), findsOneWidget);
      expect(find.text("Omar's"), findsOneWidget);

      await tester.tap(find.byKey(const Key('owner_m_omar')));
      await settle(tester);
      expect((await rig.store.ownership('transactions', 't1')).owner, 'm_omar');

      await tester.tap(find.byKey(const Key('owner_shared')));
      await settle(tester);
      expect((await rig.store.ownership('transactions', 't1')).owner, Owner.shared);

      await tester.tap(find.byKey(const Key('owner_private')));
      await settle(tester);
      final o = await rig.store.ownership('transactions', 't1');
      expect(o.isPrivate, isTrue);
      expect(o.owner, Owner.shared, reason: 'private is a separate flag');
    });

    testWidgets('without a household there is no owner row to clutter a detail sheet', (tester) async {
      final rig = Rig();
      await pumpWidgetUnderTest(
        tester,
        rig,
        const Scaffold(body: OwnerRow(table: 'transactions', id: 't1', title: 'x')),
      );
      expect(find.byKey(const Key('owner_row')), findsNothing);
    });

    testWidgets('with a household the row names the owner', (tester) async {
      final rig = Rig(joined: true);
      await pumpWidgetUnderTest(
        tester,
        rig,
        const Scaffold(body: OwnerRow(table: 'transactions', id: 't1', title: 'x')),
      );
      expect(find.text('Mine'), findsOneWidget);
    });
  });

  group('transaction detail', () {
    final tx = Transaction(
      id: 't1',
      merchant: 'Carrefour',
      amount: 250,
      category: SpendCategory.groceries,
      date: DateTime(2026, 11, 3, 18),
      source: TxSource.manual,
      cardId: 'c',
      accountLabel: 'Salary',
    );

    testWidgets('has a Household row once there is a household, and not before', (tester) async {
      await pumpWidgetUnderTest(tester, Rig(), Scaffold(body: SingleChildScrollView(child: TxDetailSheet(tx: tx))));
      expect(find.text('Carrefour'), findsWidgets);
      expect(find.byKey(const Key('owner_row')), findsNothing);
    });

    testWidgets('the row opens the sheet from the detail', (tester) async {
      await pumpWidgetUnderTest(tester, Rig(joined: true), Scaffold(body: SingleChildScrollView(child: TxDetailSheet(tx: tx))));
      await tester.tap(find.byKey(const Key('owner_row')));
      await settle(tester);
      expect(find.text('Who is this for?'), findsOneWidget);
    });
  });

  group('joint toggles', () {
    testWidgets('Budget: no toggle without a household', (tester) async {
      await pumpApp(tester, Rig(), '/budget');
      expect(find.byKey(const Key('scope_toggle')), findsNothing);
      expect(find.text('Spent this month'), findsOneWidget);
    });

    testWidgets('Budget: Joint shows limits, who spent it, bills and goals', (tester) async {
      await pumpApp(tester, Rig(joined: true), '/budget');
      expect(find.byKey(const Key('scope_toggle')), findsOneWidget);
      expect(find.byKey(const Key('joint_budget')), findsNothing);
      await tester.tap(find.text('Joint'));
      await settle(tester);
      expect(find.byKey(const Key('joint_budget')), findsOneWidget);
      expect(find.text('Household spent this month'), findsOneWidget);
      expect(find.text('Joint limits'), findsOneWidget);
      expect(find.text('Groceries'), findsWidgets);
      expect(find.byKey(const Key('by_member')), findsOneWidget);
      await tester.tap(find.text('Mine'));
      await settle(tester);
      expect(find.byKey(const Key('joint_budget')), findsNothing);
    });

    testWidgets('Wealth: Joint counts shared and partner items and leaves private ones out', (tester) async {
      final rig = Rig(joined: true);
      await pumpApp(tester, rig, '/wealth');
      await tester.tap(find.text('Joint'));
      await settle(tester);
      expect(find.byKey(const Key('joint_networth')), findsOneWidget);
      expect(find.text('Joint net worth'), findsOneWidget);
      expect(find.text('Marina apartment'), findsOneWidget);
      expect(find.text('Omar current account'), findsOneWidget);
      expect(find.text('Salary account'), findsOneWidget);
      // my private line is in my own data but never in the joint list
      expect(find.text('Hidden savings'), findsNothing);
      expect(find.byKey(const Key('nw_by_owner')), findsOneWidget);
    });
  });
}
