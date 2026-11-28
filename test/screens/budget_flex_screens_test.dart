// Renders the flex budget screens to PNG at 390x844. Skipped unless
// SCREENS_DIR is set, so it never touches the normal test run:
//
//   SCREENS_DIR=/mnt/project-files/screens/v13 flutter test test/screens/budget_flex_screens_test.dart
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
    testWidgets('flex budget screens ($mode)', (tester) async {
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

      Future<void> open(String location) async {
        final repo = MockPulseRepository(latency: Duration.zero);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ProviderScope(
              overrides: [
                repositoryProvider.overrideWithValue(repo),
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

      Future<void> scrollTo(Finder f, {double alignment = 0.3}) async {
        await tester.scrollUntilVisible(
          f,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(f), alignment: alignment);
        await tester.pump(const Duration(milliseconds: 500));
      }

      await open('/budget');
      await shot('budget-flex-top');
      await scrollTo(find.byKey(const Key('flex_hero')), alignment: 0.05);
      await shot('budget-flex-flexible');

      await tester.tap(find.textContaining('Fixed '));
      await tester.pump(const Duration(milliseconds: 500));
      await shot('budget-flex-fixed');

      await tester.tap(find.textContaining('Non-monthly '));
      await tester.pump(const Duration(milliseconds: 500));
      await shot('budget-flex-nonmonthly');

      await tester.tap(find.byKey(const Key('plan_travel')));
      await tester.pump(const Duration(milliseconds: 600));
      await shot('budget-category-plan-sheet');

      await open('/budget');
      await tester.tap(find.textContaining('Categories').first);
      await tester.pump(const Duration(milliseconds: 600));
      await shot('budget-categories-mode');

      await open('/budget');
      await tester.tap(find.text('Move money').first);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byKey(const Key('to_dining')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('move_amount')), '300');
      await tester.pump();
      await shot('budget-move-money');
      await tester.tap(find.byKey(const Key('move_go')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 1200));
      await shot('budget-move-done-undo');

      await open('/budget');
      await scrollTo(find.byKey(const Key('cover_dining')), alignment: 0.5);
      await shot('budget-overspend-red');
      await tester.tap(find.byKey(const Key('cover_dining')));
      await tester.pump(const Duration(milliseconds: 600));
      await shot('budget-cover-overspend');

      await open('/budget');
      await scrollTo(find.byKey(const Key('chart-dot-flow')), alignment: 0.4);
      await tester.tap(find.byKey(const Key('chart-dot-flow')));
      await tester.pump(const Duration(milliseconds: 900));
      await scrollTo(find.byKey(const Key('sankey_section')), alignment: 0.02);
      await shot('budget-sankey');
      final r = tester.getRect(find.byKey(const Key('sankey_canvas')));
      await tester.tapAt(Offset(r.left + 78 + 95, r.top + 8 + 40));
      await tester.pump(const Duration(milliseconds: 600));
      await shot('budget-sankey-flow');
      await scrollTo(find.byKey(const Key('flow_detail')), alignment: 0.3);
      await shot('budget-sankey-flow-list');
    }, skip: _dir == null);
  }
}
