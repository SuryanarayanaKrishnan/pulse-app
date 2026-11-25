// Renders the category icon family and the screens that use it to PNG at 390x844. Skipped unless
// SCREENS_DIR is set, so it never touches the normal test run:
//
//   SCREENS_DIR=/mnt/project-files/screens/v10 flutter test test/screens
@TestOn('vm')
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/icons/glyphs.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/theme/tokens.dart';
import 'package:pulse/core/widgets/widgets.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/core/router/router.dart';
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

class _Sheet extends StatelessWidget {
  const _Sheet(this.dark);
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    Widget cell(Widget icon, String label) => SizedBox(
      width: 86,
      child: Column(
        children: [
          icon,
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.tt.labelSmall,
            maxLines: 2,
          ),
        ],
      ),
    );
    Widget section(String title, List<Widget> kids) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 10),
          child: Text(title, style: context.tt.titleSmall),
        ),
        Wrap(runSpacing: 14, children: kids),
      ],
    );
    final defaults = [
      for (final cat in [
        ...SpendCategory.defaults,
        const SpendCategory('subscriptions', 'Subscriptions'),
        const SpendCategory('gifts', 'Gifts & Charity'),
        const SpendCategory('transfer', 'Transfers'),
        const SpendCategory('other_income', 'Other Income'),
      ])
        cell(CategoryIcon.well(cat, size: 48), cat.label),
    ];
    final filled = [
      for (final cat in SpendCategory.defaults.take(8))
        cell(CategoryIcon.well(cat, size: 48, filled: true), cat.label),
    ];
    final custom = [
      for (final g in customGlyphs)
        cell(
          CategoryIcon.well(
            SpendCategory.custom('c_${g.key}', g.label, iconKey: g.key),
            size: 48,
          ),
          g.label,
        ),
    ];
    final sizes = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final s in [16.0, 20.0, 24.0, 32.0, 48.0])
          CategoryIcon(SpendCategory.travel, size: s),
        for (final s in [16.0, 24.0, 48.0])
          CategoryIcon(SpendCategory.health, size: s, filled: true),
      ],
    );
    return Container(
      color: c.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pulse category icons', style: context.tt.headlineMedium),
            Text(
              '24 unit grid, 1.75 stroke, round caps and joins',
              style: context.tt.bodyMedium,
            ),
            section('Default categories', defaults),
            section('Filled style', filled),
            section('Custom category glyphs', [
              ...custom,
              cell(
                CategoryIcon.well(
                  const SpendCategory.custom('c_none', 'Generic'),
                  size: 48,
                ),
                'Fallback',
              ),
            ]),
            section('Sizes 16 to 48', [sizes]),
          ],
        ),
      ),
    );
  }
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('category icons ($mode)', (tester) async {
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

      // the icon sheet, tall
      tester.view.physicalSize = const Size(390 * 2, 1720 * 2);
      tester.view.devicePixelRatio = 2;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? PulseTheme.dark : PulseTheme.light,
            home: Scaffold(body: _Sheet(dark)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(() async {
        final b =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 2);
        final data = await img.toByteData(format: ui.ImageByteFormat.png);
        final f = File('$_dir/icon-sheet-$mode.png');
        await f.create(recursive: true);
        await f.writeAsBytes(data!.buffer.asUint8List());
      });

      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      final repo = MockPulseRepository(latency: Duration.zero);
      await repo.createCategory(name: 'Coffee runs', iconKey: 'coffee');
      await repo.createCategory(name: 'Pets', iconKey: 'paw');
      await repo.createCategory(name: 'Gym', iconKey: 'dumbbell');
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
            child: const PulseApp(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));

      void go(String route) {
        GoRouter.of(tester.element(find.byType(Scaffold).first)).go(route);
      }

      await shot('home');
      go(Routes.budget);
      await tester.pump(const Duration(seconds: 1));
      await shot('budget');
      go(Routes.activity);
      await tester.pump(const Duration(seconds: 1));
      await shot('activity');
      go(Routes.categories);
      await tester.pump(const Duration(seconds: 1));
      await shot('categories');
      go(Routes.automations);
      await tester.pump(const Duration(seconds: 1));
      await shot('automations');
      go(Routes.categories);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byTooltip('New category'));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('icon_coffee')));
      await shot('new-category-icon-picker');
      await tester.tapAt(const Offset(195, 15));
      await tester.pump(const Duration(seconds: 1));
      go(Routes.review);
      await tester.pump(const Duration(seconds: 1));
      await shot('review');
    }, skip: _dir == null);
  }
}
