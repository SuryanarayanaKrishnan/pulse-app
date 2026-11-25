import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/widgets/widgets.dart';

import 'extremes_test.dart' show seedExtremes;
import 'harness.dart';

const _screens = [
  '/home',
  '/budget',
  '/cards',
  '/splits',
  '/wealth',
  '/activity',
  '/settings',
  '/categories',
  '/automations',
  '/goals',
  '/recurring',
  '/reports',
  '/review',
  '/cards-ranked',
  '/household',
  '/statements',
];

/// Taps every tappable thing on every screen, one at a time, like a tester
/// mashing the app. Whatever opens (sheet, dialog, screen) is dismissed and the
/// screen is reopened. Any framework error fails the test and names the target.
void main() {
  for (final seeded in [false, true]) {
    testWidgets('tap everything (${seeded ? "busy ledger" : "fresh user"})', (
      tester,
    ) async {
      final app = await launchApp(tester, data: QaData.empty);
      if (seeded) await seedExtremes(app);
      final failures = <String>[];
      var taps = 0;
      for (final route in _screens) {
        await app.go(route);
        app.errors.drain();
        final targets = _tappables(tester);
        final count = targets.length.clamp(0, 14);
        for (var i = 0; i < count; i++) {
          await app.go(route);
          app.errors.drain();
          final list = _tappables(tester);
          if (i >= list.length) break;
          final label = _describe(tester, list[i]);
          // The native file picker has no implementation under flutter test.
          if (label.startsWith('Choose')) continue;
          final pos = tester.getCenter(find.byWidget(list[i]).first);
          if (pos.dy > 2300 || pos.dy < 0 || pos.dx < 0 || pos.dx > 1170)
            continue;
          taps++;
          try {
            final g = await tester.startGesture(
              pos,
              kind: PointerDeviceKind.touch,
            );
            await g.up();
          } on Object catch (e) {
            failures.add('$route tap "$label" threw: $e');
          }
          await app.settle(4);
          tester.takeException();
          for (final e in app.errors.drain()) {
            // Native file picker has no implementation under flutter test.
            if (e.contains('pickFiles')) continue;
            failures.add('$route tap "$label": $e');
          }
          if (app.visibleText.any((t) => t.contains('Something went wrong'))) {
            failures.add('$route tap "$label": error state shown');
          }
        }
      }
      // ignore: avoid_print
      print('QA tapped $taps targets');
      expect(
        failures.toSet().toList(),
        isEmpty,
        reason: failures.toSet().join('\n'),
      );
      await shutDown(tester);
      for (final e in app.errors.drain()) {
        failures.add('on shutdown: $e');
      }
      app.errors.uninstall();
      expect(failures.toSet().toList(), isEmpty, reason: failures.toSet().join('\n'));
    }, timeout: const Timeout(Duration(minutes: 8)));
  }
}

List<Widget> _tappables(WidgetTester tester) => [
  for (final w in tester.widgetList(
    find.byWidgetPredicate(
      (w) =>
          (w is Pressable && w.onTap != null) ||
          (w is InkWell && w.onTap != null) ||
          w is IconButton ||
          w is TextButton ||
          w is FilledButton ||
          w is ElevatedButton,
    ),
  ))
    w,
];

String _describe(WidgetTester tester, Widget w) {
  final texts = find.descendant(
    of: find.byWidget(w),
    matching: find.byType(Text),
  );
  final t = [for (final x in tester.widgetList<Text>(texts)) x.data]
      .whereType<String>()
      .take(2)
      .join(' / ');
  return t.isEmpty ? w.runtimeType.toString() : t;
}
