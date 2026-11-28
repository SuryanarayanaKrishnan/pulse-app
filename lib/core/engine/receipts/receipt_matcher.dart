/// Links a receipt to an existing card charge. Pure Dart.
///
/// Rules: the charge is a debit not yet linked to a receipt; the card's last
/// four digits agree when both sides know them; the amount is the receipt
/// total (or total less a discount line) within a small tolerance, or a bit
/// above it for tip and VAT; the date is within [matchWindowDays]; and the
/// merchant looks alike. A receipt that fits two charges equally well is
/// ambiguous and is never auto-linked.
library;

import '../fuzzy.dart';
import '../split_settle.dart' show normaliseName;
import 'receipt_models.dart';

const matchWindowDays = 3;

/// Charge amounts may exceed the receipt by up to this share (tip, VAT).
const tipVatAllowance = 0.15;

/// Rounding tolerance either way, in fils (AED 1).
const amountToleranceMinor = 100;

class Charge {
  const Charge({
    required this.id,
    required this.amountMinor,
    required this.postedAt,
    required this.merchant,
    this.cardLast4,
    this.currency = 'AED',
    this.linked = false,
    this.isDebit = true,
  });
  final String id;
  final int amountMinor;
  final DateTime postedAt;
  final String merchant;
  final String? cardLast4;
  final String currency;

  /// Already carries a receipt.
  final bool linked;
  final bool isDebit;
}

enum MatchKind { matched, ambiguous, none, alreadyLinked }

class MatchResult {
  const MatchResult(
    this.kind, {
    this.charge,
    this.score = 0,
    this.candidates = const [],
  });
  final MatchKind kind;
  final Charge? charge;
  final double score;
  final List<Charge> candidates;
}

const _aliases = {
  MerchantKind.noon: [
    'noon',
    'noon com',
    'noon food',
    'noon supermall',
    'noon minutes',
    'noon dubai',
  ],
  MerchantKind.talabat: [
    'talabat',
    'talabat mart',
    'talabat dubai',
    'talabat uae',
  ],
  MerchantKind.careem: [
    'careem',
    'careem food',
    'careem quik',
    'careem dubai',
    'careem now',
  ],
};

/// 0..100 for how much the bank's merchant text looks like the receipt's.
double merchantSimilarity(ParsedReceipt r, String chargeMerchant) {
  final c = normaliseName(chargeMerchant);
  if (c.isEmpty) return 0;
  var best = 0.0;
  final names = <String>[
    r.merchantName,
    ?r.venue,
    ..._aliases[r.kind] ?? const <String>[],
  ];
  for (final n in names) {
    final nn = normaliseName(n);
    if (nn.isEmpty) continue;
    final base = tokenSetRatio(nn, c);
    // "NOON.COM DUBAI AE" holds the brand as a whole token.
    final contains = RegExp('(^| )${RegExp.escape(nn)}( |\$)').hasMatch(c)
        ? 100.0
        : 0.0;
    final v = base > contains ? base : contains;
    if (v > best) best = v;
  }
  return best;
}

double _amountScore(ParsedReceipt r, int charge) {
  var best = 0.0;
  for (final a in r.chargeCandidates) {
    final d = charge - a;
    if (d.abs() <= amountToleranceMinor || d.abs() <= a * 0.005) {
      best = best > 1 ? best : 1;
    } else if (d > 0 && d <= a * tipVatAllowance) {
      // More than the receipt: tip, VAT or a fee not on it.
      best = best > 0.6 ? best : 0.6;
    }
  }
  return best;
}

double _dayDistance(DateTime a, DateTime b) {
  final x = DateTime(a.year, a.month, a.day),
      y = DateTime(b.year, b.month, b.day);
  return x.difference(y).inDays.abs().toDouble();
}

/// Scores one charge; null when it cannot be the one.
double? scoreCharge(ParsedReceipt r, Charge c) {
  if (!c.isDebit || c.currency != r.currency) return null;
  final days = _dayDistance(r.when, c.postedAt);
  if (days > matchWindowDays) return null;
  final sim = merchantSimilarity(r, c.merchant);
  if (sim < 60) return null;
  if (r.cardLast4 != null && c.cardLast4 != null && r.cardLast4 != c.cardLast4)
    return null;
  final cardBonus = (r.cardLast4 != null && c.cardLast4 == r.cardLast4)
      ? 0.15
      : 0.0;
  final dateScore = 1 - days * 0.15;
  if (r.hasAmount) {
    final a = _amountScore(r, c.amountMinor);
    if (a == 0) return null;
    return a * 0.5 + dateScore * 0.2 + (sim / 100) * 0.15 + cardBonus + 0.0;
  }
  // No amount in the email (restaurant "order accepted"): time and merchant
  // only, and only within the same day.
  if (days > 1) return null;
  return dateScore * 0.4 + (sim / 100) * 0.3 + cardBonus;
}

/// Picks the charge for [r] among [charges]. Never links two receipts to one
/// charge: linked charges are skipped, and a tie is reported as ambiguous.
MatchResult matchReceipt(ParsedReceipt r, List<Charge> charges) {
  if (r.stage != ReceiptStage.confirmed && r.stage != ReceiptStage.accepted) {
    return const MatchResult(MatchKind.none);
  }
  final scored = <(Charge, double)>[];
  var linkedFit = false;
  for (final c in charges) {
    final s = scoreCharge(r, c);
    if (s == null) continue;
    if (c.linked) {
      linkedFit = true;
      continue;
    }
    scored.add((c, s));
  }
  if (scored.isEmpty) {
    return MatchResult(linkedFit ? MatchKind.alreadyLinked : MatchKind.none);
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  final top = scored.first;
  final minScore = r.hasAmount ? 0.6 : 0.55;
  if (top.$2 < minScore) return const MatchResult(MatchKind.none);
  final tied = scored.where((s) => top.$2 - s.$2 < 0.08).toList();
  if (tied.length > 1) {
    // Two charges of the same size on the same day: the user decides.
    return MatchResult(
      MatchKind.ambiguous,
      score: top.$2,
      candidates: [for (final t in tied) t.$1],
    );
  }
  return MatchResult(
    MatchKind.matched,
    charge: top.$1,
    score: top.$2,
    candidates: [top.$1],
  );
}
