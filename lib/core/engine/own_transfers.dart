/// Money moving between the user's own accounts and cards is not spending.
///
/// Paying the Tabby bill from a SIB card, paying a Mashreq card from a Mashreq
/// account, moving cash between two own accounts: each leg is captured as its
/// own SMS or notification, and counting either leg as spend counts the same
/// money twice (the Tabby purchase itself was already captured).
///
/// This module decides, from one captured line and the user's own accounts,
/// whether it looks like such a movement. It never decides alone: callers keep
/// the line out of spend and budgets, then ask the person to confirm.
///
/// Pure Dart, no Flutter and no I/O.
library;

import 'institutions.dart';
import 'split_settle.dart' show extractTransferIds;
import 'types.dart';

/// Tags written on a transaction (the `tags` JSON list).
const ownTransferTag = 'own_transfer';
const cardBillTag = 'card_bill';
const ownAccountTag = 'own_account_transfer';

/// `link:<transactionId>`: the other leg of this movement.
const linkTagPrefix = 'link:';

/// `orig_cat:<categoryId>`: what the line was before it was seen as a movement,
/// so "not a transfer" can put it back. Empty id means it had no category.
const origCategoryTagPrefix = 'orig_cat:';

/// A card paid through a wallet still earns on the paying card (Tabby repaid
/// from a SIB card earns SIB's online rate), so the line stays in that card's
/// cashback cycle even though it is not spending.
const rewardableTag = 'rewardable';

enum OwnTransferKind {
  /// Paying a credit card (or Tabby) bill from another account or card.
  cardBill,

  /// Moving money between two of the user's own accounts.
  ownAccount;

  String get tag => switch (this) {
    cardBill => cardBillTag,
    ownAccount => ownAccountTag,
  };

  /// The category the line is filed under: neither is spend nor income.
  String get categorySlug => switch (this) {
    cardBill => 'cc_payment',
    ownAccount => 'transfer',
  };

  static OwnTransferKind? fromTags(Iterable<String> tags) {
    if (tags.contains(cardBillTag)) return cardBill;
    if (tags.contains(ownAccountTag)) return ownAccount;
    return null;
  }
}

/// What the detector needs to know about one of the user's accounts.
class OwnAccountRef {
  const OwnAccountRef({
    required this.id,
    required this.type,
    this.institution,
    this.name,
    this.last4,
  });
  final String id;

  /// bank | credit_card | wallet | cash
  final String type;
  final String? institution, name, last4;

  bool get isCard => type == 'credit_card';
}

class OwnTransferVerdict {
  const OwnTransferVerdict(this.kind, this.reason, {this.counterpartyId});
  final OwnTransferKind kind;

  /// Short, plain: why it looks like a movement ("Tabby is one of your cards").
  final String reason;

  /// The own account at the other end, when the text or merchant names it.
  final String? counterpartyId;

  @override
  String toString() => 'OwnTransferVerdict($kind, $reason, $counterpartyId)';
}

String _norm(String s) => s
    .toUpperCase()
    .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

final _transferMarker = RegExp(
  r'\b(?:IPI|AANI|IBAN|FUND|ONLINE|MOBILE|INSTANT|SEND\s+MONEY|TRANSFER(?:RED)?|TRF|XFER)\b',
  caseSensitive: false,
);

final _ownWords = RegExp(
  r'\b(?:OWN\s+ACC(?:OUNT)?|MY\s+(?:OWN\s+)?ACC(?:OUNT)?|SELF|BETWEEN\s+(?:MY\s+)?OWN|SAME\s+NAME|OWN\s+NAME)\b',
  caseSensitive: false,
);

final _billWords = RegExp(
  r'\b(?:CREDIT\s*CARD\s*(?:PAYMENT|PMT|BILL|SETTLEMENT|REPAYMENT)|CARD\s*(?:PAYMENT|PMT|BILL|SETTLEMENT|REPAYMENT)|CC\s*(?:PAYMENT|PMT|BILL)|PAYMENT\s+TO\s+(?:MY\s+)?(?:CREDIT\s+)?CARD|PAY(?:ING)?\s+(?:CREDIT\s+)?CARD\s+BILL|BILL\s+PAYMENT\s+(?:TO\s+)?(?:CREDIT\s+)?CARD)\b',
  caseSensitive: false,
);

/// A credit on a card account that says it is a payment, not a refund.
final _paymentReceived = RegExp(
  r'\b(?:PAYMENT\s+RECEIVED|PAYMENT\s*-?\s*THANK\s*YOU|THANK\s+YOU\s+FOR\s+YOUR\s+PAYMENT|AUTOPAY|CARD\s+PAYMENT|SUCCESSFUL\s+PAYMENT|PAYMENT\s+OF)\b',
  caseSensitive: false,
);

/// Does [haystack] (uppercase, normalised) name this institution/card word?
bool _mentions(String haystack, String? needle) {
  if (needle == null) return false;
  final n = _norm(needle);
  if (n.length < 3) return false;
  return RegExp('(?:^| )${RegExp.escape(n)}(?: |\$)').hasMatch(haystack);
}

/// The word(s) a card is known by in a merchant string: its issuer, else the
/// first word of its name ("Tabby", "SIB").
Iterable<String> _cardNames(OwnAccountRef a) sync* {
  final inst = a.institution;
  if (inst != null && inst.trim().isNotEmpty) {
    yield inst;
    final key = institutions.resolveKey(inst);
    if (key != null) yield key;
  }
  final first = (a.name ?? '').trim().split(RegExp(r'\s+')).firstOrNull;
  if (first != null && first.isNotEmpty) yield first;
}

