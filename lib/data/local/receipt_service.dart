import 'package:drift/drift.dart';

import '../../core/analytics/analytics.dart';
import '../../core/engine/receipts/receipt_category.dart';
import '../../core/engine/receipts/receipt_inbox.dart';
import '../../core/engine/receipts/receipt_matcher.dart';
import '../../core/engine/receipts/receipt_models.dart';
import '../../core/engine/receipts/receipt_parsers.dart';
import '../../core/engine/receipts/receipt_source.dart';
import 'database.dart';

class ReceiptScanResult {
  const ReceiptScanResult({
    this.matched = 0,
    this.held = 0,
    this.ignored = 0,
    this.skipped = false,
  });
  final int matched, held, ignored;

  /// The source is not configured, so nothing was read.
  final bool skipped;
}

/// Links receipt emails to card charges already on this phone and enriches
/// them. It never creates a transaction: a receipt with no charge waits, and
/// after [holdDays] is offered for review. Email bodies are parsed and
/// dropped; only extracted fields are kept (held receipts in `app_settings`,
/// which never syncs; link and notes on the transaction row).
class ReceiptService {
  ReceiptService({
    required this.db,
    required this.source,
    required this.analytics,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final PulseDatabase db;
  final ReceiptSource source;
  final Analytics analytics;
  final DateTime Function() _now;

  static const inboxKey = 'receipts.inbox';
  static const lookbackDays = 14;

  Future<ReceiptInbox> _load() async =>
      ReceiptInbox.decode(await db.setting(inboxKey));
  Future<void> _save(ReceiptInbox i) => db.putSetting(inboxKey, i.encode());

  /// Receipts that waited long enough for a charge and still have none.
  Future<List<HeldReceipt>> dueForReview() async =>
      (await _load()).dueForReview(_now());

  Future<int> waitingCount() async => (await _load()).waiting(_now()).length;

  Future<void> dismiss(String messageId) async {
    final i = await _load();
    i.dismiss(messageId);
    await _save(i);
  }

  Future<List<Charge>> _charges(DateTime from) async {
    final accounts = {
      for (final a in await db.select(db.accounts).get()) a.id: a.last4,
    };
    final rows =
        await (db.select(db.transactions)..where(
              (t) =>
                  t.deletedAt.isNull() & t.postedAt.isBiggerOrEqualValue(from),
            ))
            .get();
    return [
      for (final t in rows)
        Charge(
          id: t.id,
          amountMinor: t.amountMinor,
          postedAt: t.postedAt.toLocal(),
          merchant: t.merchantNormalized ?? t.merchantRaw ?? '',
          cardLast4: accounts[t.accountId],
          currency: t.currency,
          linked: t.receiptRef != null,
          isDebit: t.direction == 'debit',
        ),
    ];
  }

  /// Reads new receipts, links what matches, holds the rest.
  Future<ReceiptScanResult> scan() async {
    if (!source.isConfigured) return const ReceiptScanResult(skipped: true);
    final now = _now();
    final since = now.subtract(const Duration(days: lookbackDays));
    final inbox = await _load();
    final messages = await source.fetch(since: since);
    final incoming = <ParsedReceipt>[];
    var ignored = 0;
    for (final m in messages) {
      final r = parseReceipt(m);
      if (inbox.seen(r)) continue;
      if (r.stage != ReceiptStage.confirmed &&
          r.stage != ReceiptStage.accepted) {
        inbox.markDone(r);
        ignored++;
        continue;
      }
      // The same order can arrive twice (resend): the first one wins.
      if (r.orderId != null &&
          incoming.any((x) => x.orderId == r.orderId && x.stage == r.stage)) {
        inbox.markDone(r);
        ignored++;
        continue;
      }
      incoming.add(r);
    }
    // Held receipts get another try: their charge may have posted since.
    final retry = [for (final h in inbox.held) h.receipt];
    var matched = 0, held = 0;
    final charges = await _charges(
      since.subtract(const Duration(days: matchWindowDays)),
    );
    for (final r in [...retry, ...incoming]) {
      final res = matchReceipt(r, charges);
      switch (res.kind) {
        case MatchKind.matched:
          if (await _apply(res.charge!.id, r)) {
            matched++;
            inbox.markDone(r);
            final i = charges.indexWhere((c) => c.id == res.charge!.id);
            final c = charges[i];
            charges[i] = Charge(
              id: c.id,
              amountMinor: c.amountMinor,
              postedAt: c.postedAt,
              merchant: c.merchant,
              cardLast4: c.cardLast4,
              currency: c.currency,
              linked: true,
            );
            analytics.track(AnalyticsEvent.receiptMatched(r.kind.name));
          }
        case MatchKind.alreadyLinked:
          // Its charge already has a receipt: nothing to add, never twice.
          inbox.markDone(r);
        case MatchKind.ambiguous:
          if (!inbox.held.any((h) => h.receipt.messageId == r.messageId))
            held++;
          inbox.hold(
            r,
            _heldSince(inbox, r, now),
            ambiguousWith: [for (final c in res.candidates) c.id],
          );
        case MatchKind.none:
          if (!inbox.held.any((h) => h.receipt.messageId == r.messageId))
            held++;
          inbox.hold(r, _heldSince(inbox, r, now));
      }
    }
    await _save(inbox);
    return ReceiptScanResult(matched: matched, held: held, ignored: ignored);
  }

  DateTime _heldSince(ReceiptInbox i, ParsedReceipt r, DateTime now) =>
      i.held
          .where((h) => h.receipt.messageId == r.messageId)
          .firstOrNull
          ?.firstSeen ??
      now;

  /// The user picked the charge for a held receipt.
  Future<bool> linkManually(String messageId, String txId) async {
    final inbox = await _load();
    final h = inbox.held
        .where((h) => h.receipt.messageId == messageId)
        .firstOrNull;
    if (h == null) return false;
    final ok = await _apply(txId, h.receipt);
    if (ok) {
      inbox.markDone(h.receipt);
      await _save(inbox);
      analytics.track(AnalyticsEvent.receiptMatched(h.receipt.kind.name));
    }
    return ok;
  }

  /// Adds the receipt's link, notes and (for unreviewed rows) a better
  /// category. Amount, date, merchant and direction are never touched.
  Future<bool> _apply(String txId, ParsedReceipt r) async {
    final row = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(txId))).getSingleOrNull();
    if (row == null || row.receiptRef != null) return false;
    final notes = receiptNotes(r);
    String? catId;
    final slug = categoryFromReceipt(r);
    if (slug != null && !row.reviewed && row.categoryId != slug) {
      final c = await (db.select(
        db.categories,
      )..where((t) => t.id.equals(slug))).getSingleOrNull();
      catId = c?.id;
    }
    await (db.update(db.transactions)..where((t) => t.id.equals(txId))).write(
      TransactionsCompanion(
        receiptRef: Value(r.messageId),
        receiptNotes: Value(notes.isEmpty ? null : notes),
        categoryId: catId == null ? const Value.absent() : Value(catId),
      ),
    );
    return true;
  }
}
