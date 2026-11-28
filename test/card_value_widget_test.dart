import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/engine/card_value.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/local/card_value_report.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/cards/card_check_nudge.dart';
import 'package:pulse/features/cards/card_value_widgets.dart';

class _Rec extends NoopAnalytics {
  final events = <AnalyticsEvent>[];
  @override
  void track(AnalyticsEvent e) => events.add(e);
}

CardCheck _check({
  required int earned,
  required int best,
  bool estimated = true,
}) => CardCheck(
  paidCardId: 'a',
  paidTitle: 'Card A',
  earnedMinor: earned,
  bestCardId: 'b',
  bestTitle: 'Card B',
  bestMinor: best,
  estimated: estimated,
);

Widget _app(Widget home, {List<Override> overrides = const []}) {
  PulseTheme.useGoogleFonts = false;
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: PulseTheme.light,
      home: Scaffold(body: SingleChildScrollView(child: home)),
    ),
  );
}

void main() {
  group('card check nudge', () {
    late List<String> haptics;
    setUp(() {
      haptics = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (c) async {
            if (c.method == 'HapticFeedback.vibrate')
              haptics.add('${c.arguments}');
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
    });

    Future<_Rec> show(WidgetTester tester, CardCheck check) async {
      final rec = _Rec();
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showCardCheckNudge(ctx, rec, check),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return rec;
    }

    testWidgets(
      'wrong card: names the better card, AED, estimate; light haptic; both events',
      (tester) async {
        final rec = await show(tester, _check(earned: 250, best: 600));
        expect(
          find.textContaining('Card B would have earned about AED 6.00'),
          findsOneWidget,
        );
        expect(find.textContaining('vs AED 2.50 on Card A'), findsOneWidget);
        expect(
          find.textContaining('estimate, unverified terms'),
          findsOneWidget,
        );
        expect(haptics, contains('HapticFeedbackType.lightImpact'));
        expect(rec.events.map((e) => e.name), [
          'card_check_shown',
          'card_check_wrong',
        ]);
        expect(rec.events.first.properties, {
          'result': 'wrong',
          'estimated': true,
        });
        expect(rec.events.last.properties, {'missed_bucket': 'lt_5'});
      },
    );

    testWidgets('right card: calm confirmation, shown event only', (
      tester,
    ) async {
      final rec = await show(
        tester,
        _check(earned: 600, best: 600, estimated: false),
      );
      expect(
        find.textContaining(
          'Right card. Card A earned about AED 6.00 (estimate)',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('unverified'), findsNothing);
      expect(rec.events.map((e) => e.name), ['card_check_shown']);
      expect(rec.events.single.properties['result'], 'right');
    });

    test('miss buckets carry no amounts', () {
      expect(missedBucket(499), 'lt_5');
      expect(missedBucket(500), '5_20');
      expect(missedBucket(2000), '5_20');
      expect(missedBucket(2001), 'gt_20');
    });
  });

  group('card value pages', () {
    final report = CardValueReport(
      ranking: const [
        CardNetValue(
          id: 'a',
          title: 'Bank Alpha',
          windowSpendMinor: 900000,
          windowRewardsMinor: 20000,
          annualRewardsMinor: 81000,
          annualBenefitsMinor: 60000,
          annualFeeMinor: 31500,
          feeWaived: false,
          estimated: true,
        ),
        CardNetValue(
          id: 'b',
          title: 'Bank Beta',
          windowSpendMinor: 100000,
          windowRewardsMinor: 1000,
          annualRewardsMinor: 4000,
          annualBenefitsMinor: 0,
          annualFeeMinor: 31500,
          feeWaived: false,
          estimated: true,
        ),
      ],
      extras: {
        'a': const CardExtras(
          accountId: 'a',
          feeWaiver: MilestoneRing(
            label: 'Fee waiver',
            currentMinor: 500000,
            targetMinor: 2000000,
            state: RingState.active,
            rewardMinor: 31500,
          ),
          welcome: MilestoneRing(
            label: 'Welcome offer',
            currentMinor: 500000,
            targetMinor: 500000,
            state: RingState.complete,
            daysLeft: 30,
            rewardMinor: 40000,
          ),
          benefits: [Benefit('Airport lounge', 60000)],
          hints: [
            CardHint(
              kind: 'cap',
              cardId: 'a',
              message: 'Use Bank Beta for dining until 2026-11-30.',
            ),
          ],
        ),
        'b': const CardExtras(accountId: 'b'),
      },
    );
    final overrides = [cardValueProvider.overrideWith((ref) async => report)];

    testWidgets('detail: rings, benefits, hint and the estimate label', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const CardValueSection('a'), overrides: overrides),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fee waiver'), findsOneWidget);
      expect(find.textContaining('AED 15,000 to go'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
      expect(find.textContaining('Done'), findsOneWidget);
      expect(find.text('Airport lounge'), findsOneWidget);
      expect(
        find.textContaining('Use Bank Beta for dining until'),
        findsOneWidget,
      );
      expect(find.textContaining('not yet verified'), findsOneWidget);
    });

    testWidgets('detail: a card with no data adds nothing', (tester) async {
      await tester.pumpWidget(
        _app(const CardValueSection('b'), overrides: overrides),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('ranked: ordered by net value with the breakdown', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const NetValueRanking(), overrides: overrides),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('(estimate)'), findsOneWidget);
      final a = tester.getTopLeft(find.text('Bank Alpha')).dy;
      final b = tester.getTopLeft(find.text('Bank Beta')).dy;
      expect(a, lessThan(b));
      expect(
        find.textContaining('AED 810 rewards · AED 600 benefits · AED 315 fee'),
        findsOneWidget,
      );
      expect(find.text('AED 1,095'), findsOneWidget);
      expect(find.text('−AED 275'), findsOneWidget);
    });
  });
}
