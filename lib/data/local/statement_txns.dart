import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../../core/engine/dates.dart';
import '../../core/engine/dedupe.dart' as dd;
import '../../core/engine/institutions.dart';
import '../../core/engine/salary.dart';
import '../../core/engine/statement_parser.dart';
import '../../core/engine/types.dart';
import 'database.dart';
import 'ids.dart';
import 'ingest_pipeline.dart';
import 'own_transfers_store.dart';

/// What importing a statement's lines did.
class StatementTxnResult {
  const StatementTxnResult({
    this.created = 0,
    this.merged = 0,
    this.skipped = 0,
    this.accountId,
  });

  /// Lines no other source had seen: new transactions.
  final int created;

  /// Lines a captured transaction already covered: that row gained the
  /// "statement" source and is now locked to the bank's numbers.
  final int merged;

  /// Lines imported by an earlier statement (overlapping periods, re-reads).
  final int skipped;

  /// The account the statement belongs to; null when none could be told, in
  /// which case nothing was imported.
  final String? accountId;

  bool get imported => accountId != null;
  int get total => created + merged + skipped;
}

/// The user's account a statement belongs to: by the card's last four, else
/// by bank and kind when exactly one account fits. Null when it is unclear.
Future<AccountRow?> resolveStatementAccount(
  PulseDatabase db,
  ParsedStatement parsed,
  String? institution,
) async {
  final accts = await (db.select(
    db.accounts,
  )..where((a) => a.deletedAt.isNull())).get();
  String key(String? s) =>
      s == null ? '' : (institutions.resolveKey(s) ?? normName(s));
  final bank = key(institution ?? parsed.institution);
  bool sameBank(AccountRow a) => bank.isEmpty || key(a.institution) == bank;
  final wantType = parsed.kind == StatementKind.creditCard
      ? 'credit_card'
      : null;

  if (parsed.last4 != null) {
    var c = accts.where((a) => a.last4 == parsed.last4).toList();
    if (c.length > 1) {
      final narrowed = c.where(sameBank).toList();
      if (narrowed.isNotEmpty) c = narrowed;
    }
    if (c.length == 1) return c.first;
  }
  final c = [
    for (final a in accts)
      if (sameBank(a) &&
          (wantType != null
              ? a.type == wantType
              : (a.type == 'bank' || a.type == 'wallet')))
        a,
  ];
  return c.length == 1 ? c.first : null;
}

