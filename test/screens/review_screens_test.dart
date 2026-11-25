// Renders the swipe-to-review screens to PNG at 390x844. Skipped unless
// SCREENS_DIR is set, so it never touches the normal test run:
//
//   SCREENS_DIR=/mnt/project-files/screens/v9 flutter test test/screens
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
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/widgets/widgets.dart';
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
    testWidgets('review screens ($mode)', (tester) async {
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
      final kv = MemoryKvStore();
      final today = toDubaiDate(DateTime.now());
      kv.data['review.zero_days'] =
          '${today.addDays(-3).toIso()},${today.addDays(-2).toIso()},${today.addDays(-1).toIso()}';
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
              kvStoreProvider.overrideWithValue(kv),
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

      await shot('home-review-card');
      await tester.tap(find.byKey(const ValueKey('review-card-home')));
      await tester.pump(const Duration(seconds: 1));
      await shot('review-stack');

      final card = find.byKey(const ValueKey('review-card'));
      var g = await tester.startGesture(tester.getCenter(card));
      await g.moveBy(const Offset(50, 0));
      await g.moveBy(const Offset(50, 0));
      await tester.pump();
      await shot('review-swipe-right');
      await g.moveBy(const Offset(-110, 0));
      await g.moveBy(const Offset(-110, 0));
      await tester.pump();
      await shot('review-swipe-left');
      await g.up();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.widgetWithText(PrimaryButton, 'Fix it'));
      await tester.pump(const Duration(seconds: 1));
      await shot('review-fix-category');
      await tester.tapAt(const Offset(195, 15));
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(card);
      await tester.pump(const Duration(seconds: 1));
      await shot('review-details');
      await tester.tapAt(const Offset(195, 15));
      await tester.pump(const Duration(seconds: 1));

      while (find.widgetWithText(PrimaryButton, 'Looks right').evaluate().isNotEmpty) {
        await tester.tap(find.widgetWithText(PrimaryButton, 'Looks right'));
        await tester.pump(const Duration(seconds: 1));
      }
      await shot('review-inbox-zero');
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pump(const Duration(seconds: 1));
      await shot('home-inbox-zero');

      await tester.tap(find.text('Which card should I use?'));
      await tester.pump(const Duration(seconds: 1));
      await shot('sheet-above-tab-bar');
    }, skip: _dir == null);
  }
}
