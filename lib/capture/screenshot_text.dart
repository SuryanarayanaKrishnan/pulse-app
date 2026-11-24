import '../core/engine/sms_parser.dart' show isOtpMessage;
import 'apple_shortcut.dart';

/// Reads a payment out of text recognised on a screenshot (a notification
/// banner or an order screen). Conservative: if no clear amount is found it
/// returns null and the screenshot text is dropped, so nothing guesses.
/// The image itself never leaves the Shortcuts action that read it.
ShortcutTransaction? parseScreenshotText(String text, {DateTime? now}) {
  final t = text.replaceAll('\r', '');
  if (t.trim().isEmpty || isOtpMessage(t)) return null;
  final lines = [
    for (final l in t.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ];

  const skip = r'balance|available|limit|cashback|outstanding|points|reward';
  final skipRe = RegExp(skip, caseSensitive: false);
  final amountRe = RegExp(
    r'(?:AED|Dhs?\.?)\s?(\d[\d,]*(?:\.\d{1,2})?)|(\d[\d,]*(?:\.\d{1,2})?)\s?(?:AED|Dhs?\b)',
    caseSensitive: false,
  );
  String? amount;
  for (final l in lines) {
    if (skipRe.hasMatch(l)) continue;
    final m = amountRe.firstMatch(l);
    if (m != null) {
      amount = m.group(1) ?? m.group(2);
      break;
    }
  }
  if (amount == null) return null;

  String? merchant;
  final at = RegExp(
    r'(?:\bat|\bfrom|\bto|merchant:?)\s+([A-Za-z0-9][A-Za-z0-9 &\x27\-\.]{1,38}?)(?=\s+(?:on|using|with|card|for|has|was|ending)\b|[,.\n]|$)',
    caseSensitive: false,
  );
  for (final l in lines) {
    final m = at.firstMatch(l);
    if (m != null) {
      merchant = m.group(1)!.trim();
      break;
    }
  }

  final last4 = RegExp(
    r'(?:ending(?: with)?|card|[*•x]{2,})\s*:?\s*(\d{4})\b',
    caseSensitive: false,
  ).firstMatch(t)?.group(1);

  final credit = RegExp(
    r'refund|credited|received|reversal',
    caseSensitive: false,
  ).hasMatch(t);

  final tx = ShortcutTransaction.tryParse(
    Uri(
      scheme: 'pulse',
      host: 'ingest',
      queryParameters: {
        'amount': 'AED $amount',
        'merchant': ?merchant,
        'card': ?last4,
        if (credit) 'direction': 'credit',
      },
    ),
    now: now,
  );
  return tx?.asScreenshot();
}
