import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

/// Golden screenshots of the five tabs, light and dark, on a phone-sized
/// screen with the demo ledger. Catches layout regressions (a screen going
/// blank, a header losing its colour, overflow stripes) at a glance.
///
/// Dates in the demo data move with the calendar and the test font is a
/// block face, so a small difference is tolerated; a real change is not.
/// Refresh with: flutter test test/qa/golden_smoke_test.dart --update-goldens
class _Tolerant extends LocalFileComparator {
  _Tolerant(super.testFile, this.tolerance);
  final double tolerance;
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final r = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (!r.passed && r.diffPercent <= tolerance) return true;
    if (!r.passed) {
      final err = await generateFailureOutput(r, golden, basedir);
      throw FlutterError(err);
    }
    return true;
  }
}

void main() {
  final base = goldenFileComparator as LocalFileComparator;
  setUpAll(
    () => goldenFileComparator = _Tolerant(
      base.basedir.resolve('golden_smoke_test.dart'),
      0.03,
    ),
  );
  tearDownAll(() => goldenFileComparator = base);

  const tabs = ['home', 'budget', 'cards', 'splits', 'wealth'];
  for (final dark in [false, true]) {
    for (final tab in tabs) {
      testWidgets('$tab ${dark ? "dark" : "light"}', (tester) async {
        final app = await launchApp(
          tester,
          data: QaData.demo,
          location: '/$tab',
          dark: dark,
          size: const Size(390, 844),
          dpr: 1,
        );
        await app.settle(10);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/${tab}_${dark ? "dark" : "light"}.png'),
        );
        expect(tester.takeException(), isNull);
        await shutDown(tester);
      });
    }
  }
}
