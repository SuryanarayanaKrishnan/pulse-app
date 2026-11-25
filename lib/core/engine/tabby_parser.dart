import 'sms_parser.dart';
import 'types.dart';

/// Tabby Card push notifications. Wordings seen on a real phone:
///
///  * "Transaction of AED 5.00" / "At SHOP was successful. Your available Tabby
///    Card limit is AED 2,623.84."  (the amount is in the title, the limit in the
///    body: the limit must never be read as the amount)
///  * "Transaction adjusted" / "Your SHOP purchase was decreased by AED 83.61"
///    (a partial refund; "increased by" is more spend)
///  * "Successful payment" / "Your payment of 56.32 AED was successful"
///    (a repayment of the card, a credit)
///  * "Transaction declined" / "You cannot use Tabby Card ..." (nothing happened)
///
/// The card number is never shown, so there is no last 4: the transaction goes
/// to the user's Tabby card by institution.
class TabbyParser implements MessageParser {
  @override
  String get institution => 'tabby';

  static final _ws = RegExp(r'\s+');
  static final _purchase = RegExp(
    r'transaction of (?:AED|Dhs?\.?)\s?(?<amt>\d[\d,]*(?:\.\d{1,2})?)[ .:\-]*at (?<m>.+?) was successful',
    caseSensitive: false,
  );
  static final _adjusted = RegExp(
    r'your (?<m>.+?) purchase was (?<dir>decreased|increased) by (?:AED|Dhs?\.?)\s?(?<amt>\d[\d,]*(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  static final _payment = RegExp(
    r'your payment of (?:AED\s?)?(?<amt>\d[\d,]*(?:\.\d{1,2})?)(?:\s?AED)? was successful',
    caseSensitive: false,
  );

  @override
  bool matches(String? sender, String text) =>
      RegExp(r'tabby', caseSensitive: false).hasMatch(text) ||
      _purchase.hasMatch(text.replaceAll(_ws, ' ')) ||
      _adjusted.hasMatch(text.replaceAll(_ws, ' ')) ||
      _payment.hasMatch(text.replaceAll(_ws, ' '));

  @override
  ParsedTransaction? parse(String text, {DateTime? receivedAt}) {
    final t = text.replaceAll(_ws, ' ').trim();
    if (t.isEmpty || isOtpMessage(t)) return null;
    if (RegExp(r'declined', caseSensitive: false).hasMatch(t)) return null;

    ParsedTransaction make(String amt, Direction d, String? merchant) {
      final minor = parseMinorUnits(amt);
      if (minor == null || minor <= 0) throw const FormatException('amount');
      return ParsedTransaction(
        amountMinor: minor,
        currency: 'AED',
        direction: d,
        merchantRaw: merchant?.trim(),
        postedAt: receivedAt,
        institution: institution,
        confidence: 0.95,
      );
    }

    try {
      var m = _purchase.firstMatch(t);
      if (m != null)
        return make(m.namedGroup('amt')!, Direction.debit, m.namedGroup('m'));
      m = _adjusted.firstMatch(t);
      if (m != null) {
        final less = m.namedGroup('dir')!.toLowerCase() == 'decreased';
        return make(
          m.namedGroup('amt')!,
          less ? Direction.credit : Direction.debit,
          m.namedGroup('m'),
        );
      }
      m = _payment.firstMatch(t);
      if (m != null)
        return make(
          m.namedGroup('amt')!,
          Direction.credit,
          'Tabby card payment',
        );
    } on FormatException {
      return null;
    }
    return null;
  }
}
