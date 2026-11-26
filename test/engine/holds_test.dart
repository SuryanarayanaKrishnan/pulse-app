import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/holds.dart';
import 'package:pulse/core/engine/types.dart' show Direction;

// Wording copied from real merchant emails (names, card and account digits removed).
const holdText =
    'Dear Customer, We hope this email finds you well. We are writing to inform you that a '
    'pre-authorization hold has been placed on your card in the amount of AED100.0 For Regeny EV charging. '
    'Please note that this is not a charge.';
const settleText =
    'Dear Customer, We are reaching out to inform you that the final settlement amount of AED14.85 has been '
    'processed for your Regeny EV charging session.\nThe remaining amount from pre-authorization of AED100 will '
    'be released shortly. Please note that depending on your financial institution, this process may take a few business days.';
const releaseText =
    'Dear Customer, We wanted to inform you that the pre-authorization hold of AED100.0 for your Regeny EV '
    'charging session has been successfully released. The funds are no longer held.';

void main() {
  test('hold email', () {
    final n = parseHoldNotice(
      holdText,
      sender: 'noreply@regeny.ae',
      subject: 'Pre-Authorization Hold for Regeny EV charging',
    )!;
    expect(n.kind, HoldNoticeKind.hold);
    expect(n.holdMinor, 10000);
    expect(n.merchant, 'Regeny EV charging');
  });

  test('settlement email carries final and held amounts', () {
    final n = parseHoldNotice(settleText, sender: 'noreply@regeny.ae')!;
    expect(n.kind, HoldNoticeKind.settlement);
    expect(n.finalMinor, 1485);
    expect(n.holdMinor, 10000);
  });

  test('release email', () {
    final n = parseHoldNotice(releaseText, sender: 'noreply@regeny.ae')!;
    expect(n.kind, HoldNoticeKind.release);
    expect(n.holdMinor, 10000);
  });

  test('charging receipts and ordinary mail are not hold notices', () {
    expect(
      parseHoldNotice(
        'Thank you for charging with Regeny. Total Paid: AED 14.85',
        sender: 'noreply@regeny.ae',
      ),
      isNull,
    );
    expect(parseHoldNotice('50% off at Noon this weekend'), isNull);
  });

  test('hold heuristics', () {
    expect(
      looksLikeHold('REGENY EV CHARGING DUBAI', 10000, Direction.debit),
      isTrue,
    );
    expect(
      looksLikeHold('REGENY EV CHARGING DUBAI', 1485, Direction.debit),
      isFalse,
    );
    expect(looksLikeHold('Starbucks', 10000, Direction.debit), isFalse);
    expect(
      sameHoldMerchant('REGENY EV CHARGING', 'Regeny EV charging'),
      isTrue,
    );
  });
}
