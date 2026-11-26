import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/bugreport/annotate.dart';
import 'package:pulse/bugreport/bug_report_sheet.dart';
import 'package:pulse/bugreport/report.dart';
import 'package:pulse/bugreport/transport.dart';
import 'package:pulse/core/theme/theme.dart';

const _device = DeviceSnapshot(
  appVersion: '1.0.0',
  build: '5',
  platform: 'ios',
  osVersion: 'iOS 26.1',
  locale: 'en-US',
  theme: 'dark',
  route: '/cards',
);

class _T implements BugReportTransport {
  @override
  DeliveryMethod get method => DeliveryMethod.local;
  @override
  bool get available => true;
  @override
  Future<SendOutcome> send(BugReport r) async => SendOutcome.ok(method);
}

void main() {
  testWidgets(
    'the sheet survives the launcher disposing its screenshot, resizes and close',
    (tester) async {
      PulseTheme.useGoogleFonts = false;
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final shot = (await tester.runAsync(
        () => createTestImage(width: 390, height: 844),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          theme: PulseTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  await showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => BugReportSheet(
                      screenshot: shot,
                      device: _device,
                      logLines: const [],
                      local: _T(),
                    ),
                  );
                  // What BugReportLauncher.launch does the moment the route pops,
                  // before the close animation has finished painting.
                  shot.dispose();
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final sizes = [
        const Size(1170, 2532),
        const Size(1260, 2400),
        const Size(1350, 1500),
        const Size(1170, 2532),
      ];
      for (final s in sizes) {
        tester.view.physicalSize = s;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
      }
      await tester.scrollUntilVisible(
        find.byKey(const Key('bug-annotate')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('bug-annotate')));
      await tester.pumpAndSettle();
      for (final s in sizes) {
        tester.view.physicalSize = s;
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      // Close the sheet; the screenshot is disposed while it animates out.
      await tester.tapAt(const Offset(5, 5));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull);
        // Whatever is still on screen must not paint a disposed image (on a
        // device that is the "non-genuine Image" rasterization error).
        for (final w in tester.widgetList<CustomPaint>(
          find.byKey(const Key('bug-canvas'), skipOffstage: false),
        )) {
          final p = w.painter! as AnnotationPainter;
          expect(
            p.image!.debugDisposed,
            isFalse,
            reason: 'frame $i paints a disposed screenshot',
          );
        }
      }
      await tester.pumpAndSettle();
      expect(shot.debugDisposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
