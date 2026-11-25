// Renders the custom-goals screens to PNG at 390x844. Skipped unless
// SCREENS_DIR is set, so it never touches the normal test run:
//
//   SCREENS_DIR=/mnt/project-files/screens/v11 flutter test test/screens
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
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/local/goal_store.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';

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
    testWidgets('goals screens ($mode)', (tester) async {
      await tester.runAsync(_loadFonts);
      PulseTheme.useGoogleFonts = false;
      PulseTheme.testFontFamily = 'PulseInter';
      addTearDown(() => PulseTheme.testFontFamily = null);
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final key = GlobalKey();

      Future<void> open(String location) async {
        final store = demoGoalStore();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ProviderScope(
              overrides: [
                goalStoreProvider.overrideWithValue(store),
                repositoryProvider.overrideWithValue(MockPulseRepository(latency: Duration.zero, goals: store)),
                analyticsProvider.overrideWithValue(NoopAnalytics()),
                kvStoreProvider.overrideWithValue(MemoryKvStore()),
                sessionProvider.overrideWith(
                  (ref) => SessionController(onboarded: true, signedIn: true, connected: true),
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
          final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final img = await b.toImage(pixelRatio: 1);
          final data = await img.toByteData(format: ui.ImageByteFormat.png);
          final f = File('$_dir/$name-$mode.png');
          await f.create(recursive: true);
          await f.writeAsBytes(data!.buffer.asUint8List());
        });
      }

      await open('/goals');
      await shot('goals-list');

      await open('/goals/g_car');
      await shot('goal-detail-on-track');
      await tester.tap(find.byKey(const Key('goal_add')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.enterText(find.byKey(const Key('contribution_amount')), '2500');
      await shot('goal-add-money');

      await open('/goals/g_japan');
      await shot('goal-detail-behind');

      await open('/goals/g_card');
      await shot('goal-detail-paydown');

      await open('/goals');
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump(const Duration(milliseconds: 600));
      await shot('goal-create');
      await tester.enterText(find.byKey(const Key('goal_name')), 'Emergency fund');
      await tester.enterText(find.byKey(const Key('goal_target')), '30000');
      await tester.enterText(find.byKey(const Key('goal_monthly')), '2000');
      await shot('goal-create-filled');

      await open('/home');
      await shot('home-goals-widget');
      await tester.tap(find.text('Safe to spend today'));
      await tester.pump(const Duration(milliseconds: 600));
      await shot('safe-to-spend-goals');

      await open('/wealth');
      await shot('wealth-goals');
    }, skip: _dir == null);
  }
}
