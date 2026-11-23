import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/card_util.dart';
import 'package:pulse/data/models.dart';

CreditCard _card(
  String id, {
  double dining = 0,
  RewardCap? cap,
  DateTime? due,
  double minDue = 100,
  double? statementBalance,
}) => CreditCard(
  id: id,
  issuer: id.toUpperCase(),
  name: 'Card',
  last4: '0000',
  network: CardNetwork.visa,
  gradient: const [Color(0xFF000000), Color(0xFF111111)],
  limit: 10000,
  balance: 2500,
  dueDate: due ?? DateTime(2026, 12, 1),
  minDue: minDue,
  rewardsLabel: 'Cashback',
  rewardPoints: 0,
  rewardValueAed: 0,
  categoryRates: {if (dining > 0) SpendCategory.dining: dining},
  statementBalance: statementBalance,
  caps: {SpendCategory.dining: ?cap},
);

void main() {
  test('effective rate falls to base once a cap is reached', () {
    final open = _card('a', dining: 5, cap: const RewardCap(limit: 100));
    final full = _card('a', dining: 5, cap: const RewardCap(limit: 100, used: 100));
    expect(effectiveRate(open, SpendCategory.dining), 5);
    expect(effectiveRate(full, SpendCategory.dining), 0.5);
  });

  test('reward is capped at what is left, then earns base rate', () {
    final c = _card('a', dining: 5, cap: const RewardCap(limit: 100, used: 95));
    // 5 AED of cap left covers 100 AED of spend; the other 100 earns 0.5%.
    expect(rewardFor(c, SpendCategory.dining, 200), closeTo(5.5, 0.001));
  });

  test('ranking and advice use live rates, not headline rates', () {
    final capped = _card(
      'fab',
      dining: 5,
      cap: const RewardCap(limit: 100, used: 100),
    );
    final other = _card('adcb', dining: 3);
    final advice = adviseCard([capped, other], SpendCategory.dining, amount: 100)!;
    expect(advice.best.id, 'adcb');
    expect(advice.rate, 3);
    expect(advice.estimate, closeTo(3, 0.001));
    expect(advice.reason, contains('cap'));
    expect(advice.runnerUp!.id, 'fab');
  });

  test('reward moment nudges to another card when the cap is hit', () {
    final fab = _card('fab', dining: 5, cap: const RewardCap(limit: 100, used: 97));
    final adcb = _card('adcb', dining: 3);
    final m = rewardMoment(
      cards: [fab, adcb],
      card: fab,
      merchant: 'Talabat',
      category: SpendCategory.dining,
      amount: 142,
    );
    expect(m.cap!.reached, isTrue);
    expect(m.nudge, startsWith('Cap reached on this card.'));
    expect(m.nudge, contains('ADCB Card'));
    expect(m.nudge, contains('+3% vs +0.5%'));
  });

  test('no nudge when the card used is still the best', () {
    final fab = _card('fab', dining: 5, cap: const RewardCap(limit: 100));
    final adcb = _card('adcb', dining: 3);
    final m = rewardMoment(
      cards: [fab, adcb],
      card: fab,
      merchant: 'Talabat',
      category: SpendCategory.dining,
      amount: 50,
    );
    expect(m.earned, closeTo(2.5, 0.001));
    expect(m.nudge, isNull);
  });

  test('due info counts days, pays a day early and shows min vs full', () {
    final c = _card(
      'a',
      due: DateTime(2026, 11, 26),
      minDue: 125,
      statementBalance: 2400,
    );
    final d = dueInfo(c, today: DateTime(2026, 11, 23));
    expect(d.daysLeft, 3);
    expect(d.urgent, isTrue);
    expect(d.payBy, DateTime(2026, 11, 25));
    expect(d.minDue, 125);
    expect(d.totalDue, 2400);
    expect(d.nudge, contains('2 days'));
    final late = dueInfo(c, today: DateTime(2026, 11, 28));
    expect(late.overdue, isTrue);
  });
}
