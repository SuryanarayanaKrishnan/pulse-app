/// On-device auto-settle of splits. Pure Dart, no Flutter imports.
///
/// Given the counterparty of a bank line, SMS or Aani transfer and its amount,
/// decides whether it settles (part of) an open split balance with a contact.
/// Amounts are minor units (fils) so nothing here touches floating point.
library;

import 'fuzzy.dart';
import 'types.dart';

/// Who the money went to or came from, as the engine extracts it.
class Counterparty {
  const Counterparty({
    required this.name,
    required this.direction,
    this.phone,
    this.ibanTail,
  });

  final String name;

  /// [Direction.debit]: I paid them. [Direction.credit]: they paid me.
  final Direction direction;
  final String? phone;
  final String? ibanTail;
}

/// One contact in one group, with what is open between me and them.
class SplitContact {
  const SplitContact({
    required this.groupId,
    required this.memberId,
    required this.name,
    required this.balanceMinor,
    this.phone,
    this.ibanTail,
  });

  final String groupId;
  final String memberId;
  final String name;

  /// Positive: they owe me. Negative: I owe them.
  final int balanceMinor;
  final String? phone;
  final String? ibanTail;
}

enum MatchStrength { phone, iban, exactName, fuzzyName }

sealed class SettleDecision {
  const SettleDecision();
}

/// Nothing to settle.
class NoSettle extends SettleDecision {
  const NoSettle();
}

/// A proposed settlement: [fromMe] true when I pay, false when they pay me.
class SettleProposal {
  const SettleProposal({
    required this.contact,
    required this.amountMinor,
    required this.fromMe,
    required this.strength,
  });

  final SplitContact contact;
  final int amountMinor;
  final bool fromMe;
  final MatchStrength strength;

  /// Balance left after applying this payment (absolute, minor units).
  int get remainingMinor => contact.balanceMinor.abs() - amountMinor;
  bool get isPartial => remainingMinor > 0;
}

/// Sure enough to apply straight away (with an Undo).
class AutoSettle extends SettleDecision {
  const AutoSettle(this.proposal);
  final SettleProposal proposal;
}

/// Plausible but not sure: ask once.
class AskSettle extends SettleDecision {
  const AskSettle(this.proposal, this.key);
  final SettleProposal proposal;

  /// Stable key under which the answer is remembered.
  final String key;
}

enum RememberedAnswer { yes, no }

String normaliseName(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9؀-ۿ ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _digits(String? s) => (s ?? '').replaceAll(RegExp(r'\D'), '');

bool _samePhone(String? a, String? b) {
  final x = _digits(a), y = _digits(b);
  if (x.length < 7 || y.length < 7) return false;
  return x == y || x.endsWith(y) || y.endsWith(x);
}

bool _sameTail(String? a, String? b) {
  final x = (a ?? '').replaceAll(RegExp(r'\s'), '').toUpperCase();
  final y = (b ?? '').replaceAll(RegExp(r'\s'), '').toUpperCase();
  return x.length >= 4 && y.length >= 4 && (x.endsWith(y) || y.endsWith(x));
}

/// The key an answer is remembered under: the strongest identifier we have.
String counterpartyKey(Counterparty c, SplitContact contact) =>
    '${contact.groupId}:${contact.memberId}:'
    '${normaliseName(c.name).isNotEmpty ? normaliseName(c.name) : _digits(c.phone)}';

MatchStrength? _strength(Counterparty c, SplitContact m) {
  if (_samePhone(c.phone, m.phone)) return MatchStrength.phone;
  if (_sameTail(c.ibanTail, m.ibanTail)) return MatchStrength.iban;
  final a = normaliseName(c.name), b = normaliseName(m.name);
  if (a.isEmpty || b.isEmpty) return null;
  if (a == b) return MatchStrength.exactName;
  // "Sara" vs "SARA K" or a typo: plausible, never certain.
  if (tokenSetRatio(a, b) >= 85) return MatchStrength.fuzzyName;
  return null;
}

/// Decide what, if anything, a payment settles.
///
/// A contact qualifies when the direction fits (I paid someone I owe, or
/// someone who owes me paid me) and the amount does not exceed the open
/// balance. Phone or IBAN-tail matches and a unique exact name are confident;
/// fuzzy names, ties between contacts or groups, and unmatched-by-id payments
/// ask once. [remembered] holds earlier answers by [counterpartyKey].
SettleDecision decideSettlement({
  required Counterparty counterparty,
  required int amountMinor,
  required List<SplitContact> contacts,
  Map<String, RememberedAnswer> remembered = const {},
}) {
  if (amountMinor <= 0) return const NoSettle();
  final fromMe = counterparty.direction == Direction.debit;

  final candidates = <SettleProposal>[];
  for (final m in contacts) {
    final open = fromMe ? -m.balanceMinor : m.balanceMinor;
    if (open <= 0 || amountMinor > open) continue;
    final s = _strength(counterparty, m);
    if (s == null) continue;
    candidates.add(
      SettleProposal(
        contact: m,
        amountMinor: amountMinor,
        fromMe: fromMe,
        strength: s,
      ),
    );
  }
  if (candidates.isEmpty) return const NoSettle();

  // Strongest evidence first; a tie on the best tier is ambiguous.
  candidates.sort((a, b) => a.strength.index.compareTo(b.strength.index));
  final best = candidates.first;
  final tier = candidates.where((c) => c.strength == best.strength).toList();
  // The same person in several groups is only unambiguous when one group
  // holds this payment exactly; otherwise the user chooses once.
  var unique = tier.length == 1;
  var pick = best;
  if (!unique) {
    final exact = tier.where((c) => c.remainingMinor == 0).toList();
    if (exact.length == 1) {
      pick = exact.first;
      unique = true;
    }
  }

  final key = counterpartyKey(counterparty, pick.contact);
  switch (remembered[key]) {
    case RememberedAnswer.no:
      return const NoSettle();
    case RememberedAnswer.yes:
      return AutoSettle(pick);
    case null:
      break;
  }
  final strong = pick.strength != MatchStrength.fuzzyName;
  return unique && strong ? AutoSettle(pick) : AskSettle(pick, key);
}

/// Pull a phone number or IBAN tail out of a captured description, for
/// callers that only have raw text. Returns nulls when nothing is there.
({String? phone, String? ibanTail}) extractTransferIds(String text) {
  final iban = RegExp(
    r'(?:IBAN|A/?C|ACCOUNT)[^A-Z0-9]*(?:[A-Z]{2}\d{2})?[A-Z0-9 ]*?(\d{4})\b',
    caseSensitive: false,
  ).firstMatch(text);
  final phone = RegExp(r'(\+?\d[\d ]{8,14}\d)').firstMatch(text);
  return (
    phone: phone?.group(1)?.replaceAll(' ', ''),
    ibanTail: iban?.group(1),
  );
}
