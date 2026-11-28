/// Cross-source dedupe: one purchase, one row, however many channels saw it
/// (SMS, wallet notification, Apple Pay shortcut, statement line).
///
/// Port of `statements/matching.py`, `find_capture_duplicate` and
/// `find_statement_transaction` (pulse-api). Pure Dart.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'dates.dart';
import 'fuzzy.dart';
import 'merchants.dart';
import 'types.dart';

const dateWindowDays = 3;
const minMerchantScore = 60;

/// A lone same-amount candidate one day away is accepted on weaker merchant
/// evidence.
const weakScore = 30;

/// A tap and its SMS arrive within minutes of each other.
const captureWindow = Duration(minutes: 60);

/// 0-100 similarity of two merchant descriptors; null when either is empty.
int? merchantScore(String? a, String? b) {
  if (a == null || a.isEmpty || b == null || b.isEmpty) return null;
  final ea = matchEntry(a), eb = matchEntry(b);
  if (ea != null && identical(ea, eb)) return 100;
  final ca = cleanDescriptor(a).toLowerCase();
  final cb = cleanDescriptor(b).toLowerCase();
  if (ca.isEmpty || cb.isEmpty) return null;
  final s = tokenSetRatio(ca, cb);
  final p = partialRatio(ca, cb) * 0.9;
  return (s > p ? s : p).truncate();
}

class StatementLine {
  const StatementLine({
    required this.postedOn,
    required this.description,
    required this.amountMinor,
    required this.currency,
    required this.direction,
    this.foreignAmountMinor,
    this.foreignCurrency,
  });
  final CalDate postedOn;
  final String description;
  final int amountMinor;
  final String currency;
  final Direction direction;
  final int? foreignAmountMinor;
  final String? foreignCurrency;
}

class TxnLike {
  const TxnLike({
    required this.postedAt,
    required this.amountMinor,
    required this.currency,
    required this.direction,
    this.merchantRaw,
    this.merchantNormalized,
  });
  final DateTime postedAt;
  final int amountMinor;
  final String currency;
  final Direction direction;
  final String? merchantRaw;
  final String? merchantNormalized;
}

class LineMatch {
  const LineMatch(this.lineIndex, this.txnIndex, this.score);
  final int lineIndex, txnIndex, score;
}

bool amountsEqual(StatementLine line, TxnLike txn) {
  if (txn.amountMinor == line.amountMinor && txn.currency == line.currency) {
    return true;
  }
  return line.foreignAmountMinor != null &&
      txn.amountMinor == line.foreignAmountMinor &&
      txn.currency == line.foreignCurrency;
}

/// Matches statement lines to captured transactions. Same direction, same
/// amount (account or foreign currency), within [dateWindowDays] days and a
/// similar merchant; greedy by best score so each transaction is claimed by
/// at most one line.
List<LineMatch> matchLines(List<StatementLine> lines, List<TxnLike> txns) {
  final pairs = <(int, int, int, int)>[]; // (-score, gap, line, txn)
  for (var li = 0; li < lines.length; li++) {
    final line = lines[li];
    final feasible = <(int, int, int?)>[];
    for (var ti = 0; ti < txns.length; ti++) {
      final txn = txns[ti];
      if (txn.direction != line.direction || !amountsEqual(line, txn)) continue;
      final gap = toDubaiDate(txn.postedAt).daysSince(line.postedOn).abs();
      if (gap > dateWindowDays) continue;
      final score = merchantScore(
        txn.merchantNormalized ?? txn.merchantRaw,
        line.description,
      );
      feasible.add((ti, gap, score));
    }
    for (final (ti, gap, score) in feasible) {
      int accepted;
      if (score != null && score >= minMerchantScore) {
        accepted = score;
      } else if (feasible.length == 1 &&
          gap <= 1 &&
          (score == null || score >= weakScore)) {
        accepted = score ?? 40;
      } else {
        continue;
      }
      pairs.add((-accepted, gap, li, ti));
    }
  }
  pairs.sort((a, b) {
    for (final c in [
      a.$1.compareTo(b.$1),
      a.$2.compareTo(b.$2),
      a.$3.compareTo(b.$3),
      a.$4.compareTo(b.$4),
    ]) {
      if (c != 0) return c;
    }
    return 0;
  });
  final usedLines = <int>{}, usedTxns = <int>{};
  final out = <LineMatch>[];
  for (final (negScore, _, li, ti) in pairs) {
    if (usedLines.contains(li) || usedTxns.contains(ti)) continue;
    usedLines.add(li);
    usedTxns.add(ti);
    out.add(LineMatch(li, ti, -negScore));
  }
  out.sort((a, b) => a.lineIndex.compareTo(b.lineIndex));
  return out;
}

