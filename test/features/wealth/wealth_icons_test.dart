import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/icons/category_tint.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/widgets/category_icon.dart';
import 'package:pulse/core/engine/goals.dart' show GoalKind;
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/coach/coach_progress.dart';
import 'package:pulse/features/goals/goal_widgets.dart';
import 'package:pulse/features/tour/tour_progress.dart';
import 'package:pulse/features/wealth/wealth_icons.dart';

void main() {
  group('WealthKind', () {
    test('every kind has its own glyph, not the fallback', () {
      for (final k in WealthKind.values) {
        final cat = SpendCategory.custom(
          'w_${k.name}',
          k.label,
          iconKey: k.glyphKey,
        );
        expect(hasOwnGlyph(cat), isTrue, reason: k.name);
      }
    });

    test(
      'goals, gold, jewellery, funds, stocks and property never share a glyph',
      () {
        const distinct = [
          WealthKind.goal,
          WealthKind.gold,
          WealthKind.jewellery,
          WealthKind.fund,
          WealthKind.stock,
          WealthKind.property,
        ];
        expect({
          for (final k in distinct) k.glyphKey,
        }, hasLength(distinct.length));
        // And the tints differ between the families that sit side by side.
        expect(WealthKind.gold.token, isNot(WealthKind.jewellery.token));
        expect(WealthKind.goal.token, isNot(WealthKind.stock.token));
      },
    );

    test('tints stay in the gold and violet family', () {
      const gold = {'yellow', 'amber', 'stone'};
      const violet = {'violet', 'indigo', 'fuchsia'};
      for (final k in WealthKind.values.where((k) => k != WealthKind.loan)) {
        expect(gold.union(violet), contains(k.token), reason: k.name);
        // The token is a real hue.
        expect(
          categoryTint(k.token, dark: false),
          isNot(categoryTint('gray', dark: false)),
        );
      }
    });

    test('every asset kind maps to a wealth kind', () {
      expect(WealthKind.forAsset(AssetKind.gold), WealthKind.gold);
      expect(WealthKind.forAsset(AssetKind.funds), WealthKind.fund);
      expect(WealthKind.forAsset(AssetKind.stocks), WealthKind.stock);
      expect(WealthKind.forAsset(AssetKind.realEstate), WealthKind.property);
      for (final k in AssetKind.values) {
        expect(WealthKind.forAsset(k), isA<WealthKind>());
      }
    });
  });

  group('icon chips', () {
    Future<void> pumpChips(
      WidgetTester tester, {
      required bool dark,
      double scale = 1,
    }) async {
      PulseTheme.useGoogleFonts = false;
      tester.view.physicalSize = const Size(360, 640) * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: PulseTheme.light,
          darkTheme: PulseTheme.dark,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: ListView(
              scrollCacheExtent: const ScrollCacheExtent.pixels(5000),
              children: [
                for (final k in WealthKind.values)
                  ListTile(leading: WealthIcon(k), title: Text(k.label)),
                const GoalIcon('car'),
                const GoalIcon(null, kind: GoalKind.paydown),
              ],
            ),
          ),
        ),
      );
    }

    for (final dark in [false, true]) {
      testWidgets('render at 360px, text 1.5 (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        await pumpChips(tester, dark: dark, scale: 1.5);
        expect(find.byType(WealthIcon), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a goal wears violet, paying a card down wears indigo', (
      tester,
    ) async {
      await pumpChips(tester, dark: false);
      final w = tester
          .widgetList<WealthIcon>(find.byType(WealthIcon, skipOffstage: false))
          .toList();
      expect(
        w.where((i) => i.kind == WealthKind.goal && i.glyphKey == 'car'),
        hasLength(1),
      );
      expect(
        w.where((i) => i.kind == WealthKind.payDown && i.glyphKey == 'fees'),
        hasLength(1),
      );
    });
  });

  group('on the Wealth tab', () {
    MemoryKvStore kv() {
      final k = MemoryKvStore()..data['tour.seen'] = '1';
      for (final t in ['home', 'budget', 'cards', 'splits', 'wealth']) {
        k.data['tips.seen.$t'] = '1';
      }
      for (final s in CoachScreen.values) {
        k.data['coach.seen.${s.key}'] = '1';
      }
      return k;
    }

    for (final dark in [false, true]) {
      testWidgets(
        'lists carry distinct icons at 360px, text 1.5 (${dark ? 'dark' : 'light'})',
        (tester) async {
          PulseTheme.useGoogleFonts = false;
          tester.view.physicalSize = const Size(360, 640) * 2;
          tester.view.devicePixelRatio = 2;
          tester.platformDispatcher.textScaleFactorTestValue = 1.5;
          tester.platformDispatcher.platformBrightnessTestValue = dark
              ? Brightness.dark
              : Brightness.light;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                tourKvProvider.overrideWithValue(kv()),
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
              child: const PulseApp(initialLocation: '/wealth'),
            ),
          );
          for (var i = 0; i < 25; i++) {
            await tester.pump(const Duration(milliseconds: 150));
          }
          final seen = <WealthKind>{};
          final list = find.byType(Scrollable).first;
          for (var i = 0; i < 30; i++) {
            seen.addAll(
              tester
                  .widgetList<WealthIcon>(
                    find.byType(WealthIcon, skipOffstage: false),
                  )
                  .map((w) => w.kind),
            );
            await tester.drag(list, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 100));
          }
          // At least gold/jewellery, funds and goals read differently.
          expect(seen.length, greaterThanOrEqualTo(3), reason: '$seen');
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
