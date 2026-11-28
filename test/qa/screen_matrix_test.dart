import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'audit.dart';
import 'extremes_test.dart' show seedExtremes;
import 'harness.dart';

/// Every screen, on real (non-demo) data, in light and dark, on the iPhone
/// sizes people actually own, at normal and large text. Fails on any framework
/// error (overflow, build) and on layout problems the audits can see: text on
/// text, text off the edge, cards glued together.
const routes = [
  '/home',
  '/budget',
  '/cards',
  '/splits',
  '/wealth',
  '/activity',
  '/settings',
  '/settings/money',
  '/settings/family',
  '/settings/data',
  '/settings/look',
  '/settings/help',
  '/settings/connections',
  '/apple-pay-setup',
  '/categories',
  '/automations',
  '/statements',
  '/family',
  '/cards-ranked',
  '/legacy',
  '/backup',
  '/backup/setup',
  '/sync',
  '/privacy',
  '/privacy/learning',
  '/review',
  '/goals',
  '/recurring',
  '/reports',
  '/household',
  '/restore',
  '/tour',
  '/apple-ingest',
];

const devices = <String, Size>{
  'se': Size(375, 667),
  'iphone15': Size(393, 852),
  'promax': Size(430, 932),
};

void main() {
  for (final entry in devices.entries) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 1.6]) {
        for (final seeded in [false, true]) {
          final name =
              '${entry.key} ${dark ? "dark" : "light"} x$scale ${seeded ? "busy" : "fresh"}';
          testWidgets('matrix: $name', (tester) async {
            final app = await launchApp(
              tester,
              data: QaData.empty,
              dark: dark,
              size: entry.value * 3,
              dpr: 3,
              textScale: scale,
            );
            if (seeded) await seedExtremes(app);
            final failures = <String>[];
            for (final route in routes) {
              await app.go(route);
              tester.takeException();
              for (final e in app.errors.drain()) {
                if (e.contains('No implementation found for method cancel'))
                  continue;
                failures.add('$route: $e');
              }
              if (app.visibleText.any(
                (t) => t.contains('Something went wrong'),
              )) {
                failures.add('$route: error state shown');
              }
              // The tour is an overlay drawn over the app on purpose.
              if (route == '/tour') continue;
              for (final p in auditScreen(tester)) {
                failures.add('$route: $p');
              }
            }
            app.errors.uninstall();
            expect(failures, isEmpty, reason: failures.join('\n'));
            await shutDown(tester);
          }, timeout: const Timeout(Duration(minutes: 4)));
        }
      }
    }
  }
}
