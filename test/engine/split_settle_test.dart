import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/split_settle.dart';
import 'package:pulse/core/engine/types.dart';

// Synthetic fixtures only: invented names, numbers and amounts.
SplitContact c(
  String id,
  String name,
  int bal, {
  String group = 'g1',
  String? phone,
  String? tail,
}) => SplitContact(
  groupId: group,
  memberId: id,
  name: name,
  balanceMinor: bal,
  phone: phone,
  ibanTail: tail,
);

Counterparty cp(String name, Direction d, {String? phone, String? tail}) =>
    Counterparty(name: name, direction: d, phone: phone, ibanTail: tail);

void main() {
  final contacts = [
    c('a', 'Tariq Example', 5000, phone: '+971500000001', tail: '1111'),
    c('b', 'Lena Sample', -3000, phone: '+971500000002'),
  ];

  test('incoming transfer from a debtor settles by phone, confidently', () {
    final d = decideSettlement(
      counterparty: cp('Unknown Sender', Direction.credit, phone: '0500000001'),
      amountMinor: 5000,
      contacts: contacts,
    );
    expect(d, isA<AutoSettle>());
    final p = (d as AutoSettle).proposal;
    expect(p.fromMe, isFalse);
    expect(p.strength, MatchStrength.phone);
    expect(p.isPartial, isFalse);
  });

  test('outgoing transfer settles what I owe, matched by IBAN tail', () {
    final withTail = [c('b', 'Lena Sample', -3000, tail: '9999')];
    final d = decideSettlement(
      counterparty: cp('X', Direction.debit, tail: '9999'),
      amountMinor: 3000,
      contacts: withTail,
    );
    expect((d as AutoSettle).proposal.fromMe, isTrue);
    expect(d.proposal.strength, MatchStrength.iban);
  });

  test('partial payment leaves the remainder open', () {
    final d = decideSettlement(
      counterparty: cp('Tariq Example', Direction.credit),
      amountMinor: 2000,
      contacts: contacts,
    );
    final p = (d as AutoSettle).proposal;
    expect(p.isPartial, isTrue);
    expect(p.remainingMinor, 3000);
  });

  test('amount above the open balance does not match', () {
    expect(
      decideSettlement(
        counterparty: cp('Tariq Example', Direction.credit),
        amountMinor: 5001,
        contacts: contacts,
      ),
      isA<NoSettle>(),
    );
  });

  test('direction must fit the balance', () {
    // Tariq owes me; me paying Tariq is not a settlement.
    expect(
      decideSettlement(
        counterparty: cp('Tariq Example', Direction.debit),
        amountMinor: 1000,
        contacts: contacts,
      ),
      isA<NoSettle>(),
    );
  });

  test('fuzzy name asks instead of applying', () {
    final d = decideSettlement(
      counterparty: cp('TARIQ EXAMPLES', Direction.credit),
      amountMinor: 1000,
      contacts: contacts,
    );
    expect(d, isA<AskSettle>());
  });

  test('unrelated name does nothing', () {
    expect(
      decideSettlement(
        counterparty: cp('Coffee Corner', Direction.credit),
        amountMinor: 1000,
        contacts: contacts,
      ),
      isA<NoSettle>(),
    );
  });

  test('remembered answers skip the question', () {
    final ask = decideSettlement(
      counterparty: cp('TARIQ EXAMPLES', Direction.credit),
      amountMinor: 1000,
      contacts: contacts,
    ) as AskSettle;
    expect(
      decideSettlement(
        counterparty: cp('TARIQ EXAMPLES', Direction.credit),
        amountMinor: 1000,
        contacts: contacts,
        remembered: {ask.key: RememberedAnswer.yes},
      ),
      isA<AutoSettle>(),
    );
    expect(
      decideSettlement(
        counterparty: cp('TARIQ EXAMPLES', Direction.credit),
        amountMinor: 1000,
        contacts: contacts,
        remembered: {ask.key: RememberedAnswer.no},
      ),
      isA<NoSettle>(),
    );
  });

  test('same person in two groups asks unless one is cleared exactly', () {
    final two = [
      c('a', 'Tariq Example', 5000, group: 'g1'),
      c('a2', 'Tariq Example', 4000, group: 'g2'),
    ];
    expect(
      decideSettlement(
        counterparty: cp('Tariq Example', Direction.credit),
        amountMinor: 1000,
        contacts: two,
      ),
      isA<AskSettle>(),
    );
    final d = decideSettlement(
      counterparty: cp('Tariq Example', Direction.credit),
      amountMinor: 4000,
      contacts: two,
    );
    expect((d as AutoSettle).proposal.contact.groupId, 'g2');
  });

  test('zero or negative amounts are ignored', () {
    expect(
      decideSettlement(
        counterparty: cp('Tariq Example', Direction.credit),
        amountMinor: 0,
        contacts: contacts,
      ),
      isA<NoSettle>(),
    );
  });

  test('extractTransferIds finds a phone and an IBAN tail', () {
    final r = extractTransferIds(
      'Aani transfer from +971 50 000 0001 IBAN AE00 0000 1234',
    );
    expect(r.phone, '+971500000001');
    expect(r.ibanTail, '1234');
  });
}
