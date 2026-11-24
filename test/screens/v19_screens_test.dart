// Renders Home, Cards, a card detail, Budget and Wealth to PNG at 390x844.
// Skipped unless SCREENS_DIR is set:
//
//   SCREENS_DIR=/mnt/project-files/screens/v19 SCREENS_PREFIX=after flutter test test/screens/v19_screens_test.dart
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
import 'package:pulse/core/engine/card_art.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/widgets/card_face.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';

final _dir = Platform.environment['SCREENS_DIR'];
final _prefix = Platform.environment['SCREENS_PREFIX'] ?? 'after';

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
  // The bundled display face, when present (after the redesign).
  final display = File('assets/fonts/Fraunces_600SemiBold.ttf');
  if (display.existsSync()) {
    final f = FontLoader('PulseDisplay')..addFont(bytes(display.path));
    await f.load();
  }
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('v19 screens ($mode)', (tester) async {
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
          final f = File('$_dir/$_prefix-$name-$mode.png');
          await f.create(recursive: true);
          await f.writeAsBytes(data!.buffer.asUint8List());
        });
      }

      await shot('home');
      await tester.tap(find.text('Budget').last);
      await shot('budget');
      await tester.tap(find.text('Wealth').last);
      await shot('wealth');
      await tester.tap(find.text('Cards').last);
      await shot('cards');
      await tester.tapAt(const Offset(195, 440));
      await shot('card-detail');
    }, skip: _dir == null);
  }

  testWidgets('v19 card catalog gallery', (tester) async {
    await tester.runAsync(_loadFonts);
    PulseTheme.useGoogleFonts = false;
    PulseTheme.testFontFamily = 'PulseInter';
    addTearDown(() => PulseTheme.testFontFamily = null);
    tester.view.physicalSize = const Size(780, 1900);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final entries = CardArts.byCatalogId.entries.toList();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: PulseTheme.light,
          home: Scaffold(
            body: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(12),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.586,
              children: [
                for (final e in entries)
                  CardFace(art: e.value, last4: '4821', name: e.key),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File('$_dir/$_prefix-card-catalog.png');
      await f.create(recursive: true);
      await f.writeAsBytes(data!.buffer.asUint8List());
    });
  }, skip: _dir == null);
}
