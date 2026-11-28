import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/own_transfers.dart';
import 'package:pulse/core/engine/types.dart';

void main() {
  const sib = OwnAccountRef(
    id: 'sib',
    type: 'credit_card',
    institution: 'SIB',
    name: 'SIB Cashback',
    last4: '1111',
  );
  const tabby = OwnAccountRef(
    id: 'tabby',
    type: 'credit_card',
    institution: 'Tabby',
    name: 'Tabby Card',
  );
  const mashreq = OwnAccountRef(
    id: 'msq',
    type: 'bank',
    institution: 'Mashreq',
    name: 'Mashreq Current',
    last4: '9876',
  );
  const mashreqCard = OwnAccountRef(
    id: 'msqcc',
    type: 'credit_card',
    institution: 'Mashreq',
    name: 'Mashreq Cashback',
    last4: '4455',
  );
  const savings = OwnAccountRef(
    id: 'sav',
    type: 'bank',
    institution: 'ENBD',
    name: 'ENBD Savings',
    last4: '3322',
  );
  final all = [sib, tabby, mashreq, mashreqCard, savings];

  OwnTransferVerdict? run(
    String merchant,
    Direction d,
    OwnAccountRef source, {
    String? text,
  }) => classifyOwnTransfer(
    merchant: merchant,
    text: text,
    direction: d,
    source: source,
    accounts: all,
  );

  test('paying Tabby from the SIB card is a card bill, pointing at Tabby', () {
    final v = run('TABBY', Direction.debit, sib);
    expect(v?.kind, OwnTransferKind.cardBill);
    expect(v?.counterpartyId, 'tabby');
  });

  test('a Mashreq account paying a card by its last four', () {
    final v = run(
      'CREDIT CARD PAYMENT',
      Direction.debit,
      mashreq,
      text: 'AED 1,500 debited for credit card payment to card ending 4455',
    );
    expect(v?.kind, OwnTransferKind.cardBill);
    expect(v?.counterpartyId, 'msqcc');
  });

  test('"Mashreq" as the merchant on another bank is that card being paid', () {
    final v = run('MASHREQ CARD', Direction.debit, savings);
    expect(v?.kind, OwnTransferKind.cardBill);
    expect(v?.counterpartyId, 'msqcc');
  });

  test('transfer to own account, by wording and by account number', () {
    expect(
      run('IPI TRANSFER OWN ACCOUNT', Direction.debit, mashreq)?.kind,
      OwnTransferKind.ownAccount,
    );
    final byNumber = run(
      'FUND TRANSFER',
      Direction.debit,
      mashreq,
      text: 'Fund transfer of AED 5,000 to A/C ending 3322',
    );
    expect(byNumber?.kind, OwnTransferKind.ownAccount);
    expect(byNumber?.counterpartyId, 'sav');
  });

  test('the receiving side: payment into a card, and money into a bank', () {
    expect(
      run('PAYMENT RECEIVED', Direction.credit, sib)?.kind,
      OwnTransferKind.cardBill,
    );
    expect(
      run('Tabby card payment', Direction.credit, tabby)?.kind,
      OwnTransferKind.cardBill,
    );
    expect(
      run('IPI TRANSFER OWN ACCOUNT', Direction.credit, savings)?.kind,
      OwnTransferKind.ownAccount,
    );
  });

  test('ordinary spending, salary and a friend transfer are left alone', () {
    expect(run('CARREFOUR', Direction.debit, sib), isNull);
    expect(run('NOON', Direction.debit, mashreq), isNull);
    expect(run('SALARY WPS', Direction.credit, mashreq), isNull);
    expect(run('IPI TRANSFER TO AHMED KHAN', Direction.debit, mashreq), isNull);
    // A refund on a card is not a payment.
    expect(run('NOON REFUND', Direction.credit, sib), isNull);
    // The card's own name on its own line is not "paying another card".
    expect(run('SIB ANNUAL FEE', Direction.debit, sib), isNull);
  });

  test('a card word inside another word does not match', () {
    expect(run('TABBYS CAFE', Direction.debit, sib), isNull);
  });

  group('pairing', () {
    final t0 = DateTime.utc(2026, 11, 28, 10);
    TransferLeg leg(
      String id,
      String account,
      Direction d, {
      int minor = 50000,
      Duration after = Duration.zero,
      bool flagged = false,
      bool linked = false,
    }) => TransferLeg(
      id: id,
      accountId: account,
      amountMinor: minor,
      currency: 'AED',
      direction: d,
      postedAt: t0.add(after),
      flagged: flagged,
      linked: linked,
    );

    test('same amount, opposite side, other account, close in time', () {
      final me = leg('a', 'sib', Direction.debit);
      final hit = findOtherLeg(me, [
        leg('x', 'sib', Direction.credit), // same account
        leg('y', 'tabby', Direction.debit), // same direction
        leg('z', 'tabby', Direction.credit, minor: 49999), // other amount
        leg('w', 'tabby', Direction.credit, after: const Duration(days: 3)),
        leg('b', 'tabby', Direction.credit, after: const Duration(hours: 5)),
      ]);
      expect(hit?.id, 'b');
    });

    test('the nearest in time wins and a paired leg is never taken twice', () {
      final me = leg('a', 'sib', Direction.debit);
      final hit = findOtherLeg(me, [
        leg('far', 'tabby', Direction.credit, after: const Duration(days: 1)),
        leg('near', 'tabby', Direction.credit, after: const Duration(hours: 1)),
        leg('taken', 'tabby', Direction.credit, linked: true),
      ]);
      expect(hit?.id, 'near');
    });
  });
}
