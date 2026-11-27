import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/sms_parser.dart';
import 'package:pulse/core/engine/types.dart';

// Wording copied from real Mashreq alert emails (names removed).
const neoDebit =
    'Transaction notification on your Mashreq NEO Account Dear Customer, Thank you for banking with Mashreq. '
    'Your AC No:XXXXXXXX1262 is debited with AED 91.00 for Aani Instant Payments (Local IPP Transfer). '
    'Login to Online Banking for details To view details, log in to Mashreq Mobile App or Online Banking.';
const neoSalary =
    'Transaction notification on your Mashreq NEO Account Dear Customer, Thank you for banking with Mashreq. '
    'Your AC No: XXXXXXXX1262 is credited with AED 15000.00 for Salary. Login to Online Banking for details.';
const neoInward =
    'Dear Customer, Thank you for banking with Mashreq. An amount of AED 5714.18 has been credited to your '
    'Mashreq a/c no. XXXXXXXX1262 for Inward Remittance. Login to Online Banking to view details.';
const neoDebitAmount =
    'Dear Customer, Thank you for banking with Mashreq. Amount of AED 13750.00 has been debited from your '
    'Mashreq account no. XXXXXXXX1262 for Account to Account Transfer. Login to Online Banking for details.';
const neoA2A =
    'Your AC No: XXXXXXXX1262 is credited with AED 125.00 as Account to Account Transfer. Login to Online Banking for details.';
const card =
    'Dear Customer, Thank you for banking with Mashreq Bank. Please note the details of a recent transaction on '
    'your Mashreq Card. Your Mashreq Cashback Card ending with 9333 was used for a purchase of EUR .93 at '
    'ORACLE IRELAND 35318033509 IE on 25-NOV-2026 05:01 PM. Available limit is AED 32,596.10 This is a system generated alert.';
const cardAed =
    'Your Mashreq Cashback Card ending with 9333 was used for a purchase of AED 56.50 at CARREFOUR MOE on 25-NOV-2026 05:01 PM. '
    'Available limit is AED 32,596.10';

void main() {
  final r = defaultParserRegistry;
  ParsedTransaction? p(String t) =>
      r.parse(t, sender: 'MashreqAlerts@mashreq.com');

  test('NEO debit', () {
    final x = p(neoDebit)!;
    expect(
      (x.amountMinor, x.currency, x.direction, x.last4),
      (9100, 'AED', Direction.debit, '1262'),
    );
    expect(x.merchantRaw, 'Aani Instant Payments');
    expect(x.institution, 'mashreq');
  });

  test('NEO salary credit', () {
    final x = p(neoSalary)!;
    expect(
      (x.amountMinor, x.direction, x.last4),
      (1500000, Direction.credit, '1262'),
    );
    expect(x.merchantRaw, 'Salary');
  });

  test('inward remittance, amount-first wordings and account to account', () {
    final a = p(neoInward)!;
    expect(
      (a.amountMinor, a.direction, a.merchantRaw),
      (571418, Direction.credit, 'Inward Remittance'),
    );
    final b = p(neoDebitAmount)!;
    expect(
      (b.amountMinor, b.direction, b.merchantRaw),
      (1375000, Direction.debit, 'Account to Account Transfer'),
    );
    final c = p(neoA2A)!;
    expect((c.amountMinor, c.direction), (12500, Direction.credit));
  });

  test('card purchase email, including a foreign amount written without a leading zero', () {
    final x = p(card)!;
    expect(
      (x.amountMinor, x.currency, x.direction, x.last4),
      (93, 'EUR', Direction.debit, '9333'),
    );
    expect(x.merchantRaw, startsWith('ORACLE IRELAND'));
    final y = p(cardAed)!;
    expect(
      (y.amountMinor, y.currency, y.merchantRaw),
      (5650, 'AED', 'CARREFOUR MOE'),
    );
  });

  test('promotions, surveys, card-viewed notices and statements are not transactions', () {
    for (final t in [
      'Get up to 40% off on noon Food with your Mashreq Credit Card Dear Customer, More savings, more reasons to order from noon Food.',
      'Your credit card details were viewed successfully Dear SURYANARAYANA KRISHNAN, You have successfully viewed your credit card details on your Mashreq Mobile Banking App for the card ending with ****9333',
      'Help us serve you better Dear Customer, We value your relationship with Mashreq and request your participation in a short survey.',
    ]) {
      expect(p(t), isNull, reason: t);
    }
  });
}
