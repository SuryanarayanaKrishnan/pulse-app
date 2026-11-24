import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/engine/card_art.dart';
import 'package:pulse/core/engine/catalog.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/theme/tokens.dart';
import 'package:pulse/core/utils/greeting.dart';
import 'package:pulse/core/widgets/card_face.dart';
import 'package:pulse/core/widgets/credit_card_visual.dart';
import 'package:pulse/core/widgets/screen_header.dart';
import 'package:pulse/core/widgets/section_header.dart';
import 'package:pulse/data/mock_repository.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _host(Widget child, {ThemeData? theme, double scale = 1}) => MaterialApp(
  theme: theme ?? PulseTheme.light,
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(body: child),
  ),
);

void main() {
  setUp(() => PulseTheme.useGoogleFonts = false);

  final catalog = CardCatalog.fromJson(
    jsonDecode(File('assets/catalog/cards.json').readAsStringSync())
        as Map<String, Object?>,
  );

  group('card art', () {
    test('every catalog card has art', () {
      expect(catalog.cards, isNotEmpty);
      for (final c in catalog.cards) {
        expect(c.art, isNotNull, reason: c.id);
        expect(c.art!.stops.length, inInclusiveRange(2, 3), reason: c.id);
        expect(c.art!.tier, isNotEmpty, reason: c.id);
        expect(c.art!.bank, isNotEmpty, reason: c.id);
      }
    });

    test('network on the art matches the catalog network', () {
      for (final c in catalog.cards) {
        expect(c.art!.network.name, c.network, reason: c.id);
      }
    });

    test('text stays readable against every gradient stop', () {
      for (final e in CardArts.byCatalogId.entries) {
        for (final s in e.value.stops) {
          expect(
            _contrast(Color(e.value.text), Color(s)),
            greaterThanOrEqualTo(4.5),
            reason: '${e.key} ${s.toRadixString(16)}',
          );
        }
      }
    });

    test('art round-trips through the catalog JSON', () {
      final a = CardArts.byCatalogId['mashreq-solitaire']!;
      final b = CardArtSpec.fromJson(a.toJson());
      expect(b.toJson(), a.toJson());
      expect(b.finish, CardFinish.metal);
    });

    test('mock repository cards resolve to bundled art', () async {
      final cards = await MockPulseRepository(latency: Duration.zero).myCards();
      for (final c in cards) {
        expect(
          CardArts.resolve(id: c.id, issuer: c.issuer, name: c.name),
          isNotNull,
          reason: c.id,
        );
      }
    });
  });

  group('card face', () {
    final art = CardArts.byCatalogId['emirates-nbd-skywards-infinite']!;
    for (final w in [32.0, 56.0, 160.0, 320.0, 358.0]) {
      testWidgets('renders at width $w without overflow', (tester) async {
        await tester.pumpWidget(
          _host(
            Center(
              child: SizedBox(
                width: w,
                child: CardFace(
                  art: art,
                  last4: '4821',
                  name: 'Skywards Infinite',
                  compact: w < 100,
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('every card renders at 2x text scale in dark', (tester) async {
      await tester.pumpWidget(
        _host(
          ListView(
            children: [
              for (final a in CardArts.byCatalogId.values)
                SizedBox(
                  width: 300,
                  child: CardFace(art: a, last4: '0001'),
                ),
            ],
          ),
          theme: PulseTheme.dark,
          scale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('credit card visual falls back for unknown products', (
      tester,
    ) async {
      final cards = await MockPulseRepository(latency: Duration.zero).myCards();
      final odd = cards.first.copyWith();
      await tester.pumpWidget(
        _host(SizedBox(width: 300, child: CreditCardVisual(card: odd))),
      );
      expect(find.text('4821'), findsNothing); // masked groups, last4 only
      expect(tester.takeException(), isNull);
    });
  });

  group('headers', () {
    test('greeting follows the clock', () {
      expect(greetingFor(DateTime(2026, 1, 1, 3)), 'Up late');
      expect(greetingFor(DateTime(2026, 1, 1, 8)), 'Good morning');
      expect(greetingFor(DateTime(2026, 1, 1, 14)), 'Good afternoon');
      expect(greetingFor(DateTime(2026, 1, 1, 19)), 'Good evening');
      expect(greetingFor(DateTime(2026, 1, 1, 23)), 'Good night');
    });

    test('ink is tinted toward the accent but stays high contrast', () {
      for (final c in [PulseColors.light, PulseColors.dark]) {
        expect(c.ink, isNot(c.textPrimary));
        expect(_contrast(c.ink, c.bg), greaterThan(9));
      }
    });

    test('titles use the display face; body text does not', () {
      final t = PulseTheme.light.textTheme;
      expect(t.displayMedium!.fontFamily, PulseTheme.displayFamily);
      expect(t.titleLarge!.fontFamily, PulseTheme.displayFamily);
      expect(t.bodyMedium!.fontFamily, isNot(PulseTheme.displayFamily));
    });

    for (final size in const [Size(360, 640), Size(390, 844)]) {
      for (final scale in [1.0, 1.6]) {
        testWidgets('header fits ${size.width}x${size.height} at x$scale', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            _host(
              ListView(
                children: const [
                  ScreenHeader(
                    'Good afternoon',
                    subtitle: 'Tuesday 24 November',
                    trailing: [
                      SizedBox(width: 44, height: 44),
                      SizedBox(width: 44, height: 44),
                    ],
                  ),
                  SectionHeader(
                    'Spend this month and everything else that matters',
                    action: 'See all',
                  ),
                ],
              ),
              scale: scale,
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.text('TUESDAY 24 NOVEMBER'), findsOneWidget);
        });
      }
    }
  });

  test('display font and licence are bundled', () {
    expect(File('assets/fonts/OFL.txt').existsSync(), isTrue);
    expect(File('assets/fonts/Fraunces_600SemiBold.ttf').existsSync(), isTrue);
    expect(File('pubspec.yaml').readAsStringSync(), contains('PulseDisplay'));
  });
}
