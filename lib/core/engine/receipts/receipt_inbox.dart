/// Unmatched receipts wait here, then are offered for review. Pure Dart.
///
/// A receipt is NEVER turned into spend by itself: only a bank or card
/// capture creates spend. Held receipts hold extracted fields only.
library;

import 'dart:convert';

import 'receipt_models.dart';

/// How long an unmatched receipt waits for its card charge to arrive.
const holdDays = 5;

class HeldReceipt {
  const HeldReceipt(
    this.receipt,
    this.firstSeen, {
    this.ambiguousWith = const [],
  });
  final ParsedReceipt receipt;
  final DateTime firstSeen;

  /// Charge ids it fit equally well (user picks).
  final List<String> ambiguousWith;

  bool dueForReview(DateTime now) =>
      now.difference(firstSeen).inDays >= holdDays;

  Map<String, Object?> toJson() => {
    'r': receipt.toJson(),
    'seen': firstSeen.toUtc().toIso8601String(),
    'amb': ambiguousWith,
  };
  static HeldReceipt fromJson(Map<String, Object?> j) => HeldReceipt(
    ParsedReceipt.fromJson(Map<String, Object?>.from(j['r'] as Map)),
    DateTime.parse(j['seen'] as String),
    ambiguousWith: [for (final x in (j['amb'] as List? ?? const [])) '$x'],
  );
}

/// What the app remembers between runs: held receipts and the message ids and
/// order ids already handled (so a re-scan never links twice).
class ReceiptInbox {
  ReceiptInbox({List<HeldReceipt>? held, Set<String>? done})
    : held = held ?? [],
      done = done ?? {};

  final List<HeldReceipt> held;
  final Set<String> done;

  /// Held receipts old enough to show the user, oldest first.
  List<HeldReceipt> dueForReview(DateTime now) =>
      [for (final h in held.where((h) => h.dueForReview(now))) h]
        ..sort((a, b) => a.firstSeen.compareTo(b.firstSeen));

  /// Still waiting (not yet due).
  List<HeldReceipt> waiting(DateTime now) => [
    for (final h in held)
      if (!h.dueForReview(now)) h,
  ];

  bool seen(ParsedReceipt r) =>
      done.contains('m:${r.messageId}') ||
      (r.orderId != null && done.contains('o:${r.orderId}:${r.stage.name}')) ||
      held.any((h) => h.receipt.messageId == r.messageId);

  void markDone(ParsedReceipt r) {
    done.add('m:${r.messageId}');
    if (r.orderId != null) done.add('o:${r.orderId}:${r.stage.name}');
    held.removeWhere((h) => h.receipt.messageId == r.messageId);
  }

  void hold(
    ParsedReceipt r,
    DateTime now, {
    List<String> ambiguousWith = const [],
  }) {
    held.removeWhere((h) => h.receipt.messageId == r.messageId);
    held.add(HeldReceipt(r, now, ambiguousWith: ambiguousWith));
  }

  /// Drops a receipt the user dismissed, remembering it so it is not re-held.
  void dismiss(String messageId) {
    final h = held.where((h) => h.receipt.messageId == messageId).firstOrNull;
    if (h != null) markDone(h.receipt);
    done.add('m:$messageId');
    held.removeWhere((h) => h.receipt.messageId == messageId);
  }

  String encode() => jsonEncode({
    'held': [for (final h in held) h.toJson()],
    'done': done.toList(),
  });

  static ReceiptInbox decode(String? raw) {
    if (raw == null || raw.isEmpty) return ReceiptInbox();
    try {
      final j = Map<String, Object?>.from(jsonDecode(raw) as Map);
      return ReceiptInbox(
        held: [
          for (final h in (j['held'] as List? ?? const []))
            HeldReceipt.fromJson(Map<String, Object?>.from(h as Map)),
        ],
        done: {for (final d in (j['done'] as List? ?? const [])) '$d'},
      );
    } catch (_) {
      return ReceiptInbox();
    }
  }
}
