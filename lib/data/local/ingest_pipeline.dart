import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../../core/engine/card_value.dart';
import '../../core/engine/dates.dart';
import '../../core/engine/dedupe.dart';
import '../../core/engine/holds.dart';
import '../../core/engine/institutions.dart';
import '../digit_suggestion.dart';
import '../../core/engine/merchants.dart';
import '../../core/learning/global_merchant_map.dart';
import '../../core/engine/rewards.dart';
import '../../core/engine/rule_engine.dart';
import '../../core/engine/salary.dart';
import '../../core/engine/sms_parser.dart';
import '../../core/engine/types.dart';
import 'card_cycles.dart';
import 'database.dart';
import 'ids.dart';

/// Structured fields supplied by a capture that already knows them (the iOS
/// Shortcut, a wallet notification parsed natively).
class IngestFields {
  const IngestFields({
    required this.amountMinor,
    this.currency = 'AED',
    this.direction = 'debit',
    this.merchant,
    this.last4,
    this.postedAt,
  });
  final int amountMinor;
  final String currency, direction;
  final String? merchant, last4;
  final DateTime? postedAt;

  Map<String, Object?> toJson() => {
    'amount_minor': amountMinor,
    'currency': currency,
    'direction': direction,
    if (merchant != null) 'merchant': merchant,
    if (last4 != null) 'last4': last4,
    if (postedAt != null) 'posted_at': postedAt!.toUtc().toIso8601String(),
  };

  static IngestFields? fromJson(Object? j) {
    if (j is! Map) return null;
    final amount = (j['amount_minor'] as num?)?.toInt();
    if (amount == null || amount <= 0) return null;
    return IngestFields(
      amountMinor: amount,
      currency: ((j['currency'] as String?) ?? 'AED').toUpperCase(),
      direction: j['direction'] == 'credit' ? 'credit' : 'debit',
      merchant: j['merchant'] as String?,
      last4: j['last4'] as String?,
      postedAt: j['posted_at'] == null ? null : DateTime.tryParse('${j['posted_at']}'),
    );
  }
}

/// One captured message, as the capture layer hands it over (the same shape
/// the ingest queue stores).
class IngestInput {
  const IngestInput({
    required this.channel,
    this.rawText,
    this.sender,
    this.institution,
    this.receivedAt,
    this.externalId,
    this.appName,
    this.title,
    this.fields,
  });

  final TxnSource channel;
  final String? rawText, sender, institution, externalId, appName, title;
  final DateTime? receivedAt;
  final IngestFields? fields;

  /// From a queue payload (`IngestRequestDto.toJson`). Notifications from a
  /// known wallet app are filed under that wallet.
  factory IngestInput.fromPayload(TxnSource channel, Map<String, Object?> p) {
    final app = (p['app_name'] as String?)?.toLowerCase() ?? '';
    var ch = channel;
    if (ch == TxnSource.notification) {
      if (app.contains('samsung')) {
        ch = TxnSource.samsungWallet;
      } else if (app.contains('google') || app.contains('wallet') || app.contains('gms')) {
        ch = TxnSource.googleWallet;
      }
    }
    return IngestInput(
      channel: ch,
      rawText: p['raw_text'] as String?,
      sender: p['sender'] as String?,
      institution: p['institution'] as String?,
      receivedAt: p['received_at'] == null ? null : DateTime.tryParse('${p['received_at']}'),
      externalId: p['external_id'] as String?,
      appName: p['app_name'] as String?,
      title: p['title'] as String?,
      fields: IngestFields.fromJson(p['fields']),
    );
  }

  Map<String, Object?> toJson() => {
    'channel': channel.wire,
    if (rawText != null) 'raw_text': rawText,
    if (sender != null) 'sender': sender,
    if (institution != null) 'institution': institution,
    if (receivedAt != null) 'received_at': receivedAt!.toUtc().toIso8601String(),
    if (externalId != null) 'external_id': externalId,
    if (appName != null) 'app_name': appName,
    if (title != null) 'title': title,
    if (fields != null) 'fields': fields!.toJson(),
  };

