import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/features/home/home_extras.dart';

CreditCard _card(String id, DateTime due, {double balance = 2500}) =>
    CreditCard(
      id: id,
      issuer: id.toUpperCase(),
      name: 'Card',
      last4: '0000',
      network: CardNetwork.visa,
      gradient: const [Color(0xFF000000), Color(0xFF111111)],
      limit: 10000,
      balance: balance,
      dueDate: due,
      minDue: 100,
      rewardsLabel: 'Cashback',
      rewardPoints: 0,
      rewardValueAed: 0,
      categoryRates: const {},
      statementBalance: balance,
    );

void main() {
  final today = DateTime(2026, 11, 28);

  test('nothing is urgent when every due date is more than 5 days out', () {
    expect(
      urgentBill([_card('a', DateTime(2026, 12, 20))], today: today),
      isNull,
    );
  });

  test('picks the soonest bill within 5 days', () {
    final b = urgentBill([
      _card('a', DateTime(2026, 12, 2)),
      _card('b', DateTime(2026, 11, 30)),
      _card('c', DateTime(2026, 12, 25)),
    ], today: today);
    expect(b?.card.id, 'b');
    expect(b?.daysLeft, 2);
  });

  test('an overdue bill outranks everything', () {
    final b = urgentBill([
      _card('a', DateTime(2026, 11, 29)),
      _card('b', DateTime(2026, 11, 20)),
    ], today: today);
    expect(b?.card.id, 'b');
    expect(b?.overdue, isTrue);
  });
}
