import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/bugreport/annotate.dart';
import 'package:pulse/bugreport/bug_report_sheet.dart';
import 'package:pulse/bugreport/report.dart';
import 'package:pulse/bugreport/transport.dart';
import 'package:pulse/core/theme/theme.dart';

const _device = DeviceSnapshot(
  appVersion: '1.2.0',
  build: '42',
  platform: 'android',
  osVersion: 'Android 14',
  locale: 'en-AE',
  theme: 'light',
  route: '/home',
);

class _Fake implements BugReportTransport {
  _Fake(this.method, {this.ok = true});
  @override
  final DeliveryMethod method;
  @override
  bool get available => true;
  final bool ok;
  final sent = <BugReport>[];
  @override
  Future<SendOutcome> send(BugReport r) async {
    sent.add(r);
    return ok ? SendOutcome.ok(method) : SendOutcome.failed(method, 'x');
  }
}

Future<void> _pump(
  WidgetTester tester, {
  ui.Image? shot,
  BugReportTransport? issue,
  required _Fake local,
  void Function(DeliveryMethod)? onSent,
}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: PulseTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => BugReportSheet(
                  screenshot: shot,
                  device: _device,
                  logLines: const ['10:00:00 route  /home', '10:00:01 event first_capture'],
                  local: local,
                  issue: issue,
                  onSent: onSent,
                  now: () => DateTime.utc(2026, 5, 1),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<ui.Image> _image(WidgetTester tester) async => (await tester.runAsync(() => createTestImage(width: 390, height: 844)))!;

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
}

Future<void> _openAnnotate(WidgetTester tester) async {
  await _scrollTo(tester, find.byKey(const Key('bug-annotate')));
  await tester.tap(find.byKey(const Key('bug-annotate')));
  await tester.pumpAndSettle();
}

Future<void> _drag(WidgetTester tester, Offset from, Offset to) async {
  final g = await tester.startGesture(from);
  await g.moveBy(Offset((to.dx - from.dx) / 2, (to.dy - from.dy) / 2));
  await g.moveTo(to);
  await g.up();
  await tester.pump();
}

void main() {
  testWidgets('shows chips, note, switches and the attachment preview', (tester) async {
    final shot = await _image(tester);
    await _pump(tester, shot: shot, local: _Fake(DeliveryMethod.local));
    for (final k in ['bug', 'confusing', 'idea']) {
      expect(find.byKey(Key('bug-category-$k')), findsOneWidget);
    }
    expect(find.byKey(const Key('bug-note')), findsOneWidget);
    expect(find.byKey(const Key('bug-include-screenshot')), findsOneWidget);
    expect(find.byKey(const Key('bug-mask-all')), findsOneWidget);
    await _scrollTo(tester, find.byKey(const Key('bug-preview')));
    expect(find.textContaining('Pulse 1.2.0 (42), android Android 14'), findsOneWidget);
    expect(find.textContaining('Screen /home, en-AE, light theme'), findsOneWidget);
    expect(find.text('Screenshot'), findsOneWidget);
    expect(find.textContaining('Activity log, 2 lines'), findsOneWidget);
    expect(find.byKey(const Key('bug-log-view')), findsNothing);
    await tester.tap(find.byKey(const Key('bug-toggle-log')));
    await tester.pump();
    expect(find.byKey(const Key('bug-log-view')), findsOneWidget);
    expect(find.textContaining('first_capture'), findsWidgets);
  });

  testWidgets('switches update the preview', (tester) async {
    final shot = await _image(tester);
    await _pump(tester, shot: shot, local: _Fake(DeliveryMethod.local));
    await tester.ensureVisible(find.byKey(const Key('bug-mask-all')));
    await tester.tap(find.byKey(const Key('bug-mask-all')));
    await tester.pump();
    await _scrollTo(tester, find.byKey(const Key('bug-preview')));
    expect(find.text('Screenshot, all text masked'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('bug-include-screenshot')));
    await tester.tap(find.byKey(const Key('bug-include-screenshot')));
    await tester.pump();
    await _scrollTo(tester, find.byKey(const Key('bug-preview')));
    expect(find.text('Screenshot left out'), findsOneWidget);
    expect(find.byKey(const Key('bug-annotate')), findsNothing);
  });

  testWidgets('annotate: pen and blur marks, undo and clear', (tester) async {
    final shot = await _image(tester);
    await _pump(tester, shot: shot, local: _Fake(DeliveryMethod.local));
    await _openAnnotate(tester);
    final canvas = tester.getRect(find.byKey(const Key('bug-canvas')));
    final undo = find.byKey(const Key('bug-undo'));
    expect(tester.widget<TextButton>(undo).onPressed, isNull, reason: 'nothing to undo yet');

    await _drag(tester, canvas.topLeft + const Offset(20, 40), canvas.topLeft + const Offset(80, 120));
    expect(tester.widget<TextButton>(undo).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('bug-tool-blur')));
    await tester.pump();
    await _drag(tester, canvas.topLeft + const Offset(10, 150), canvas.topLeft + const Offset(100, 200));

    await tester.tap(find.byKey(const Key('bug-color-1')));
    await tester.pump();
    await _drag(tester, canvas.topLeft + const Offset(30, 250), canvas.topLeft + const Offset(120, 260));

    await tester.tap(find.byKey(const Key('bug-annotate-done')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('bug-preview')));
    expect(find.text('Screenshot, 3 marks'), findsOneWidget);

    await _openAnnotate(tester);
    await tester.tap(find.byKey(const Key('bug-undo')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('bug-annotate-done')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('bug-preview')));
    expect(find.text('Screenshot, 2 marks'), findsOneWidget);

    await _openAnnotate(tester);
    await tester.tap(find.byKey(const Key('bug-clear')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('bug-annotate-done')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('bug-preview')));
    expect(find.text('Screenshot'), findsOneWidget);
  });

  testWidgets('without a service URL the sheet offers the share sheet and sends once', (tester) async {
    final local = _Fake(DeliveryMethod.local);
    DeliveryMethod? sent;
    await _pump(tester, local: local, onSent: (m) => sent = m);
    expect(find.byKey(const Key('bug-send')), findsNothing);
    await tester.tap(find.byKey(const Key('bug-category-idea')));
    await tester.enterText(find.byKey(const Key('bug-note')), 'Add dark charts');
    await tester.pump();
    await _scrollTo(tester, find.byKey(const Key('bug-share')));
    await tester.tap(find.byKey(const Key('bug-share')));
    await tester.pumpAndSettle();
    expect(sent, DeliveryMethod.local);
    expect(local.sent.single.category, BugCategory.idea);
    expect(local.sent.single.note, 'Add dark charts');
    expect(local.sent.single.screenshotPng, isNull);
    expect(find.byKey(const Key('bug-note')), findsNothing, reason: 'sheet closed');
  });

  testWidgets('a failing issue endpoint falls back to the share sheet', (tester) async {
    final issue = _Fake(DeliveryMethod.issue, ok: false);
    final local = _Fake(DeliveryMethod.local);
    DeliveryMethod? sent;
    await _pump(tester, local: local, issue: issue, onSent: (m) => sent = m);
    await _scrollTo(tester, find.byKey(const Key('bug-send')));
    await tester.tap(find.byKey(const Key('bug-send')));
    await tester.pumpAndSettle();
    expect(issue.sent.length, 1);
    expect(local.sent.length, 1);
    expect(sent, DeliveryMethod.local);
  });

  testWidgets('the screenshot is exported with the marks when included', (tester) async {
    final shot = await _image(tester);
    final local = _Fake(DeliveryMethod.local);
    await _pump(tester, shot: shot, local: local);
    await _scrollTo(tester, find.byKey(const Key('bug-share')));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('bug-share')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    final png = local.sent.single.screenshotPng;
    expect(png, isNotNull);
    expect(png!.sublist(1, 4), [80, 78, 71], reason: 'PNG header');
  });

  test('controller: marks, undo, clear, tiny gestures are ignored', () {
    final c = AnnotationController();
    c.begin(const Offset(0.1, 0.1));
    c.end();
    expect(c.hasMarks, isFalse, reason: 'a tap is not a stroke');
    c.begin(const Offset(0.1, 0.1));
    c.extend(const Offset(2, -1));
    c.end();
    expect((c.marks.single as PenMark).points.last, const Offset(1, 0), reason: 'clamped');
    c.setTool(AnnotateTool.blur);
    c.begin(const Offset(0.2, 0.2));
    c.extend(const Offset(0.5, 0.4));
    c.end();
    expect(c.blurCount, 1);
    c.undo();
    expect(c.marks.length, 1);
    c.clear();
    expect(c.hasMarks, isFalse);
    c.undo();
  });
}
