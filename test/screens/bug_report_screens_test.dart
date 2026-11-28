// Renders the bug report sheet to PNG at 390x844 (light and dark).
// Skipped unless SCREENS_DIR is set:
//
//   SCREENS_DIR=/mnt/project-files/screens/v17 flutter test test/screens/bug_report_screens_test.dart
@TestOn('vm')
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/bugreport/bug_report_sheet.dart';
import 'package:pulse/bugreport/report.dart';
import 'package:pulse/bugreport/transport.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/theme/tokens.dart';

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

class _NoShare implements BugReportTransport {
  @override
  DeliveryMethod get method => DeliveryMethod.local;
  @override
  bool get available => true;
  @override
  Future<SendOutcome> send(BugReport r) async =>
      const SendOutcome.ok(DeliveryMethod.local);
}

/// A stand-in for the screen a tester was on (made-up numbers).
class _FakeHome extends StatelessWidget {
  const _FakeHome();
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    Widget row(String a, String b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(a)),
          Text(b, style: context.tt.titleMedium),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Safe to spend', style: context.tt.bodyMedium),
          Text('AED 4,280', style: context.tt.headlineMedium),
          const SizedBox(height: 12),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          row('Spinneys', '-AED 124.26'),
          row('Careem', '-AED 31.00'),
          row('Salary', '+AED 18,500'),
          row('Rent', '-AED 6,200'),
        ],
      ),
    );
  }
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('bug report sheet ($mode)', (tester) async {
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
      final shotKey = GlobalKey();

      Widget app(Widget home) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? PulseTheme.dark : PulseTheme.light,
        home: home,
      );

      // 1. The "screenshot": the fake home screen, captured like the real flow.
      await tester.pumpWidget(
        RepaintBoundary(key: shotKey, child: app(const _FakeHome())),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final image = (await tester.runAsync(() async {
        final b =
            shotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        return b.toImage(pixelRatio: 2);
      }))!;

      late BuildContext ctx;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: app(
            Builder(
              builder: (c) {
                ctx = c;
                return const _FakeHome();
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      showModalBottomSheet<void>(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        constraints: BoxConstraints(maxHeight: 844 * 0.94),
        builder: (_) => BugReportSheet(
          screenshot: image,
          device: const DeviceSnapshot(
            appVersion: '1.0.0',
            build: '12',
            platform: 'android',
            osVersion: 'Android 14',
            locale: 'en-AE',
            theme: 'light',
            route: '/home',
          ),
          logLines: const [
            '10:02:11 route /home',
            '10:02:19 event first_capture',
            '10:02:40 route /settings',
            '10:02:44 error FormatException: [text]',
          ],
          local: _NoShare(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();

      Future<void> shot(String name) async {
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

      await tester.enterText(
        find.byKey(const Key('bug-note')),
        'The total looks off after I add a card',
      );
      await tester.pump();
      await shot('bug-report-sheet');

      // 2. Annotate: pen circle and a hide box.
      await tester.ensureVisible(find.byKey(const Key('bug-annotate')));
      await tester.tap(find.byKey(const Key('bug-annotate')));
      await tester.pumpAndSettle();
      final canvas = tester.getRect(find.byKey(const Key('bug-canvas')));
      Future<void> drag(
        Offset a,
        Offset b, [
        List<Offset> via = const [],
      ]) async {
        final g = await tester.startGesture(canvas.topLeft + a);
        for (final p in [...via, b]) {
          await g.moveTo(canvas.topLeft + p);
        }
        await g.up();
        await tester.pump();
      }

      await drag(const Offset(20, 90), const Offset(20, 90), [
        const Offset(80, 70),
        const Offset(150, 90),
        const Offset(130, 130),
        const Offset(60, 135),
        const Offset(20, 100),
      ]);
      await tester.tap(find.byKey(const Key('bug-tool-blur')));
      await tester.pump();
      await drag(const Offset(15, 190), const Offset(190, 250), [
        const Offset(60, 200),
        const Offset(120, 230),
      ]);
      await shot('bug-report-annotate');

      // 3. Back to the sheet, masked, preview and log visible.
      await tester.tap(find.byKey(const Key('bug-annotate-done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bug-mask-all')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('bug-toggle-log')));
      await tester.tap(find.byKey(const Key('bug-toggle-log')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('bug-share')));
      await shot('bug-report-preview');
    }, skip: _dir == null);
  }
}
