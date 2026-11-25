import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/card_value.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/rewards.dart';

// Synthetic fixtures only.
CardSpec _spec(Map<String, Object?> over) => parseStructure({
  'unit': 'cashback',
  'point_value_aed': 1,
  'base_rate': 0.01,
  ...over,
});

RankableCard _card(String id, CardSpec spec, {List<Spend> spends = const [], int order = 0}) =>
    RankableCard(id: id, title: 'Card $id', spec: spec, state: computeCycle(spec, spends), createdOrder: order);

final _dining = _spec({
  'rules': [
    {'name': 'Dining', 'categories': ['dining'], 'rate': 0.05, 'monthly_cap_units': 100},
  ],
});
final _flat = _spec({'base_rate': 0.02});

void main() {
  group('checkCard', () {
    final cards = [_card('a', _dining), _card('b', _flat, order: 1)];
    const dinner = Spend(20000, 'dining', 'cafe');

    test('right card: no miss', () {
      final c = checkCard(paidCardId: 'a', before: cards, spend: dinner)!;
      expect(c.right, isTrue);
      expect(c.earnedMinor, 1000);
      expect(c.missedMinor, 0);
    });

    test('wrong card: reports AED earned vs best', () {
      final c = checkCard(paidCardId: 'b', before: cards, spend: dinner)!;
      expect(c.right, isFalse);
      expect(c.earnedMinor, 400);
      expect(c.bestCardId, 'a');
      expect(c.bestMinor, 1000);
      expect(c.missedMinor, 600);
    });

    test('a tie is never wrong, and tiny misses count as right', () {
      final tie = [_card('a', _flat), _card('b', _flat, order: 1)];
      expect(checkCard(paidCardId: 'b', before: tie, spend: dinner)!.right, isTrue);
      // AED 50 at 5% vs 2%: AED 1.50 missed? 2.50-1.00 = 1.50 -> wrong; AED 10: 0.50-0.20 -> noise.
      expect(checkCard(paidCardId: 'b', before: cards, spend: const Spend(1000, 'dining'))!.right, isTrue);
    });

    test('caps bind: a capped card is not the best', () {
      final capped = [
        _card('a', _dining, spends: const [Spend(200000, 'dining')]),
        _card('b', _flat, order: 1),
      ];
      final c = checkCard(paidCardId: 'b', before: capped, spend: dinner)!;
      expect(c.right, isTrue);
    });

    test('nothing to compare returns null', () {
      expect(checkCard(paidCardId: 'a', before: [cards.first], spend: dinner), isNull);
      expect(checkCard(paidCardId: 'zzz', before: cards, spend: dinner), isNull);
      expect(checkCard(paidCardId: 'a', before: cards, spend: const Spend(0, 'dining')), isNull);
      final none = [_card('a', _spec({'base_rate': 0})), _card('b', _spec({'base_rate': 0}))];
      expect(checkCard(paidCardId: 'a', before: none, spend: dinner), isNull);
    });

    test('flags estimates when terms are unverified', () {
      final c = checkCard(paidCardId: 'b', before: cards, spend: dinner, unverifiedCardIds: {'a'})!;
      expect(c.estimated, isTrue);
      expect(checkCard(paidCardId: 'b', before: cards, spend: dinner)!.estimated, isFalse);
    });
  });

  group('benefits', () {
    test('values flat and per-use perks, skips junk', () {
      final b = parseBenefits({
        'benefits': [
          {'name': 'Lounge', 'value_aed_year': 600},
          {'name': 'Cinema', 'unit_value_aed': 35, 'uses_per_year': 12, 'expected_use_pct': 0.5},
          {'name': 'No value'},
          {'value_aed_year': 5},
          'junk',
          {'name': 'Zero', 'value_aed_year': 0},
        ],
      });
      expect(b.map((x) => x.name), ['Lounge', 'Cinema']);
      expect(b[0].annualValueMinor, 60000);
      expect(b[1].annualValueMinor, 21000);
      expect(totalBenefitsMinor(b), 81000);
    });
    test('empty perks', () {
      expect(parseBenefits({}), isEmpty);
      expect(parseBenefits({'benefits': 'x'}), isEmpty);
    });
  });

  group('rings', () {
    test('fee waiver progress', () {
      final s = _spec({'fee_waiver_spend_minor': 2000000});
      final r = feeWaiverRing(s, 31500, 500000)!;
      expect(r.fraction, 0.25);
      expect(r.remainingMinor, 1500000);
      expect(r.state, RingState.active);
      expect(r.rewardMinor, 31500);
      expect(feeWaiverRing(s, 31500, 2500000)!.state, RingState.complete);
      expect(feeWaiverRing(s, 31500, 2500000)!.fraction, 1);
    });
    test('no ring without a fee or threshold', () {
      expect(feeWaiverRing(_spec({'fee_waiver_spend_minor': 100}), 0, 0), isNull);
      expect(feeWaiverRing(_spec({}), 5000, 0), isNull);
    });
    test('welcome bonus: active, complete, expired', () {
      final w = parseWelcomeBonus({
        'welcome_bonus': {'spend_minor': 500000, 'within_days': 90, 'bonus_value_aed': 400},
      })!;
      const opened = CalDate(2026, 10, 1);
      final a = welcomeBonusRing(w, opened, const CalDate(2026, 11, 1), 100000);
      expect(a.state, RingState.active);
      expect(a.daysLeft, 59);
      expect(a.rewardMinor, 40000);
      expect(welcomeBonusRing(w, opened, const CalDate(2026, 11, 1), 500000).state, RingState.complete);
      final e = welcomeBonusRing(w, opened, const CalDate(2027, 1, 15), 100000);
      expect(e.state, RingState.expired);
      expect(e.daysLeft, 0);
    });
    test('welcome bonus parse rejects incomplete data', () {
      expect(parseWelcomeBonus({}), isNull);
      expect(parseWelcomeBonus({'welcome_bonus': {'spend_minor': 1}}), isNull);
    });
  });

  group('hints', () {
    const end = CalDate(2026, 11, 30);
    test('capped card points at the better owned card until cycle end', () {
      final a = _card('a', _dining, spends: const [Spend(220000, 'dining')]);
      final b = _card('b', _flat, order: 1);
      final h = cardHints(card: a, all: [a, b], cycleEnd: end);
      expect(h, hasLength(1));
      expect(h.first.kind, 'cap');
      expect(h.first.suggestedCardId, 'b');
      expect(h.first.message, contains('Use Card b'));
      expect(h.first.message, contains('2026-11-30'));
    });
    test('no hint below 80% of the cap', () {
      final a = _card('a', _dining, spends: const [Spend(100000, 'dining')]);
      expect(cardHints(card: a, all: [a], cycleEnd: end), isEmpty);
    });
    test('near a monthly minimum: keep using the card', () {
      final s = _spec({'min_monthly_spend_minor': 200000});
      final a = _card('a', s, spends: const [Spend(170000)]);
      final h = cardHints(card: a, all: [a], cycleEnd: end);
      expect(h.single.kind, 'threshold');
      expect(h.single.message, contains('AED 300 more'));
      expect(cardHints(card: _card('a', s, spends: const [Spend(50000)]), all: [a], cycleEnd: end), isEmpty);
      expect(cardHints(card: _card('a', s, spends: const [Spend(250000)]), all: [a], cycleEnd: end), isEmpty);
    });
  });

  group('rankByNetValue', () {
    const today = CalDate(2026, 11, 24);
    DatedSpend d(int daysAgo, int minor, [String? cat]) =>
        DatedSpend(today.addDays(-daysAgo), Spend(minor, cat));

    test('rewards + benefits - fee, annualised from 90 days', () {
      final cash = CardValueInput(
        id: 'cash',
        title: 'Cash',
        spec: _flat,
        annualFeeMinor: 0,
        spends: [d(10, 90000), d(40, 90000)], // AED 1,800 -> 36 in window
      );
      final lounge = CardValueInput(
        id: 'lounge',
        title: 'Lounge',
        spec: _spec({'base_rate': 0.01}),
        annualFeeMinor: 50000,
        benefits: const [Benefit('Lounge', 120000)],
        spends: [d(10, 90000)], // 9 AED in window
      );
      final r = rankByNetValue([cash, lounge], today);
      expect(r.first.id, 'lounge');
      expect(r[1].windowRewardsMinor, 3600);
      expect(r[1].annualRewardsMinor, (3600 * 365 / 90).round());
      expect(r.first.netAnnualMinor, (900 * 365 / 90).round() + 120000 - 50000);
    });

    test('spend outside the window earns nothing, but still fills caps', () {
      final c = CardValueInput(
        id: 'a',
        title: 'A',
        spec: _dining,
        annualFeeMinor: 0,
        statementDay: null,
        // Same August cycle: the spend just before the window uses the cap.
        spends: [d(91, 200000, 'dining'), d(88, 100000, 'dining')],
      );
      final r = rankByNetValue([c], today).single;
      expect(r.windowRewardsMinor, 0);
      final old = CardValueInput(
        id: 'a',
        title: 'A',
        spec: _dining,
        annualFeeMinor: 0,
        spends: [d(200, 100000, 'dining')],
      );
      expect(rankByNetValue([old], today).single.windowSpendMinor, 0);
    });

    test('monthly minimum not met zeroes the cycle', () {
      final c = CardValueInput(
        id: 'a',
        title: 'A',
        spec: _spec({'base_rate': 0.02, 'min_monthly_spend_minor': 500000}),
        annualFeeMinor: 0,
        spends: [d(1, 100000)],
      );
      expect(rankByNetValue([c], today).single.windowRewardsMinor, 0);
    });

    test('fee counted unless annualised spend reaches the waiver', () {
      CardValueInput mk(int spend) => CardValueInput(
        id: 'a',
        title: 'A',
        spec: _spec({'base_rate': 0.01, 'fee_waiver_spend_minor': 2000000}),
        annualFeeMinor: 31500,
        spends: [d(5, spend)],
      );
      expect(rankByNetValue([mk(100000)], today).single.feeWaived, isFalse);
      expect(rankByNetValue([mk(100000)], today).single.annualFeeMinor, 31500);
      final big = rankByNetValue([mk(600000)], today).single; // 6,000 x 365/90 > 20,000
      expect(big.feeWaived, isTrue);
      expect(big.annualFeeMinor, 0);
    });

    test('ties keep input order; empty input', () {
      final a = CardValueInput(id: 'a', title: 'A', spec: _flat, annualFeeMinor: 0, spends: const []);
      final b = CardValueInput(id: 'b', title: 'B', spec: _flat, annualFeeMinor: 0, spends: const []);
      expect(rankByNetValue([a, b], today).map((x) => x.id), ['a', 'b']);
      expect(rankByNetValue(const [], today), isEmpty);
    });
  });
}
