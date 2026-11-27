import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/best_moves.dart';
import 'package:pulse/data/card_combos.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/coach/coach_progress.dart';
import 'package:pulse/features/tour/tour_progress.dart';

CardCombo _c(String id, {num? saving, bool warn = false, bool plus = false}) =>
    parseCombos(
      jsonEncode({
        'items': [
          {
            'id': id,
            'title': id,
            'tier': plus ? 'plus' : 'free',
            'severity': warn ? 'warn' : 'info',
            'annual_saving_aed': ?saving,
          },
        ],
      }),
    ).single;

void main() {
  group('picking the best moves', () {
    test(
      'savings first, warnings out, fills with free tips, at most three',
      () {
        final all = [
          _c('warn-saving', saving: 900, warn: true),
          _c('big', saving: 1200),
          _c('small', saving: 100),
          _c('plus-tip', plus: true),
          _c('free-tip-a'),
          _c('free-tip-b'),
        ];
        final out = pickBestMoves(all);
        expect(out.map((c) => c.id), ['big', 'small', 'free-tip-a']);
        expect(pickBestMoves(all, max: 2).map((c) => c.id), ['big', 'small']);
      },
    );

    test(
      'high value needs a real figure of at least AED 500 and no warning',
      () {
        expect(isHighValue(_c('a', saving: 500)), isTrue);
        expect(isHighValue(_c('a', saving: 499)), isFalse);
        expect(isHighValue(_c('a')), isFalse);
        expect(isHighValue(_c('a', saving: 900, warn: true)), isFalse);
      },
    );

    test('the shipped bundle leads with the Reddit stack, with its figure', () {
      final combos = parseCombos(
        File('assets/catalog/combos.json').readAsStringSync(),
      );
      final moves = pickBestMoves(combos);
      expect(moves, hasLength(3));
      expect(moves.first.id, 'reddit-liv-df-sib-tabby-stack');
      expect(moves.first.annualSavingAed, 3041);
      expect(moves.skip(1).every((c) => !c.isPlus && !c.isWarning), isTrue);
    });
  });

  group('on screen', () {
    MemoryKvStore tourKv() {
      final k = MemoryKvStore()..data['tour.seen'] = '1';
      for (final t in ['home', 'budget', 'cards', 'splits', 'wealth']) {
        k.data['tips.seen.$t'] = '1';
      }
      for (final s in CoachScreen.values) {
        k.data['coach.seen.${s.key}'] = '1';
      }
      return k;
    }

    Future<void> pump(
      WidgetTester tester,
      String location, {
      MemoryKvStore? kv,
      Size size = const Size(390, 844),
      double dpr = 3,
      double textScale = 1,
      Brightness brightness = Brightness.light,
    }) async {
      PulseTheme.useGoogleFonts = false;
      tester.view.physicalSize = size * dpr;
      tester.view.devicePixelRatio = dpr;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tourKvProvider.overrideWithValue(tourKv()),
            kvStoreProvider.overrideWithValue(kv ?? MemoryKvStore()),
            // The shipped bundle, read straight from disk (no async asset load).
            cardCombosProvider.overrideWith(
              (ref) async => parseCombos(
                File('assets/catalog/combos.json').readAsStringSync(),
              ),
            ),
            repositoryProvider.overrideWithValue(
              MockPulseRepository(latency: Duration.zero),
            ),
            analyticsProvider.overrideWithValue(NoopAnalytics()),
            sessionProvider.overrideWith(
              (ref) => SessionController(
                onboarded: true,
                signedIn: true,
                connected: true,
              ),
            ),
          ],
          child: PulseApp(initialLocation: location),
        ),
      );
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    testWidgets(
      'Home shows Best moves with the Reddit stack, its yearly saving and an estimate label',
      (tester) async {
        await pump(tester, '/home');
        expect(find.byKey(const Key('best_moves')), findsOneWidget);
        expect(find.text('Best moves'), findsOneWidget);
        final card = find.byKey(
          const Key('best_move_reddit-liv-df-sib-tabby-stack'),
        );
        expect(card, findsOneWidget);
        expect(
          find.descendant(
            of: card,
            matching: find.text('Up to AED 3,041 a year'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text('Estimate, not a promise'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('best_move_new')), findsOneWidget);
      },
    );

    testWidgets(
      'opening a move shows what each card is for and how the number was worked out',
      (tester) async {
        final kv = MemoryKvStore();
        await pump(tester, '/home', kv: kv);
        final move = find.byKey(
          const Key('best_move_reddit-liv-df-sib-tabby-stack'),
        );
        await tester.scrollUntilVisible(
          move,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(tester.element(move), alignment: 0.4);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(move);
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.textContaining('A chain of three cards'), findsOneWidget);
        expect(
          find.textContaining(
            'Potential saving: up to AED 3,041 a year (estimate)',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Estimate, not a promise. Worked out on the app',
          ),
          findsOneWidget,
        );
        expect(
          jsonDecode(kv.data[seenCombosKey]!),
          contains('reddit-liv-df-sib-tabby-stack'),
        );
      },
    );

    testWidgets(
      'a new high-value combo badges the Cards tab and its header until it is opened',
      (tester) async {
        final kv = MemoryKvStore();
        await pump(tester, '/cards', kv: kv);
        expect(find.byKey(const Key('nav_badge_cards')), findsOneWidget);
        expect(find.byKey(const Key('round_icon_badge')), findsOneWidget);
        await tester.tap(find.byKey(const Key('cards-combos-button')));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Card combos'), findsWidgets);
        expect(kv.data[seenCombosKey], isNotNull);
        // Close the sheet; the badges are gone and stay gone.
        await tester.tapAt(const Offset(10, 60));
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byKey(const Key('nav_badge_cards')), findsNothing);
        expect(find.byKey(const Key('round_icon_badge')), findsNothing);
      },
    );

    testWidgets('already-seen combos show no badge', (tester) async {
      final kv = MemoryKvStore()
        ..data[seenCombosKey] = jsonEncode(['reddit-liv-df-sib-tabby-stack']);
      await pump(tester, '/cards', kv: kv);
      expect(find.byKey(const Key('nav_badge_cards')), findsNothing);
      expect(find.byKey(const Key('round_icon_badge')), findsNothing);
    });

    for (final dark in [false, true]) {
      testWidgets(
        'Home strip and Cards header fit 360px at text scale 1.5 (${dark ? 'dark' : 'light'})',
        (tester) async {
          await pump(
            tester,
            '/home',
            size: const Size(360, 640),
            dpr: 2,
            textScale: 1.5,
            brightness: dark ? Brightness.dark : Brightness.light,
          );
          final strip = find.byKey(const Key('best_moves'));
          await tester.scrollUntilVisible(
            strip,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          expect(strip, findsOneWidget);
          expect(tester.takeException(), isNull);
          // Swipe the strip: more moves, no overflow.
          await tester.drag(find.byType(ListView).last, const Offset(-250, 0));
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'Cards header at 360px, text 1.5, dark has room for three buttons',
      (tester) async {
        await pump(
          tester,
          '/cards',
          size: const Size(360, 640),
          dpr: 2,
          textScale: 1.5,
          brightness: Brightness.dark,
        );
        expect(find.byKey(const Key('cards-combos-button')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