/// Looks at one captured line. Returns null when it looks like ordinary
/// spending or income.
///
/// [text] is the full captured text (or the merchant when that is all there
/// is); [source] is the account the line was captured on.
OwnTransferVerdict? classifyOwnTransfer({
  required String? merchant,
  required String? text,
  required Direction direction,
  required OwnAccountRef source,
  required List<OwnAccountRef> accounts,
}) {
  final others = [
    for (final a in accounts)
      if (a.id != source.id) a,
  ];
  final body = '${merchant ?? ''} ${text ?? ''}'.trim();
  if (body.isEmpty) return null;
  final up = _norm(body);

  // The other end, when the text names one of the user's own cards by its last
  // four digits or its issuer.
  OwnAccountRef? named;
  final digits = RegExp(r'(?<!\d)(\d{4})(?!\d)')
      .allMatches(body)
      .map((m) => m[1]);
  final last4s = {...digits};
  final ids = extractTransferIds(body);
  if (ids.ibanTail != null) last4s.add(ids.ibanTail);
  for (final a in others) {
    if (a.last4 != null && last4s.contains(a.last4)) {
      named = a;
      break;
    }
  }

  if (direction == Direction.debit) {
    // 1. "Credit card payment", "Payment to card XXXX1234".
    if (_billWords.hasMatch(body)) {
      final card = named != null && named.isCard
          ? named
          : _cardNamed(others, up);
      return OwnTransferVerdict(
        OwnTransferKind.cardBill,
        card == null ? 'A card bill payment' : 'Paying your ${_label(card)}',
        counterpartyId: card?.id,
      );
    }
    // 2. The merchant is one of the user's own cards: paying Tabby.
    final card = _cardNamed(others, up);
    if (card != null && card.isCard) {
      return OwnTransferVerdict(
        OwnTransferKind.cardBill,
        '${_label(card)} is one of your cards',
        counterpartyId: card.id,
      );
    }
    // 3. A transfer that says it is to the user's own account.
    if (_transferMarker.hasMatch(body) && _ownWords.hasMatch(body)) {
      return OwnTransferVerdict(
        OwnTransferKind.ownAccount,
        'A transfer between your own accounts',
        counterpartyId: named?.id,
      );
    }
    // 4. A transfer to an account number that is one of the user's own.
    if (_transferMarker.hasMatch(body) && named != null) {
      return OwnTransferVerdict(
        named.isCard ? OwnTransferKind.cardBill : OwnTransferKind.ownAccount,
        'Goes to your ${_label(named)}',
        counterpartyId: named.id,
      );
    }
    return null;
  }

  // Credits.
  if (source.isCard && _paymentReceived.hasMatch(body)) {
    return OwnTransferVerdict(
      OwnTransferKind.cardBill,
      'A payment into your ${_label(source)}',
    );
  }
  if (!source.isCard && _transferMarker.hasMatch(body)) {
    if (_ownWords.hasMatch(body)) {
      return OwnTransferVerdict(
        OwnTransferKind.ownAccount,
        'A transfer between your own accounts',
        counterpartyId: named?.id,
      );
    }
    if (named != null && !named.isCard) {
      return OwnTransferVerdict(
        OwnTransferKind.ownAccount,
        'Comes from your ${_label(named)}',
        counterpartyId: named.id,
      );
    }
  }
  return null;
}

OwnAccountRef? _cardNamed(List<OwnAccountRef> others, String up) {
  for (final a in others) {
    if (!a.isCard) continue;
    for (final n in _cardNames(a)) {
      if (_mentions(up, n)) return a;
    }
  }
  return null;
}

String _label(OwnAccountRef a) {
  final n = (a.name ?? '').trim();
  final i = (a.institution ?? '').trim();
  final base = n.isNotEmpty ? n : (i.isNotEmpty ? i : 'account');
  return a.last4 == null ? base : '$base ····${a.last4}';
}

/// One side of a possible movement, for pairing.
class TransferLeg {
  const TransferLeg({
    required this.id,
    required this.accountId,
    required this.amountMinor,
    required this.currency,
    required this.direction,
    required this.postedAt,
    this.flagged = false,
    this.linked = false,
    this.accountIsCard = false,
  });
  final String id, accountId, currency;
  final int amountMinor;
  final Direction direction;
  final DateTime postedAt;

  /// Already seen as a movement by the detector.
  final bool flagged;

  /// Already paired with another leg.
  final bool linked;
  final bool accountIsCard;
}

/// How far apart the two legs of one movement may land.
const pairWindow = Duration(days: 2);

/// The other leg of [leg]: opposite direction, another account, same amount
/// and currency, close in time, not yet paired. [candidates] are everything
/// nearby. The nearest in time wins; on a tie the flagged one does.
TransferLeg? findOtherLeg(TransferLeg leg, Iterable<TransferLeg> candidates) {
  TransferLeg? best;
  Duration? bestGap;
  for (final c in candidates) {
    if (c.id == leg.id ||
        c.linked ||
        c.accountId == leg.accountId ||
        c.direction == leg.direction ||
        c.amountMinor != leg.amountMinor ||
        c.currency != leg.currency) {
      continue;
    }
    final gap = c.postedAt.difference(leg.postedAt).abs();
    if (gap > pairWindow) continue;
    if (best == null ||
        gap < bestGap! ||
        (gap == bestGap && c.flagged && !best.flagged)) {
      best = c;
      bestGap = gap;
    }
  }
  return best;
}
