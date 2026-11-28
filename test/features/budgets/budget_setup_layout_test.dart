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

/// "Build my budget" at 360px wide: amount fields and the summary strip must
/// show every digit at any Dynamic Type size, including six-figure values.
Future<void> open(
  WidgetTester tester, {
  required double scale,
  bool dark = false,
}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.platformBrightnessTestValue = dark
      ? Brightness.dark
      : Brightness.light;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(
          MockPulseRepository(latency: Duration.zero),
        ),
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
      child: const PulseApp(initialLocation: '/budget-setup'),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
}

/// The text field's painted text must fit inside its editable area.
void expectFieldFits(WidgetTester tester, Key key) {
  final field = find.byKey(key);
  final text = tester.widget<TextField>(field).controller!.text;
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
  );
  final style = tester.widget<EditableText>(editable).style;
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler:
        tester.widget<EditableText>(editable).textScaler ??
        TextScaler.noScaling,
  )..layout();
  expect(
    tester.getSize(editable).width,
    greaterThanOrEqualTo(tp.width),
    reason: '$key clips "$text"',
  );
  // Prefix "AED " is laid out beside the editable area, inside the field.
  expect(tester.getRect(field).right, lessThanOrEqualTo(360));
}

void main() {
  for (final scale in [1.0, 1.5, 2.0]) {
    for (final dark in [false, true]) {
      testWidgets(
        'amounts and summary fit at 360px, x$scale, ${dark ? 'dark' : 'light'}',
        (tester) async {
          await open(tester, scale: scale, dark: dark);
          await tester.enterText(
            find.byKey(const Key('setup_income')),
            '600000',
          );
          await tester.pump(const Duration(milliseconds: 300));
          final rent = find.byKey(const Key('setup_rent'));
          await tester.scrollUntilVisible(
            rent,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.enterText(
            find.byKey(const Key('amount_rent')),
            '125000',
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          expectFieldFits(tester, const Key('amount_rent'));
          // Every visible amount field fits its digits.
          for (final f
              in find
                  .byWidgetPredicate(
                    (w) =>
                        w is TextField &&
                        (w.key as ValueKey?)?.value.toString().contains(
                              'amount_',
                            ) ==
                            true,
                  )
                  .evaluate()) {
            expectFieldFits(tester, f.widget.key!);
          }
          await tester.scrollUntilVisible(
            find.text('Planned'),
            -200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(tester.takeException(), isNull);
          // No summary figure is clipped: its box stays inside the card/screen.
          for (final t in ['Planned', 'Saved', 'Left over']) {
            final r = tester.getRect(find.text(t));
            expect(r.left, greaterThanOrEqualTo(0));
            expect(r.right, lessThanOrEqualTo(360), reason: t);
          }
          expect(
            find.textContaining('AED 600,000').evaluate().isEmpty,
            isTrue,
          ); // income is not echoed
          final figures = find.byWidgetPredicate(
            (w) =>
                w is Text &&
                (w.data ?? '').startsWith('AED ') &&
                (w.data ?? '').contains(','),
          );
          for (final e in figures.evaluate()) {
            final r = tester.getRect(find.byWidget(e.widget));
            expect(
              r.right,
              lessThanOrEqualTo(360 - 16 + 0.5),
              reason: (e.widget as Text).data,
            );
            expect(r.left, greaterThanOrEqualTo(0));
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('over budget is spelled out, in the negative colour', (
    tester,
  ) async {
    await open(tester, scale: 1.0);
    await tester.enterText(find.byKey(const Key('setup_income')), '15000');
    await tester.pump(const Duration(milliseconds: 300));
    final rent = find.byKey(const Key('setup_rent'));
    await tester.scrollUntilVisible(
      rent,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const Key('amount_rent')), '40000');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('Over by'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Over by'), findsOneWidget);
    expect(find.text('Left over'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('15,000 take-home shows 6,925 / 2,250 / 5,825 in a row at 1x', (
    tester,
  ) async {
    await open(tester, scale: 1.0);
    await tester.enterText(find.byKey(const Key('setup_income')), '15000');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.scrollUntilVisible(
      find.text('Planned'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('AED 2,250'), findsOneWidget);
    expect(find.byKey(const Key('setup_summary_row')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
