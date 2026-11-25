import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// Every plain route in the router. Parameterised routes are in param_routes.
const _routes = [
  '/home',
  '/budget',
  '/cards',
  '/splits',
  '/wealth',
  '/activity',
  '/settings',
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

void main() {
  for (final data in QaData.values) {
    for (final dark in [false, true]) {
      for (final route in _routes) {
        testWidgets('${data.name} ${dark ? "dark" : "light"} $route', (
          tester,
        ) async {
          final app = await launchApp(
            tester,
            data: data,
            location: route,
            dark: dark,
          );
          final err = app.visibleText
              .where((t) => t.contains('Something went wrong'))
              .toList();
          expect(
            err,
            isEmpty,
            reason:
                'error state shown on $route; on screen: ${app.visibleText}',
          );
          expect(tester.takeException(), isNull);
          await shutDown(tester);
        }, timeout: const Timeout(Duration(minutes: 2)));
      }
    }
  }
}
