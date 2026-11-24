import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/screenshot_text.dart';

void main() {
  final now = DateTime(2026, 11, 24, 12);

  test('reads a card purchase banner', () {
    final tx = parseScreenshotText(
      'Card alert\nAED 45.50 spent at CAFE NERO on card ending 4821.\n'
      'Available balance AED 9,999.00',
      now: now,
    )!;
    expect(tx.amountMinor, 4550);
    expect(tx.merchant, 'CAFE NERO');
    expect(tx.last4, '4821');
    expect(tx.direction, 'debit');
  });

  test('refund is a credit; trailing currency works', () {
    final tx = parseScreenshotText(
      'Refund of 120.00 AED from NOON has been credited',
      now: now,
    )!;
    expect(tx.amountMinor, 12000);
    expect(tx.direction, 'credit');
  });

  test('no amount, OTP or empty text yields nothing', () {
    expect(parseScreenshotText('Hello there', now: now), isNull);
    expect(parseScreenshotText('', now: now), isNull);
    expect(
      parseScreenshotText('Your OTP is 123456 for AED 50.00 payment', now: now),
      isNull,
    );
  });
}
