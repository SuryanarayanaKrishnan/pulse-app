// Renders the tab-tip and safe-to-spend screens to PNG at 390x844. Skipped unless
// SCREENS_DIR is set, so it never touches the normal test run:
//
//   SCREENS_DIR=/mnt/project-files/screens/v18 flutter test test/screens/home_tips_screens_test.dart
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
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/tour/tour_progress.dart';

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
    for (final tab in ['Home', 'Cards', 'Splits', 'Wealth']) {
      testWidgets('tab tip $tab ($mode)', (tester) async {
        await tester.runAsync(_loadFonts);
        PulseTheme.useGoogleFonts = false;
        PulseTheme.testFontFamily = 'PulseInter';
        addTearDown(() => PulseTheme.testFontFamily = null);
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final kv = MemoryKvStore();
        for (final t in TipTab.values) {
          if (t.key != tab.toLowerCase()) kv.data['tips.seen.${t.key}'] = '1';
        }
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ProviderScope(
              overrides: [
                tourKvProvider.overrideWithValue(kv),
                repositoryProvider.overrideWithValue(MockPulseRepository(latency: Duration.zero)),
                analyticsProvider.overrideWithValue(NoopAnalytics()),
                kvStoreProvider.overrideWithValue(MemoryKvStore()),
                sessionProvider.overrideWith((ref) => SessionController(onboarded: true, signedIn: true, connected: true)),
              ],
              child: const PulseApp(),
            ),
          ),
        );
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (tab != 'Home') await tester.tap(find.text(tab).last);
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        Future<void> shot(String name) async {
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

        await shot('tip-${tab.toLowerCase()}');
        if (tab == 'Home') {
          await tester.tap(find.text('Safe to spend today'));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 600));
          await shot('safe-to-spend-sheet');
        }
      }, skip: _dir == null);
    }
  }
}