/// An already-stored transaction considered by the capture dedupe.
class StoredTxn {
  const StoredTxn({
    required this.id,
    required this.accountId,
    required this.amountMinor,
    required this.currency,
    required this.direction,
    required this.postedAt,
    required this.source,
    this.sources = const [],
    this.merchantRaw,
    this.merchantNormalized,
    this.claimedByMessage = false,
  });
  final String id;
  final String accountId;
  final int amountMinor;
  final String currency;
  final Direction direction;
  final DateTime postedAt;
  final TxnSource source;

  /// Every channel that already saw this purchase.
  final List<String> sources;
  final String? merchantRaw;
  final String? merchantNormalized;

  /// A message already maps to this (statement) row.
  final bool claimedByMessage;
}

/// A late SMS / tap for a purchase a statement already produced: same
/// account, amount, direction, within +-[dateWindowDays] days and a similar
/// merchant. Statement rows only.
StoredTxn? findStatementTransaction(
  Iterable<StoredTxn> stored, {
  required String accountId,
  required int amountMinor,
  required String currency,
  required Direction direction,
  required String? merchant,
  required DateTime postedAt,
}) {
  final day = toDubaiDate(postedAt);
  StoredTxn? best;
  var bestScore = -1;
  for (final t in stored) {
    if (t.source != TxnSource.statement ||
        t.accountId != accountId ||
        t.amountMinor != amountMinor ||
        t.currency != currency ||
        t.direction != direction ||
        t.claimedByMessage) {
      continue;
    }
    if (toDubaiDate(t.postedAt).daysSince(day).abs() > dateWindowDays) continue;
    final score = merchantScore(
      merchant,
      t.merchantNormalized ?? t.merchantRaw,
    );
    final acceptable =
        (score != null && score >= minMerchantScore) ||
        (score == null && merchant == null);
    if (acceptable && (best == null || (score ?? 0) > bestScore)) {
      best = t;
      bestScore = score ?? 0;
    }
  }
  return best;
}

/// The same purchase already captured through a *different* channel (SMS vs
/// wallet tap...). Deliberately tight: same account, amount, direction, within
/// an hour, merchant compatible. Two real coffees at the same price must stay
/// two transactions, so a second capture on the same channel never merges.
StoredTxn? findCaptureDuplicate(
  Iterable<StoredTxn> stored, {
  required String accountId,
  required TxnSource channel,
  required int amountMinor,
  required String currency,
  required Direction direction,
  required String? merchant,
  required DateTime postedAt,
  Duration window = captureWindow,
}) {
  StoredTxn? best;
  var bestScore = -1;
  for (final t in stored) {
    if (t.source == TxnSource.statement ||
        t.accountId != accountId ||
        t.amountMinor != amountMinor ||
        t.currency != currency ||
        t.direction != direction) {
      continue;
    }
    if (t.postedAt.difference(postedAt).abs() > window) continue;
    final seen = t.sources.isEmpty ? [t.source.wire] : t.sources;
    if (seen.contains(channel.wire)) continue;
    final score = merchantScore(
      merchant,
      t.merchantNormalized ?? t.merchantRaw,
    );
    if (score != null && score < minMerchantScore) continue;
    if (best == null || (score ?? 0) > bestScore) {
      best = t;
      bestScore = score ?? 0;
    }
  }
  return best;
}

final _ws = RegExp(r'\s+');

/// Stable dedupe key of a raw message. A client-provided [externalId] wins;
/// otherwise the content (sender, text, structured fields, timestamp) is
/// hashed, so two genuinely identical messages at different times stay
/// distinct. There is a single local user, so no user id is mixed in.
String computeExternalHash(
  TxnSource channel, {
  String? externalId,
  String? sender,
  String? rawText,
  String? fieldsJson,
  DateTime? receivedAt,
}) {
  final String basis;
  if (externalId != null && externalId.isNotEmpty) {
    basis = 'id:$externalId';
  } else {
    final text = (rawText ?? '').trim().replaceAll(_ws, ' ').toLowerCase();
    final ts = receivedAt?.toUtc().toIso8601String() ?? '';
    basis = '${sender ?? ''}|$text|${fieldsJson ?? ''}|$ts';
  }
  return sha256.convert(utf8.encode('${channel.wire}|$basis')).toString();
}