  static IngestInput fromStored(Map<String, Object?> j) =>
      IngestInput.fromPayload(TxnSource.tryParse(j['channel'] as String?) ?? TxnSource.sms, j);
}

enum IngestStatus {
  /// A new transaction was stored.
  stored,

  /// The purchase was already known (statement or another channel); sources merged.
  merged,

  /// The same message was seen before.
  duplicate,

  /// Parsed, but no account matches it yet. Kept for [IngestPipeline.reprocessPending].
  needsReview,

  /// Not a transaction (OTP, promotion, unknown format). Nothing is stored.
  ignored,

  /// A merchant's pre-authorisation notice (hold, settlement or release) was
  /// applied to a held transaction, or remembered for the bank's own alert.
  holdUpdated,
}

/// What the card earned for a captured purchase.
class RewardOutcome {
  const RewardOutcome({
    required this.accountId,
    required this.cardTitle,
    required this.earnedValueMinor,
    required this.ratePct,
    required this.rule,
    this.capLimitAed,
    this.capUsedAed,
    this.nudge,
    this.suggestedAccountId,
    this.check,
  });
  final String accountId, cardTitle;
  final int earnedValueMinor;
  final double ratePct;
  final String? rule;

  /// Cap of the rule that applied, in AED of reward, and what is used after
  /// this purchase. Null when uncapped.
  final double? capLimitAed, capUsedAed;
  final String? nudge, suggestedAccountId;

  /// Right/wrong card result for this payment; null when there is nothing
  /// to compare (a single card, nothing earnable).
  final CardCheck? check;
}

class IngestOutcome {
  const IngestOutcome(this.status, {this.transactionId, this.reward, this.reason});
  final IngestStatus status;
  final String? transactionId;
  final RewardOutcome? reward;
  final String? reason;

  bool get isNew => status == IngestStatus.stored;

  @override
  String toString() => 'IngestOutcome($status${reason == null ? '' : ', $reason'})';
}

/// The on-device ingest pipeline: parse, de-duplicate, resolve the account,
/// categorise, store and work out what the card earned. Mirrors the
/// backend's `process_raw_ingest`, with every step running on the phone.
class IngestPipeline {
  IngestPipeline(this.db, {ParserRegistry? registry, DateTime Function()? clock, this.globalMap})
    : registry = registry ?? defaultParserRegistry,
      _clock = clock ?? DateTime.now;

  final PulseDatabase db;

  /// Default categories for common merchants; used after the user's rules and
  /// the built-in dictionary.
  final GlobalMerchantMap? globalMap;
  final ParserRegistry registry;
  final DateTime Function() _clock;
  final _results = StreamController<IngestOutcome>.broadcast();

  /// Every outcome that produced a new transaction, for the reward banner.
  Stream<IngestOutcome> get results => _results.stream;

  Future<void> dispose() => _results.close();

  /// Runs one message through the pipeline. Never throws for bad input.
  Future<IngestOutcome> ingest(IngestInput input) async {
    final text = input.rawText ?? '';
    // OTP messages are dropped before anything is parsed, hashed or stored.
    if (input.fields == null && (isOtpMessage(text) || isOtpMessage(input.title ?? ''))) {
      return const IngestOutcome(IngestStatus.ignored, reason: 'otp');
    }
    await voidExpiredHolds();
    final notice = input.fields == null
        ? parseHoldNotice(text, sender: input.sender, subject: input.title)
        : null;
    final parsed = notice == null ? _parse(input) : null;
    if (notice == null && parsed == null) {
      return const IngestOutcome(IngestStatus.ignored, reason: 'not_a_transaction');
    }
    final hash = computeExternalHash(
      input.channel,
      externalId: input.externalId,
      sender: input.sender,
      rawText: text,
      fieldsJson: input.fields == null ? null : jsonEncode(input.fields!.toJson()),
      receivedAt: input.receivedAt,
    );
    final seen = await (db.select(db.rawIngests)..where((r) => r.externalHash.equals(hash))).getSingleOrNull();
    if (seen != null) {
      return IngestOutcome(IngestStatus.duplicate, transactionId: seen.transactionId);
    }
    final rawId = newId();
    await db.into(db.rawIngests).insert(
      RawIngestsCompanion.insert(
        id: rawId,
        channel: input.channel.wire,
        externalHash: hash,
        payload: jsonEncode(input.toJson()),
        parseStatus: const Value('pending'),
      ),
    );
    if (notice != null) {
      final txId = await applyHoldNotice(notice, at: input.receivedAt ?? _clock());
      await _markRaw(rawId, 'parsed', txId: txId);
      return IngestOutcome(IngestStatus.holdUpdated, transactionId: txId, reason: notice.kind.name);
    }
    final outcome = await _process(rawId, input, parsed!, text);
    if (outcome.isNew) _results.add(outcome);
    return outcome;
  }

