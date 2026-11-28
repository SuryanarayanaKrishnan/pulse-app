// Renders Recurring, Reports and the net worth chart to PNG at 390x844.
// Skipped unless SCREENS_DIR is set, so it never touches the normal run:
//
//   SCREENS_DIR=/mnt/project-files/screens/v14 flutter test test/screens/recurring_reports_screens_test.dart
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
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/nw_history.dart';
import 'package:pulse/core/household/household_keys.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/demo_household.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/data/recurring_providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/household/household_providers.dart';

import '../support/recurring_fixtures.dart';

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
    testWidgets('recurring, reports and net worth screens ($mode)', (
      tester,
    ) async {
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

      Future<void> open(String location, {bool household = false}) async {
        final store = household
            ? await demoJoinedHousehold(
                () async => [],
                now: DateTime(2026, 11, 14),
              )
            : null;
        const today = CalDate(2026, 11, 24);
        final history = [
          for (var i = 364; i >= 0; i--)
            () {
              final t = 364 - i;
              final net = 640000 + t * 2300 + (t % 17) * 900 - (t % 5) * 400;
              return NwPoint(
                today.addDays(-i),
                net + 410000,
                410000 - t * 300,
                estimated: i > 120,
              );
            }(),
        ];
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ProviderScope(
              overrides: [
                repositoryProvider.overrideWithValue(
                  MockPulseRepository(
                    latency: Duration.zero,
                    now: DateTime(2026, 11, 14),
                  ),
                ),
                transactionsProvider.overrideWith(
                  (ref) async => syntheticLedger(),
                ),
                recurringTodayProvider.overrideWithValue(
                  location == '/wealth' ? today : fixtureToday,
                ),
                if (location == '/wealth')
                  netWorthHistoryProvider.overrideWith((ref) async => history),
                analyticsProvider.overrideWithValue(NoopAnalytics()),
                kvStoreProvider.overrideWithValue(MemoryKvStore()),
                sessionProvider.overrideWith(
                  (ref) => SessionController(
                    onboarded: true,
                    signedIn: true,
                    connected: true,
                  ),
                ),
                if (store != null) ...[
                  householdStoreProvider.overrideWithValue(store),
                  householdKeyStoreProvider.overrideWithValue(
                    MemoryHouseholdKeyStore()
                      ..key = Uint8List.fromList(List.filled(32, 7)),
                  ),
                ],
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

      Future<void> scrollTo(Finder f, {double alignment = 0.3}) async {
        await tester.scrollUntilVisible(
          f,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(f), alignment: alignment);
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Recurring: list by status, then the calendar, then a detail sheet.
      await open('/recurring');
      await shot('recurring-list-top');
      await scrollTo(find.byKey(const Key('rec_paid')), alignment: 0.2);
      await shot('recurring-list-paid');
      await open('/recurring');
      await tester.tap(find.text('Calendar'));
      await tester.pump(const Duration(milliseconds: 600));
      await scrollTo(
        find.byKey(const Key('recurring_calendar')),
        alignment: 0.1,
      );
      await tester.tap(find.byKey(const Key('cal_day_22')));
      await tester.pump(const Duration(milliseconds: 500));
      await shot('recurring-calendar');
      await open('/recurring');
      await scrollTo(find.text('Cloudbox Storage').last, alignment: 0.4);
      await tester.tap(find.text('Cloudbox Storage').last);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await shot('recurring-detail-sheet');

      // Reports: category treemap, a selected tile, a longer range, members.
      await open('/reports');
      await shot('reports-treemap');
      await tester.tapAt(
        tester.getRect(find.byKey(const Key('treemap'))).topLeft +
            const Offset(20, 20),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await shot('reports-treemap-selected');
      await tester.tap(find.text('6M'));
      await tester.pump(const Duration(milliseconds: 600));
      await shot('reports-6m');
      await open('/reports', household: true);
      await tester.tap(find.text('By member'));
      await tester.pump(const Duration(milliseconds: 600));
      await shot('reports-by-member');

      // Wealth: range chips with the history chart, and assets vs liabilities.
      await open('/wealth');
      await tester.tap(find.text('1Y'));
      await tester.pump(const Duration(milliseconds: 600));
      await shot('wealth-networth-1y');
      await scrollTo(
        find.byKey(const Key('assets_vs_liabilities')),
        alignment: 0.3,
      );
      await shot('wealth-assets-vs-liabilities');
    }, skip: _dir == null);
  }
}