/// Turns a parsed statement's lines into transactions, one row per purchase
/// however many sources saw it:
///
///  * a line a captured transaction (SMS, wallet tap, Shortcut) already covers
///    is merged into that row, which gains the `statement` source and is locked
///    to the bank's figures;
///  * a line nothing has seen becomes a new `statement` row, categorised like
///    any capture, and a later SMS or tap for it merges into that row (see
///    `findStatementTransaction`);
///  * a line imported before (an overlapping statement, a re-read) is skipped.
///
/// Card bill payments and own-account transfers go through the same detection
/// as live capture, so they pair with the other leg and stay out of spending.
Future<StatementTxnResult> importStatementTransactions(
  PulseDatabase db,
  IngestPipeline pipeline, {
  required String statementId,
  required ParsedStatement parsed,
  String? institution,
}) async {
  final account = await resolveStatementAccount(db, parsed, institution);
  if (account == null || parsed.lines.isEmpty) {
    return const StatementTxnResult();
  }
  await (db.update(db.statements)..where((s) => s.id.equals(statementId)))
      .write(StatementsCompanion(accountId: Value(account.id)));

  // Each line's stable key: the same line in an overlapping statement, or the
  // same statement read twice, is the same key. Identical lines on one day
  // (two coffees) are told apart by their order.
  final seen = <String, int>{};
  final keys = <String>[];
  for (final l in parsed.lines) {
    final base =
        'stmt|${account.id}|${l.postedOn.toIso()}|${l.direction.name}|'
        '${l.amountMinor}|${normName(l.description)}';
    final n = seen.update(base, (v) => v + 1, ifAbsent: () => 0);
    keys.add(sha256.convert(utf8.encode('$base|$n')).toString());
  }
  final done = {
    for (final r in await (db.select(
      db.rawIngests,
    )..where((r) => r.externalHash.isIn(keys))).get())
      r.externalHash,
  };

  final fresh = <int>[
    for (var i = 0; i < parsed.lines.length; i++)
      if (!done.contains(keys[i])) i,
  ];
  if (fresh.isEmpty) {
    return StatementTxnResult(
      skipped: parsed.lines.length,
      accountId: account.id,
    );
  }
  final lines = [for (final i in fresh) parsed.lines[i]];

  // Captured rows on this account the statement might cover.
  final first = lines
      .map((l) => l.postedOn)
      .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
  final last = lines
      .map((l) => l.postedOn)
      .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
  final candidates = [
    for (final t
        in await (db.select(db.transactions)..where(
              (t) =>
                  t.accountId.equals(account.id) &
                  t.deletedAt.isNull() &
                  t.statementLocked.equals(false) &
                  t.postedAt.isBetweenValues(
                    atDate(first.addDays(-dd.dateWindowDays - 1)),
                    atDate(last.addDays(dd.dateWindowDays + 1)),
                  ),
            ))
            .get())
      if (t.source != 'statement') t,
  ];
  final matches = dd.matchLines(
    [
      for (final l in lines)
        dd.StatementLine(
          postedOn: l.postedOn,
          description: l.description,
          amountMinor: l.amountMinor,
          currency: parsed.currency,
          direction: l.direction,
          foreignAmountMinor: l.foreignAmountMinor,
          foreignCurrency: l.foreignCurrency,
        ),
    ],
    [
      for (final t in candidates)
        dd.TxnLike(
          postedAt: t.postedAt,
          amountMinor: t.amountMinor,
          currency: t.currency,
          direction: Direction.tryParse(t.direction) ?? Direction.debit,
          merchantRaw: t.merchantRaw,
          merchantNormalized: t.merchantNormalized,
        ),
    ],
  );
  final matchOf = {
    for (final m in matches) m.lineIndex: candidates[m.txnIndex],
  };

  final resolver = await pipeline.categoryResolver();
  final cats = await db.select(db.categories).get();
  final systemId = {
    for (final c in cats)
      if (c.slug != null) c.slug!: c.id,
  };
  var created = 0, merged = 0;
  final newIds = <String, String>{}; // tx id -> line description

  await db.transaction(() async {
    for (var n = 0; n < fresh.length; n++) {
      final i = fresh[n];
      final l = lines[n];
      final m = matchOf[n];
      String txId;
      if (m != null) {
        final sources = {
          ...[for (final s in jsonDecode(m.sources) as List) '$s'],
          if ((jsonDecode(m.sources) as List).isEmpty) m.source,
          'statement',
        }.toList();
        await (db.update(
          db.transactions,
        )..where((t) => t.id.equals(m.id))).write(
          TransactionsCompanion(
            sources: Value(jsonEncode(sources)),
            statementId: Value(statementId),
            statementLocked: const Value(true),
          ),
        );
        txId = m.id;
        merged++;
      } else {
        final direction = l.direction;
        final enr = resolver.enrich(
          l.description,
          direction,
          accountId: account.id,
          amountMinor: l.amountMinor,
          source: TxnSource.statement,
          notes: null,
        );
        var categoryId = enr.categoryId;
        if (categoryId == null &&
            detectSalary(
                  l.description,
                  direction,
                  l.amountMinor,
                  l.description,
                ) !=
                null) {
          categoryId = systemId['salary'] ?? 'salary';
        }
        txId = newId();
        await db
            .into(db.transactions)
            .insert(
              TransactionsCompanion.insert(
                id: txId,
                accountId: account.id,
                statementId: Value(statementId),
                amountMinor: l.amountMinor,
                currency: Value(parsed.currency),
                direction: direction.name,
                categoryId: Value(categoryId),
                merchantRaw: Value(l.description),
                merchantNormalized: Value(enr.merchantNormalized),
                postedAt: atDate(l.postedOn),
                source: TxnSource.statement.wire,
                externalHash: const Value.absent(),
                excludeFromBudget: Value(enr.excludeFromBudget),
                tags: Value(jsonEncode(enr.tags)),
                sources: Value(jsonEncode([TxnSource.statement.wire])),
                statementLocked: const Value(true),
                appliedRuleId: Value(enr.ruleId),
                // The bank's own line is right about the amount; the category is
                // still a guess when nothing recognised the merchant.
                reviewed: Value(categoryId != null && categoryId != 'other'),
              ),
            );
        newIds[txId] = l.description;
        created++;
      }
      await db
          .into(db.rawIngests)
          .insert(
            RawIngestsCompanion.insert(
              id: newId(),
              channel: TxnSource.statement.wire,
              externalHash: keys[i],
              // Not `transactionId`: that column means "a live message maps to
              // this row", which would stop a later SMS from merging into it.
              payload: jsonEncode({
                'statement_id': statementId,
                'line': i,
                'transaction_id': txId,
              }),
              parseStatus: const Value('parsed'),
            ),
          );
    }
  });

  // Same detection as live capture: card bill payments and own transfers stay
  // out of spending, pair with the other leg and wait for one tap.
  for (final e in newIds.entries) {
    await detectOwnTransfer(db, e.key, text: e.value);
  }
  return StatementTxnResult(
    created: created,
    merged: merged,
    skipped: parsed.lines.length - fresh.length,
    accountId: account.id,
  );
}