  // ---- pre-authorisation holds -------------------------------------------

  static const _noticesKey = 'holds.notices';

  Future<List<Map<String, Object?>>> _notices() async {
    final raw = await db.setting(_noticesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return [for (final e in jsonDecode(raw) as List) Map<String, Object?>.from(e as Map)];
    } on Object {
      return [];
    }
  }

  Future<void> _saveNotice(HoldNotice n, DateTime at) async {
    final cutoff = _clock().subtract(holdExpiry * 2);
    final kept = [
      for (final e in await _notices())
        if (DateTime.tryParse('${e['at']}')?.isAfter(cutoff) ?? false) e,
      {
        'kind': n.kind.name,
        'merchant': n.merchant,
        'hold': n.holdMinor,
        'final': n.finalMinor,
        'at': at.toUtc().toIso8601String(),
      },
    ];
    await db.putSetting(_noticesKey, jsonEncode(kept));
  }

  /// True when a settlement or release notice already closed a hold of this
  /// size at this merchant, so a late bank alert for the hold is not spend.
  Future<bool> _holdAlreadyClosed(String? merchant, int amountMinor) async {
    final cutoff = _clock().subtract(holdExpiry);
    for (final e in await _notices()) {
      if (e['kind'] == HoldNoticeKind.hold.name || e['hold'] != amountMinor) continue;
      if ((DateTime.tryParse('${e['at']}') ?? cutoff).isBefore(cutoff)) continue;
      if (sameHoldMerchant('${e['merchant']}', merchant)) return true;
    }
    return false;
  }

  bool _hasTag(TxRow t, String tag) => (jsonDecode(t.tags) as List).contains(tag);

  Future<void> _settle(TxRow hold, int finalMinor, {String? channel}) async {
    final tags = [for (final x in jsonDecode(hold.tags) as List) '$x']..remove(holdTag);
    final sources = {...[for (final x in jsonDecode(hold.sources) as List) '$x'], ?channel}.toList();
    await (db.update(db.transactions)..where((t) => t.id.equals(hold.id))).write(
      TransactionsCompanion(
        amountMinor: Value(finalMinor),
        excludeFromBudget: const Value(false),
        tags: Value(jsonEncode(tags)),
        sources: Value(jsonEncode(sources)),
      ),
    );
  }

  Future<void> _void(TxRow t) => (db.update(db.transactions)..where((x) => x.id.equals(t.id))).write(
    TransactionsCompanion(deletedAt: Value(_clock().toUtc())),
  );

