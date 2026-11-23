import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/card_ranking.dart';
import 'package:pulse/data/models.dart';

CreditCard _card(
  String id, {
  Map<SpendCategory, double> rates = const {},
  Map<SpendCategory, RewardCap> caps = const {},
  double fee = 0,
  double base = 0.5,
}) => CreditCard(
  id: id,
  issuer: id,
  name: 'Card',
  last4: '0000',
  network: CardNetwork.visa,
  gradient: const [Color(0xFF000000), Color(0xFF111111)],
  limit: 10000,
  balance: 0,
  dueDate: DateTime(2026, 12, 1),
  minDue: 0,
  rewardsLabel: 'Cashback',
  rewardPoints: 0,
  rewardValueAed: 0,
  categoryRates: rates,
  caps: caps,
  annualFee: fee,
  baseRate: base,
);

Transaction _tx(String card, double amount, SpendCategory cat, int day) =>
    Transaction(
      id: '$card$amount$day',
      merchant: 'm',
      amount: amount,
      category: cat,
      date: DateTime(2026, 11, day),
      source: TxSource.sms,
      cardId: card,
      accountLabel: 'x',
    );

void main() {
  final now = DateTime(2026, 11, 23);
  final cash = _card('cash', rates: {SpendCategory.groceries: 5});
  final miles = _card('miles', rates: {SpendCategory.travel: 3}, fee: 1200);
  final txs = [
    _tx('cash', 800, SpendCategory.groceries, 3),
    _tx('cash', 200, SpendCategory.dining, 5),
    _tx('miles', 100, SpendCategory.travel, 6),
    _tx('miles', 50, SpendCategory.travel, 1),
    _tx('cash', 999, SpendCategory.groceries, 1).copyWith(excluded: true),
  ];

  test('use ranks by spend share and ignores excluded spend', () {
    final r = cardStandings([miles, cash], txs, now: now);
    expect(r.first.card.id, 'cash');
    expect(r.first.spend, 1000);
    expect(r.first.share, closeTo(1000 / 1150, 1e-9));
    expect(r.last.underused, isFalse);
  });

  test('rewards apply rates, base rate and caps in date order', () {
    final capped = _card(
      'c',
      rates: {SpendCategory.groceries: 5},
      caps: {SpendCategory.groceries: const RewardCap(limit: 25)},
    );
    // 400 at 5% = 20; then 200 at 5% would be 10 but only 5 is left:
    // 100 of spend at 5% + 100 at the 0.5% base rate.
    final earned = earnedOn(capped, [
      _tx('c', 400, SpendCategory.groceries, 1),
      _tx('c', 200, SpendCategory.groceries, 2),
    ]);
    expect(earned, closeTo(25.5, 1e-9));
    final r = cardStandings([cash], txs, now: now, sort: CardSort.rewards);
    expect(r.single.rewards, closeTo(800 * 0.05 + 200 * 0.005, 1e-9));
  });

  test('return is net of a month of the annual fee', () {
    final r = cardStandings(
      [miles, cash],
      txs,
      now: now,
      sort: CardSort.returns,
    );
    expect(r.first.card.id, 'cash');
    final m = r.last;
    expect(m.netReturnPct, closeTo((4.5 - 100) / 150 * 100, 1e-9));
    expect(m.feeNotCovered, isTrue);
    expect(m.warning, contains('1200 fee'));
  });

  test('a card with no spend this month is flagged as underused', () {
    final idle = _card('idle');
    final r = cardStandings([cash, idle], txs, now: now);
    final s = r.firstWhere((x) => x.card.id == 'idle');
    expect(s.share, 0);
    expect(s.underused, isTrue);
    expect(s.warning, 'Rarely used');
  });

  test('best-card categories cover the everyday set', () {
    expect(bestCardCategories.map((e) => e.$2), [
      'Groceries',
      'Dining',
      'Fuel',
      'Travel',
      'Online',
      'Bills',
    ]);
  });
}
