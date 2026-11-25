import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/captured_event.dart';
import 'package:pulse/capture/screenshot_text.dart';
import 'package:pulse/core/engine/sms_parser.dart';
import 'package:pulse/core/engine/types.dart';

/// Wordings copied from real Tabby push notifications; merchants and amounts
/// here are invented.
void main() {
  final at = DateTime.utc(2026, 11, 24, 9);
  ParsedTransaction? parse(String s) =>
      defaultParserRegistry.parse(s, receivedAt: at);

  test('purchase: amount from the title, never the card limit', () {
    final p = parse(
      'Transaction of AED 7.50. At EXAMPLE SHOP LLC was successful. '
      'Your available Tabby Card limit is AED 1,234.56.',
    )!;
    expect(p.amountMinor, 750);
    expect(p.direction, Direction.debit);
    expect(p.merchantRaw, 'EXAMPLE SHOP LLC');
    expect(p.institution, 'tabby');
  });

  test('adjustment down is a refund, up is more spend', () {
    final down = parse(
      'Transaction adjusted. Your EXAMPLE CHARGING purchase was decreased by AED 12.34',
    )!;
    expect(down.direction, Direction.credit);
    expect(down.amountMinor, 1234);
    expect(down.merchantRaw, 'EXAMPLE CHARGING');
    final up = parse(
      'Transaction adjusted. Your EXAMPLE CHARGING purchase was increased by AED 2.00',
    )!;
    expect(up.direction, Direction.debit);
  });

  test('payment is a credit; declined and promos are ignored', () {
    final p = parse(
      'Successful payment ✅. Your payment of 56.32 AED was successful',
    )!;
    expect(p.direction, Direction.credit);
    expect(p.amountMinor, 5632);
    expect(
      parse(
        'Transaction declined. You cannot use Tabby Card to make Tabby payment. Try again using a different payment method.',
      ),
      isNull,
    );
  });

  test('the body alone is not misread as the limit', () {
    final p = parse(
      'At EXAMPLE SHOP LLC was successful. Your available Tabby Card limit is AED 1,234.56.',
    );
    expect(p?.amountMinor == 123456, isFalse);
  });

  test('Android notification joins title and body and targets Tabby', () {
    final e = CapturedEvent(
      id: 'n1',
      kind: 'notification',
      app: 'ai.tabby.app',
      title: 'Transaction of AED 7.50',
      body: 'At EXAMPLE SHOP LLC was successful. Your available Tabby Card limit is AED 1,234.56.',
      timestamp: at,
    );
    final payload = e.toPending(at).payload;
    expect(payload['institution'], 'tabby');
    expect(
      payload['raw_text'],
      startsWith('Transaction of AED 7.50. At EXAMPLE'),
    );
  });

  test('screenshot of a Tabby banner reads the same way', () {
    final tx = parseScreenshotText(
      'Transaction of AED 7.50\nAt EXAMPLE SHOP LLC was successful. Your\navailable Tabby Card limit is AED\n1,234.56.',
      now: at,
    )!;
    expect(tx.amountMinor, 750);
    expect(tx.merchant, 'EXAMPLE SHOP LLC');
    expect(tx.viaScreenshot, isTrue);
  });
}
