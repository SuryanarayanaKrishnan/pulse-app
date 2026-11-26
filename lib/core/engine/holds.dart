/// Card pre-authorisation holds: a merchant (an EV charger, a hotel, a car
/// rental) blocks a round amount, say AED 100, then settles the real, smaller
/// amount and releases the rest. The bank may SMS the hold, the final charge,
/// or both, and the merchant emails each step. Without care the 100 is counted
/// as spend next to the 14.85 that was actually paid.
///
/// Pure Dart. The rules, in one place:
///  * a debit at a pre-authorising merchant that looks like a hold (a round
///    amount, or one a notice announced) is a *hold*: kept, shown as pending,
///    excluded from budgets;
///  * a later debit at the same merchant and card for an amount no larger than
///    the hold *settles* it: the hold row becomes the real charge and the
///    separate row is not created;
///  * a "released" notice, or no settlement after [holdExpiry], voids the hold.
library;

import 'dedupe.dart';
import 'types.dart';

/// Tag on a transaction that is still only a hold.
const holdTag = 'pending_hold';

/// A hold the bank never settles is released by the bank within days.
const holdExpiry = Duration(days: 7);

/// Settlement lands within a day or two of the hold; allow for a long charge.
const settleWindow = Duration(days: 3);

enum HoldNoticeKind { hold, settlement, release }

class HoldNotice {
  const HoldNotice({
    required this.kind,
    required this.merchant,
    required this.holdMinor,
    this.finalMinor,
    this.currency = 'AED',
  });
  final HoldNoticeKind kind;

  /// Merchant as the bank statement will most likely show it.
  final String merchant;

  /// The amount blocked.
  final int holdMinor;

  /// The amount actually charged (settlement notices only).
  final int? finalMinor;
  final String currency;

  @override
  String toString() =>
      'HoldNotice($kind $merchant hold=$holdMinor final=$finalMinor)';
}

final _ws = RegExp(r'\s+');
final _amount = r'(?:AED|Dhs?\.?)\s?(?<n>\d[\d,]*(?:\.\d{1,2})?)';
final _preauth = RegExp(r'pre-?\s?authori[sz]ation', caseSensitive: false);

/// Sender domain (or name) -> how the charge appears on the statement.
const _knownSenders = <String, String>{
  'regeny': 'Regeny EV charging',
  'evgateway': 'Regeny EV charging',
};

/// Reads a merchant's hold / settlement / release email. Null when [text] is
/// not one. [sender] and [subject] are optional extra evidence.
HoldNotice? parseHoldNotice(String text, {String? sender, String? subject}) {
  final t = '${subject ?? ''} $text'.replaceAll(_ws, ' ').trim();
  if (!_preauth.hasMatch(t)) return null;
  final lower = t.toLowerCase();

  int? amt(RegExpMatch? m) =>
      m == null ? null : parseMinorUnits(m.namedGroup('n')!);

  final settlement = RegExp(
    r'final settlement amount of ' + _amount,
    caseSensitive: false,
  ).firstMatch(t);
  final preauthAmount = RegExp(
    r'pre-?\s?authori[sz]ation (?:hold )?(?:of|in the amount of) ' + _amount,
    caseSensitive: false,
  ).firstMatch(t);
  final holdPlaced = RegExp(
    r'hold has been placed.{0,40}?amount of ' + _amount,
    caseSensitive: false,
  ).firstMatch(t);

  HoldNoticeKind kind;
  int? hold;
  int? fin;
  if (settlement != null) {
    kind = HoldNoticeKind.settlement;
    fin = amt(settlement);
    hold = amt(
      RegExp(
        r'pre-?\s?authori[sz]ation of ' + _amount,
        caseSensitive: false,
      ).firstMatch(t),
    );
  } else if (holdPlaced != null) {
    kind = HoldNoticeKind.hold;
    hold = amt(holdPlaced);
  } else if (lower.contains('released') && preauthAmount != null) {
    kind = HoldNoticeKind.release;
    hold = amt(preauthAmount);
  } else {
    return null;
  }
  if (hold == null || hold <= 0) return null;

  var merchant = _merchantFrom(sender, t);
  if (merchant == null) return null;
  return HoldNotice(
    kind: kind,
    merchant: merchant,
    holdMinor: hold,
    finalMinor: fin,
  );
}

String? _merchantFrom(String? sender, String text) {
  final hay = '${sender ?? ''} $text'.toLowerCase();
  for (final e in _knownSenders.entries) {
    if (hay.contains(e.key)) return e.value;
  }
  // "... for Regeny EV charging session", "For Acme Parking."
  final m = RegExp(
    r"\bfor (?:your |the )?(?<m>[A-Z][A-Za-z0-9&'.\- ]{2,40}?)(?: session| purchase| booking|\.|,| Please| We )",
  ).firstMatch(text);
  return m?.namedGroup('m')?.trim();
}

/// Merchants that pre-authorise a card (statement names or fragments).
const _preauthMerchants = [
  'regeny',
  'evgateway',
  'ev charging',
  'uaev',
  'ev charge',
  'charging station',
  'chargepoint',
  'hertz',
  'avis',
  'budget rent',
  'thrifty',
  'sixt',
  'rent a car',
  'rental',
  'hotel',
];

bool isPreauthMerchant(String? merchant) {
  if (merchant == null) return false;
  final m = merchant.toLowerCase();
  return _preauthMerchants.any(m.contains);
}

/// A debit that is probably a hold: a pre-authorising merchant and a round
/// amount (AED 50, 100, 200, 500, 1,000 ...).
bool looksLikeHold(String? merchant, int amountMinor, Direction d) =>
    d == Direction.debit &&
    isPreauthMerchant(merchant) &&
    amountMinor >= 5000 &&
    amountMinor % 5000 == 0;

/// An open hold on a stored row: tagged, and not yet expired.
bool isOpenHold(Iterable<String> tags, DateTime postedAt, DateTime now) =>
    tags.contains(holdTag) && now.difference(postedAt) <= holdExpiry;

/// True when [merchantA] and [merchantB] are the same shop for hold purposes.
bool sameHoldMerchant(String? a, String? b) {
  if (a == null || b == null) return false;
  final s = merchantScore(a, b);
  if (s != null && s >= minMerchantScore) return true;
  // Statement lines and SMS often differ in everything but the brand.
  for (final key in _preauthMerchants) {
    if (a.toLowerCase().contains(key) && b.toLowerCase().contains(key))
      return true;
  }
  return false;
}
