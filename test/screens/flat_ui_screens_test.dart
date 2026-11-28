// Renders the root tabs to PNG at 390x844 (flat UI before/after). Skipped unless
// SCREENS_DIR is set, so it never touches the normal test run:
//
//   SCREENS_DIR=/mnt/project-files/screens/v8 flutter test test/screens
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
    testWidgets('root tabs ($mode)', (tester) async {
      await tester.runAsync(_loadFonts);
      PulseTheme.useGoogleFonts = false;
      PulseTheme.testFontFamily = 'PulseInter';
      PulseTheme.testDisplayFamily = 'PulseInter';
      addTearDown(() => PulseTheme.testFontFamily = null);
      tester.view.physicalSize = const Size(390 * 3, 1500 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              repositoryProvider.overrideWithValue(
                MockPulseRepository(latency: Duration.zero),
              ),
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
            child: const PulseApp(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));

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

      Future<void> tab(String label) async {
        await tester.tap(find.text(label).last);
        await tester.pump(const Duration(milliseconds: 800));
      }

      await shot('home');
      await tab('Budget');
      await shot('budget');
      await tab('Cards');
      await shot('cards');
      await tester.tap(find.text('Credit'));
      await shot('cards-credit');
      await tester.tap(find.text('Accounts'));
      await shot('accounts');
      await tab('Wealth');
      await shot('wealth');
      final gold = find.byKey(const Key('wealth-tile-gold'));
      if (gold.evaluate().isNotEmpty) {
        await tester.tap(gold);
        await tester.pump(const Duration(milliseconds: 800));
        await shot('wealth-gold');
      }
    }, skip: _dir == null);
  }
}
