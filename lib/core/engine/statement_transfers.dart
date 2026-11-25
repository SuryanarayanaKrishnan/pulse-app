/// Finds person-to-person transfers among statement lines so they can be
/// offered to auto-settle. Pure Dart, no Flutter imports.
library;

import 'split_settle.dart';
import 'types.dart';

final _marker = RegExp(
  r'\b(?:IPI|AANI|IBAN|FUND|ONLINE|MOBILE|INSTANT|SEND\s+MONEY|TRANSFER|TRF|XFER)\b',
  caseSensitive: false,
);

/// Lines that look like transfers but are never someone to settle with.
final _notPerson = RegExp(
  r'SALARY|WPS|PAYROLL|CREDIT\s*CARD|CARD\s+PAYMENT|OWN\s+ACCOUNT|SELF|INTEREST|FEE|CHARGE|REFUND|REVERSAL|EXCHANGE|REMIT',
  caseSensitive: false,
);

final _noise = RegExp(
  r'\b(?:IPI|AANI|IBAN|FUND|ONLINE|MOBILE|INSTANT|SEND|MONEY|TRANSFER|TRF|XFER|TO|FROM|FOR|BY|REF|REFERENCE|A/?C|ACCOUNT|NO|AED|DR|CR|P2P|PAYMENT|CREDIT|DEBIT|ACC)\b',
  caseSensitive: false,
);

/// The person behind a transfer line, or null when it is not a transfer to or
/// from a person (card payments, salary, shops, lines with no name or number).
Counterparty? transferCounterparty(String description, Direction direction) {
  if (!_marker.hasMatch(description) || _notPerson.hasMatch(description)) {
    return null;
  }
  final ids = extractTransferIds(description);
  var name = description
      .replaceAll(RegExp(r'[A-Z]{2}\d{2}[A-Z0-9 ]{10,}', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'[\d+][\d ]{3,}'), ' ')
      .replaceAll(_noise, ' ')
      .replaceAll(RegExp(r'[^A-Za-z؀-ۿ ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (name.length < 2) name = '';
  if (name.isEmpty && ids.phone == null && ids.ibanTail == null) return null;
  return Counterparty(
    name: name,
    direction: direction,
    phone: ids.phone,
    ibanTail: ids.ibanTail,
  );
}