  /// Applies a merchant's hold / settlement / release email. Returns the id of
  /// the transaction it changed, if any. Notices are also remembered so the
  /// bank's own alert, which may arrive before or after, is read correctly.
  Future<String?> applyHoldNotice(HoldNotice n, {DateTime? at}) async {
    final now = at ?? _clock();
    await _saveNotice(n, now);
    final day = const Duration(days: 1);
    final recent = await (db.select(db.transactions)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.direction.equals('debit') &
                t.postedAt.isBetweenValues(now.subtract(holdExpiry), now.add(day)),
          ))
        .get();
    final sameShop = [for (final t in recent) if (sameHoldMerchant(n.merchant, t.merchantNormalized ?? t.merchantRaw)) t];
    final holds = [for (final t in sameShop) if (_hasTag(t, holdTag)) t];
    // The row for the blocked amount, held or not yet recognised as a hold.
    TxRow? blocked;
    for (final t in sameShop) {
      if (t.amountMinor == n.holdMinor && (blocked == null || t.postedAt.isAfter(blocked.postedAt))) blocked = t;
    }
    switch (n.kind) {
      case HoldNoticeKind.hold:
        if (blocked != null && !_hasTag(blocked, holdTag)) {
          final tags = [for (final x in jsonDecode(blocked.tags) as List) '$x', holdTag];
          await (db.update(db.transactions)..where((t) => t.id.equals(blocked!.id))).write(
            TransactionsCompanion(tags: Value(jsonEncode(tags)), excludeFromBudget: const Value(true)),
          );
        }
        return blocked?.id;
      case HoldNoticeKind.settlement:
        final fin = n.finalMinor!;
        // The real charge may already be a row of its own (its bank alert came first).
        final real = [for (final t in sameShop) if (t.amountMinor == fin && !_hasTag(t, holdTag)) t];
        if (blocked != null && real.isNotEmpty) {
          await _void(blocked); // the hold row is redundant: the charge is already there
          return real.first.id;
        }
        if (blocked != null) {
          await _settle(blocked, fin);
          return blocked.id;
        }
        return real.isEmpty ? null : real.first.id;
      case HoldNoticeKind.release:
        for (final h in holds.where((h) => h.amountMinor == n.holdMinor)) {
          await _void(h);
        }
        return null;
    }
  }

  /// Holds the bank never settled are released by the bank: stop counting them.
  Future<int> voidExpiredHolds() async {
    final cutoff = _clock().subtract(holdExpiry);
    final rows = await (db.select(db.transactions)
          ..where((t) => t.deletedAt.isNull() & t.postedAt.isSmallerThanValue(cutoff)))
        .get();
    var n = 0;
    for (final t in rows) {
      if (_hasTag(t, holdTag)) {
        await _void(t);
        n++;
      }
    }
    return n;
  }

  /// Retries messages that had no matching account (after the user added a
  /// card or account). Returns how many became transactions.
  Future<int> reprocessPending() async {
    final rows = await (db.select(db.rawIngests)
          ..where((r) => r.parseStatus.equals('needs_review'))
          ..orderBy([(r) => OrderingTerm.asc(r.createdAt)]))
        .get();
    var made = 0;
    for (final r in rows) {
      try {
        final input = IngestInput.fromStored(Map<String, Object?>.from(jsonDecode(r.payload) as Map));
        final parsed = _parse(input);
        if (parsed == null) continue;
        final o = await _process(r.id, input, parsed, input.rawText ?? '');
        if (o.isNew) {
          made++;
          _results.add(o);
        }
      } on Object catch (e) {
        debugPrint('Reprocess failed for ${r.id}: $e');
      }
    }
    return made;
  }

  /// Waiting alerts whose card digits match no account, grouped by digits and
  /// bank, with the digit-less accounts at that bank that could own them.
  Future<List<DigitSuggestion>> digitSuggestions() async {
    final rows = await (db.select(db.rawIngests)..where((r) => r.parseStatus.equals('needs_review'))).get();
    if (rows.isEmpty) return const [];
    final accounts = await (db.select(db.accounts)..where((a) => a.deletedAt.isNull())).get();
    final known = {for (final a in accounts) if (a.last4 != null) a.last4!};
    final waiting = <String, int>{};
    final inst = <String, String>{};
    for (final r in rows) {
      try {
        final input = IngestInput.fromStored(Map<String, Object?>.from(jsonDecode(r.payload) as Map));
        final p = _parse(input);
        final last4 = p?.last4;
        final bank = p?.institution;
        if (p == null || last4 == null || bank == null || known.contains(last4)) continue;
        final k = '$last4|${institutions.resolveKey(bank) ?? normName(bank)}';
        waiting[k] = (waiting[k] ?? 0) + 1;
        inst[k] = bank;
      } on Object {
        continue;
      }
    }
    final out = <DigitSuggestion>[];
    for (final e in waiting.entries) {
      final last4 = e.key.split('|').first;
      final key = e.key.split('|').last;
      final cands = [
        for (final a in accounts)
          if (a.last4 == null &&
              a.institution != null &&
              (institutions.resolveKey(a.institution!) ?? normName(a.institution!)) == key)
            (id: a.id, label: '${a.institution} ${a.name}'.trim()),
      ];
      if (cands.isEmpty) continue;
      out.add(DigitSuggestion(last4: last4, institution: inst[e.key]!, candidates: cands, waiting: e.value));
    }
    out.sort((a, b) => b.waiting.compareTo(a.waiting));
    return out;
  }

  ParsedTransaction? _parse(IngestInput input) {
    final f = input.fields;
    if (f != null) {
      return ParsedTransaction(
        amountMinor: f.amountMinor,
        currency: f.currency,
        direction: f.direction == 'credit' ? Direction.credit : Direction.debit,
        merchantRaw: f.merchant,
        last4: f.last4,
        postedAt: f.postedAt ?? input.receivedAt,
        institution: input.institution,
        confidence: 1,
      );
    }
    final text = input.rawText ?? '';
    ParsedTransaction? p = registry.parse(
      text,
      institution: input.institution,
      sender: input.sender,
      receivedAt: input.receivedAt,
    );
    if (p == null && (input.title ?? '').isNotEmpty) {
      p = registry.parse(
        '${input.title}. $text',
        institution: input.institution,
        sender: input.sender,
        receivedAt: input.receivedAt,
      );
    }
    return p;
  }

  AccountRow? _resolveAccount(List<AccountRow> all, ParsedTransaction p) {
    final key = p.institution == null ? null : (institutions.resolveKey(p.institution!) ?? p.institution);
    bool sameInstitution(AccountRow a) {
      if (key == null) return true;
      final name = a.institution;
      if (name == null) return false;
      return (institutions.resolveKey(name) ?? normName(name)) == key || normName(name) == normName(key);
    }

    if (p.last4 != null) {
      var cands = [for (final a in all) if (a.last4 == p.last4) a];
      if (cands.length > 1) {
        final narrowed = cands.where(sameInstitution).toList();
        if (narrowed.isNotEmpty) cands = narrowed;
      }
      return cands.length == 1 ? cands.first : null;
    }
    if (key != null) {
      final cands = all.where(sameInstitution).toList();
      return cands.length == 1 ? cands.first : null;
    }
    return null;
  }

  Future<void> _markRaw(String rawId, String status, {String? txId, String? error}) =>
      (db.update(db.rawIngests)..where((r) => r.id.equals(rawId))).write(
        RawIngestsCompanion(
          parseStatus: Value(status),
          transactionId: Value(txId),
          error: Value(error),
        ),
      );

  Future<IngestOutcome> _process(String rawId, IngestInput input, ParsedTransaction p, String text) async {
    final accounts = await (db.select(db.accounts)..where((a) => a.deletedAt.isNull())).get();
    final account = _resolveAccount(accounts, p);
    if (account == null) {
      await _markRaw(rawId, 'needs_review', error: 'no_matching_account');
      return const IngestOutcome(IngestStatus.needsReview, reason: 'no_matching_account');
    }
    final postedAt = (p.postedAt ?? input.receivedAt ?? _clock()).toUtc();
    final direction = p.direction;
    final channel = input.channel;

    // Is it a purchase we already know?
    final window = postedAt.subtract(const Duration(days: 4));
    final windowEnd = postedAt.add(const Duration(days: 4));
    final nearby = await (db.select(db.transactions)
          ..where(
            (t) =>
                t.accountId.equals(account.id) &
                t.deletedAt.isNull() &
                t.postedAt.isBetweenValues(window, windowEnd),
          ))
        .get();
    final claimed = {
      for (final r in await (db.select(db.rawIngests)..where((x) => x.transactionId.isNotNull())).get())
        r.transactionId!,
    };
    final stored = [
      for (final t in nearby)
        StoredTxn(
          id: t.id,
          accountId: t.accountId,
          amountMinor: t.amountMinor,
          currency: t.currency,
          direction: Direction.tryParse(t.direction) ?? Direction.debit,
          postedAt: t.postedAt,
          source: TxnSource.tryParse(t.source) ?? TxnSource.manual,
          sources: [for (final s in (jsonDecode(t.sources) as List)) '$s'],
          merchantRaw: t.merchantRaw,
          merchantNormalized: t.merchantNormalized,
          claimedByMessage: claimed.contains(t.id),
        ),
    ];
    // Pre-authorisation holds: a smaller charge settles an open hold; a round
    // amount at a pre-authorising merchant is itself a hold, not spend.
    var asHold = false;
    if (direction == Direction.debit) {
      final open = [
        for (final t in nearby)
          if (t.deletedAt == null &&
              _hasTag(t, holdTag) &&
              t.direction == 'debit' &&
              sameHoldMerchant(p.merchantRaw, t.merchantNormalized ?? t.merchantRaw) &&
              t.amountMinor > p.amountMinor &&
              postedAt.difference(t.postedAt).abs() <= settleWindow)
            t,
      ];
      if (open.isNotEmpty) {
        open.sort((a, b) => b.postedAt.compareTo(a.postedAt));
        await _settle(open.first, p.amountMinor, channel: channel.wire);
        await _markRaw(rawId, 'parsed', txId: open.first.id);
        return IngestOutcome(IngestStatus.merged, transactionId: open.first.id, reason: 'hold_settled');
      }
      if (looksLikeHold(p.merchantRaw, p.amountMinor, direction)) {
        if (await _holdAlreadyClosed(p.merchantRaw, p.amountMinor)) {
          await _markRaw(rawId, 'parsed');
          return const IngestOutcome(IngestStatus.ignored, reason: 'hold_already_released');
        }
        asHold = true;
      }
    }
    final dupe =
        findStatementTransaction(
          stored,
          accountId: account.id,
          amountMinor: p.amountMinor,
          currency: p.currency,
          direction: direction,
          merchant: p.merchantRaw,
          postedAt: postedAt,
        ) ??
        findCaptureDuplicate(
          stored,
          accountId: account.id,
          channel: channel,
          amountMinor: p.amountMinor,
          currency: p.currency,
          direction: direction,
          merchant: p.merchantRaw,
          postedAt: postedAt,
        );
    if (dupe != null) {
      final sources = {...(dupe.sources.isEmpty ? [dupe.source.wire] : dupe.sources), channel.wire}.toList();
      await (db.update(db.transactions)..where((t) => t.id.equals(dupe.id))).write(
        TransactionsCompanion(sources: Value(jsonEncode(sources))),
      );
      await _markRaw(rawId, 'parsed', txId: dupe.id);
      return IngestOutcome(IngestStatus.merged, transactionId: dupe.id);
    }

    // Categorise: the user's rules first, then the merchant dictionary, then
    // the global merchant map.
    final enrichment = await _resolver().then(
      (r) => r.enrich(
        p.merchantRaw,
        direction,
        accountId: account.id,
        amountMinor: p.amountMinor,
        source: channel,
        notes: null,
      ),
    );
    var categoryId = enrichment.categoryId;
    final salary = detectSalary(p.merchantRaw, direction, p.amountMinor, text);
    if (salary != null && categoryId == null) categoryId = 'salary';

    final txId = newId();
    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        id: txId,
        accountId: account.id,
        amountMinor: p.amountMinor,
        currency: Value(p.currency),
        direction: direction.name,
        categoryId: Value(categoryId),
        merchantRaw: Value(p.merchantRaw),
        merchantNormalized: Value(enrichment.merchantNormalized),
        postedAt: postedAt,
        source: channel.wire,
        externalHash: const Value.absent(),
        excludeFromBudget: Value(enrichment.excludeFromBudget || asHold),
        tags: Value(jsonEncode([...enrichment.tags, if (asHold) holdTag])),
        sources: Value(jsonEncode([channel.wire])),
        appliedRuleId: Value(enrichment.ruleId),
      ),
    );
    if (salary != null) {
      await db.into(db.salaryRecords).insertOnConflictUpdate(
        SalaryRecordsCompanion.insert(
          id: newId(),
          accountId: Value(account.id),
          employer: Value(salary.employer),
          amountMinor: p.amountMinor,
          currency: Value(p.currency),
          receivedOn: toDubaiDate(postedAt).toIso(),
          transactionId: Value(txId),
          matchedBy: Value(salary.matchedBy),
        ),
      );
    }
    await _markRaw(rawId, 'parsed', txId: txId);

    RewardOutcome? reward;
    if (!asHold && direction == Direction.debit && p.currency == 'AED' && account.type == 'credit_card') {
      try {
        reward = await _reward(account, txId, categoryId, enrichment.merchantNormalized ?? p.merchantRaw, p.amountMinor, postedAt);
      } on Object catch (e) {
        debugPrint('Reward calculation failed: $e');
      }
    }
    return IngestOutcome(IngestStatus.stored, transactionId: txId, reward: reward);
  }

  Future<CategoryResolver> _resolver() async {
    final rows = await (db.select(db.merchantRules)..where((r) => r.isActive.equals(true))).get();
    final compiled = <CompiledRule>[];
    for (final r in rows) {
      try {
        compiled.add(compileStoredRule(r));
      } on Object {
        continue; // A rule that no longer compiles must not block capture.
      }
    }
    final cats = await db.select(db.categories).get();
    final system = {
      for (final c in cats)
        if (c.slug != null) c.slug!: c.id,
    };
    return CategoryResolver(compiled, system, globalMap: globalMap);
  }

  Future<RewardOutcome?> _reward(
    AccountRow account,
    String txId,
    String? categoryId,
    String? merchant,
    int amountMinor,
    DateTime postedAt,
  ) async {
    final cards = await loadOwnedCards(db);
    final card = cards.where((c) => c.account.id == account.id).firstOrNull;
    if (card == null) return null;
    final today = toDubaiDate(postedAt);
    final slug = rewardSlug(categoryId);
    final key = merchantKey(merchant);
    final before = await cycleState(db, card, today, excludeTxId: txId);
    final q = quote(card.spec, before, Spend(amountMinor, slug, key));
    final after = await cycleState(db, card, today);
    final all = await rankables(db, cards, today);
    final self = all.firstWhere((r) => r.id == card.account.id);
    final nudge = nudgeFor(
      card: self,
      all: all,
      cycleEnd: cycleBounds(today, account.statementDay).$2,
      category: slug,
      merchantKey: key,
    );
    final rule = selectRule(card.spec, slug, key);
    double? capLimit, capUsed;
    if (rule?.capUnits != null) {
      capLimit = rule!.capUnits! * card.spec.pointValueAed;
      capUsed = (after.usage[rule.name]?.usedUnits ?? 0) * card.spec.pointValueAed;
    }
    return RewardOutcome(
      accountId: account.id,
      cardTitle: card.title,
      earnedValueMinor: q.valueMinor,
      ratePct: amountMinor == 0 ? 0 : q.valueMinor / amountMinor * 100,
      rule: q.rule,
      capLimitAed: capLimit,
      capUsedAed: capUsed,
      nudge: nudge?.message,
      suggestedAccountId: nudge?.suggestedCardId,
      check: checkCard(
        paidCardId: account.id,
        before: await rankablesFor(db, cards, today, excludeTxId: txId),
        spend: Spend(amountMinor, slug, key),
        unverifiedCardIds: {for (final c in cards) if (c.catalog.verifiedOn == null) c.account.id},
      ),
    );
  }
}

/// Compiles a stored rule row for the engine.
CompiledRule compileStoredRule(RuleRow r) {
  final conditions = [
    for (final c in (jsonDecode(r.conditions) as List)) Map<String, Object?>.from(c as Map),
  ];
  return compileRule(
    conditions,
    id: r.id,
    priority: r.priority,
    categoryId: r.categoryId,
    renameMerchant: r.renameMerchant,
    markTransfer: r.markTransfer,
    excludeFromBudget: r.excludeFromBudget,
    tags: [for (final t in (jsonDecode(r.tags) as List)) '$t'],
  );
}
