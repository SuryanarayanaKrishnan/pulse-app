// Renders the household screens to PNG at 390x844. Skipped unless SCREENS_DIR
// is set, so it never touches the normal test run:
//
//   SCREENS_DIR=/mnt/project-files/screens/v12 flutter test test/screens/household_screens_test.dart
@TestOn('vm')
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:pulse/data/demo_household.dart';
import 'package:pulse/data/goal_service.dart';
import 'package:pulse/data/local/goal_store.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/household/household_providers.dart';

final _dir = Platform.environment['SCREENS_DIR'];

Future<void> _loadFonts() async {
  Future<ByteData> bytes(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());

  const inter = '/usr/share/fonts/opentype/inter';
  final text = FontLoader('PulseInter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    text.addFont(bytes('$inter/Inter-$w.otf'));
  }
  await text.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      bytes(
        '${Platform.environment['FLUTTER_ROOT'] ?? '/home/user/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    );
  await icons.load();
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('household screens ($mode)', (tester) async {
      await tester.runAsync(_loadFonts);
      PulseTheme.useGoogleFonts = false;
      PulseTheme.testFontFamily = 'PulseInter';
      addTearDown(() => PulseTheme.testFontFamily = null);
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final key = GlobalKey();

      Future<void> open(String location, {bool joined = true}) async {
        final goals = demoGoalStore();
        final repo = MockPulseRepository(latency: Duration.zero, goals: goals);
        final svc = GoalService(store: goals, assets: repo.assets);
        final MemoryHouseholdStore store;
        if (joined) {
          store = await demoJoinedHousehold(() => demoOwnRows(repo, svc));
          // a few of my own items, marked
          final txs = await repo.transactions();
          await store.setOwnership(
            HTable.transactions,
            txs[0].id,
            owner: Owner.shared,
          );
          await store.setOwnership(
            HTable.transactions,
            txs[1].id,
            owner: demoPartner,
          );
          await store.setOwnership(
            HTable.transactions,
            txs[2].id,
            isPrivate: true,
          );
          final assets = await repo.assets();
          await store.setOwnership(
            HTable.lines,
            assets.firstWhere((a) => !a.isLiability).id,
            owner: Owner.shared,
          );
          await store.setOwnership(
            HTable.goals,
            'g_japan',
            owner: Owner.shared,
          );
        } else {
          store = MemoryHouseholdStore(loader: () => demoOwnRows(repo, svc));
        }
        final keys = MemoryHouseholdKeyStore()
          ..key = Uint8List.fromList(List.generate(32, (i) => i + 3));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ProviderScope(
              overrides: [
                goalStoreProvider.overrideWithValue(goals),
                repositoryProvider.overrideWithValue(repo),
                householdStoreProvider.overrideWithValue(store),
                householdKeyStoreProvider.overrideWithValue(keys),
                analyticsProvider.overrideWithValue(NoopAnalytics()),
                kvStoreProvider.overrideWithValue(MemoryKvStore()),
                sessionProvider.overrideWith(
                  (ref) => SessionController(
                    onboarded: true,
                    signedIn: true,
                    connected: true,
                  ),
                ),
              ],
              child: PulseApp(initialLocation: location),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 3));
      }

      Future<void> shot(String name) async {
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.runAsync(() async {
          final b =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final img = await b.toImage(pixelRatio: 1);
          final data = await img.toByteData(format: ui.ImageByteFormat.png);
          final f = File('$_dir/$name-$mode.png');
          await f.create(recursive: true);
          await f.writeAsBytes(data!.buffer.asUint8List());
        });
      }

      Future<void> scroll(double dy) async {
        await tester.drag(find.byType(Scrollable).first, Offset(0, -dy));
        await tester.pump(const Duration(milliseconds: 600));
      }

      // Before: no household yet.
      await open('/household', joined: false);
      await shot('household-intro');
      await tester.tap(find.byKey(const Key('household_start')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.enterText(find.byKey(const Key('household_myname')), 'Maya');
      await shot('household-create');

      await open('/household', joined: false);
      await tester.tap(find.byKey(const Key('household_join')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.enterText(
        find.byKey(const Key('join_code')),
        'PULSE-HH1-7QXKD-M4VNA-2ZP5T-JRE3W-6HGSC',
      );
      await tester.enterText(find.byKey(const Key('join_myname')), 'Omar');
      await shot('household-join');

      // With a household.
      await open('/household');
      await shot('household-home');
      await scroll(500);
      await shot('household-home-bills');

      await open('/household');
      await tester.tap(find.byKey(const Key('household_invite')));
      await tester.pump(const Duration(milliseconds: 600));
      await shot('household-invite');

      await open('/household');
      await tester.tap(find.byKey(const Key('bill_b_rent')));
      await tester.pump(const Duration(milliseconds: 600));
      await shot('household-bill-split');

      await open('/budget');
      await shot('budget-mine-toggle');
      await tester.tap(find.text('Joint'));
      await tester.pump(const Duration(milliseconds: 600));
      await shot('budget-joint');
      await scroll(560);
      await shot('budget-joint-people-bills');

      await open('/wealth');
      await tester.tap(find.text('Joint'));
      await tester.pump(const Duration(milliseconds: 600));
      await shot('wealth-joint');
      await scroll(500);
      await shot('wealth-joint-lines');

      await open('/wealth');
      await shot('wealth-mine-toggle');

      final merchant = (await MockPulseRepository(
        latency: Duration.zero,
      ).transactions()).first.merchant;
      await open('/activity');
      await tester.tap(find.text(merchant).first);
      await tester.pump(const Duration(milliseconds: 600));
      await shot('tx-detail-household');
      await tester.tap(find.byKey(const Key('owner_row')));
      await tester.pump(const Duration(milliseconds: 600));
      await shot('ownership-sheet');
      await open('/settings');
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings_household')),
        200,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
      await shot('settings-household');
    }, skip: _dir == null);
  }
}
