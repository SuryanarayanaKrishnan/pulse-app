import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulse/core/utils/app_clock.dart';
import 'harness.dart';
import 'seed.dart';
import 'screen_matrix_test.dart' show routes;

/// A screenshot of every screen, light and dark, on a fresh install (the data
/// a new tester sees), drawn with real typefaces so a reviewer - or a diff -
/// can actually read it. Plus the five tabs on the smallest iPhone and at
/// large text, where layouts break first.
///
/// A change that moves pixels fails the test; look at test/qa/failures/ and
/// either fix the screen or refresh on purpose:
///   flutter test test/qa/screens_golden_test.dart --update-goldens
///
/// Dates in headers move with the calendar, so a small area of difference is
/// tolerated; a changed layout is not.
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
      throw FlutterError(await generateFailureOutput(r, golden, basedir));
    }
    return true;
  }
}

String _slug(String route) =>
    route == '/' ? 'root' : route.substring(1).replaceAll('/', '_');

void main() {
  final base = goldenFileComparator as LocalFileComparator;
  // Pin the date and time of day so a picture never depends on when it is taken.
  setUp(() => AppClock.source = () => DateTime(2026, 11, 20, 10));
  tearDown(() => AppClock.source = DateTime.now);
  setUpAll(
    () => goldenFileComparator = _Tolerant(
      base.basedir.resolve('screens_golden_test.dart'),
      0.01,
    ),
  );
  tearDownAll(() => goldenFileComparator = base);

  Future<void> shoot(
    WidgetTester tester,
    String route,
    String file, {
    required bool dark,
    required Size size,
    double scale = 1.0,
    bool typical = false,
  }) async {
    final app = await launchApp(
      tester,
      data: QaData.empty,
      location: route,
      dark: dark,
      size: size,
      dpr: 1,
      textScale: scale,
    );
    if (typical) await seedTypical(app);
    await app.settle(10);
    await expectLater(
      find.byType(WidgetsApp),
      matchesGoldenFile('screens/$file.png'),
    );
    await shutDown(tester);
  }

  for (final dark in [false, true]) {
    for (final route in routes) {
      testWidgets('golden ${_slug(route)} ${dark ? "dark" : "light"}', (
        tester,
      ) async {
        await shoot(
          tester,
          route,
          '${_slug(route)}_${dark ? "dark" : "light"}',
          dark: dark,
          size: const Size(393, 852),
        );
      });
    }
  }
  for (final dark in [false, true]) {
    for (final tab in ['home', 'budget', 'cards', 'splits', 'wealth', 'activity']) {
      testWidgets('golden $tab typical ${dark ? "dark" : "light"}', (tester) async {
        await shoot(
          tester,
          '/$tab',
          'typical_${tab}_${dark ? "dark" : "light"}',
          dark: dark,
          size: const Size(393, 852),
          typical: true,
        );
      });
    }
  }
  for (final tab in ['home', 'budget', 'cards', 'splits', 'wealth']) {
    testWidgets('golden $tab small phone', (tester) async {
      await shoot(
        tester,
        '/$tab',
        '${tab}_se',
        dark: false,
        size: const Size(375, 667),
      );
    });
    testWidgets('golden $tab large text', (tester) async {
      await shoot(
        tester,
        '/$tab',
        '${tab}_large_text',
        dark: false,
        size: const Size(393, 852),
        scale: 1.6,
      );
    });
  }
}
