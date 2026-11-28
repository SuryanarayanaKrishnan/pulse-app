import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/own_transfers.dart';
import 'package:pulse/core/engine/types.dart' show TxnSource;
import 'package:pulse/data/local/card_cycles.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ids.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';
import 'package:pulse/data/local/own_transfers_store.dart';

/// Paying your own card is not spending. The Tabby purchase was captured when
/// it happened; the SIB line that repays it must not count a second time, but
/// it still earns SIB's cashback.
void main() {
  final now = DateTime.utc(2026, 11, 28, 8);
  late PulseDatabase db;
  late IngestPipeline pipeline;
  late LocalPulseRepository repo;
  late String sibId, tabbyId, mashreqId, mashreqCardId;

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = PulseDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = CatalogService(
      db: db,
      bundled: () async => File('assets/catalog/cards.json').readAsStringSync(),
    );
    await catalog.loadBundled();
    pipeline = IngestPipeline(db, clock: () => now);
    addTearDown(pipeline.dispose);
    repo = LocalPulseRepository(
      db: db,
      catalog: catalog,
      pipeline: pipeline,
      clock: () => now,
    );
    sibId = (await repo.addCard(
      catalogId: 'sib-cashback',
      last4: '1111',
      limit: 20000,
    )).id;
    tabbyId = (await repo.addCard(
      catalogId: 'tabby-card',
      last4: '',
      limit: 5000,
    )).id;
    mashreqId = newId();
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: mashreqId,
            type: 'bank',
            name: 'Mashreq Current',
            institution: const Value('Mashreq'),
            last4: const Value('9876'),
          ),
        );
    mashreqCardId = newId();
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: mashreqCardId,
            type: 'credit_card',
            name: 'Mashreq Cashback',
            institution: const Value('Mashreq'),
            last4: const Value('4455'),
          ),
        );
  });

  var n = 0;
  Future<IngestOutcome> line(
    int minor,
    String merchant, {
    required String? last4,
    String direction = 'debit',
    String? institution,
    Duration after = Duration.zero,
    String? text,
  }) => pipeline.ingest(
    IngestInput(
      channel: TxnSource.sms,
      externalId: 'o${n++}',
      receivedAt: now.add(after),
      institution: institution,
      rawText: text,
      fields: IngestFields(
        amountMinor: minor,
        merchant: merchant,
        last4: last4,
        direction: direction,
        postedAt: now.add(after),
      ),
    ),
  );

  Future<List<TxRow>> live() =>
      (db.select(db.transactions)..where((t) => t.deletedAt.isNull())).get();
  List<String> tagsOf(TxRow t) => [
    for (final x in jsonDecode(t.tags) as List) '$x',
  ];
  Future<TxRow> byId(String id) =>
      (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();

  test(
    'Tabby repaid from SIB: not spending, kept for cashback, asks once',
    () async {
      final o = await line(50000, 'TABBY', last4: '1111');
      expect(o.status, IngestStatus.stored);
      expect(o.reason, 'own_transfer');
      final t = (await live()).single;
      expect(t.excludeFromBudget, isTrue);
      expect(t.categoryId, 'cc_payment');
      expect(t.reviewed, isFalse);
      expect(
        tagsOf(t),
        containsAll([ownTransferTag, cardBillTag, rewardableTag]),
      );
      // It still counts for SIB's cashback as what it was captured as.
      expect(rewardCategoryId(t), 'shopping');
      // The repayment earned SIB's online rate (10%) on the card.
      expect(o.reward, isNotNull);
      expect(o.reward!.earnedValueMinor, 5000);
    },
  );

  test(
    'the Tabby side of the repayment pairs with it and rides along',
    () async {
      await line(50000, 'TABBY', last4: '1111');
      final credit = await line(
        50000,
        'Tabby card payment',
        last4: null,
        institution: 'tabby',
        direction: 'credit',
        after: const Duration(hours: 1),
      );
      expect(credit.status, IngestStatus.stored);
      final rows = await live();
      final sib = rows.firstWhere((r) => r.accountId == sibId);
      final tabby = rows.firstWhere((r) => r.accountId == tabbyId);
      expect(tagsOf(sib), contains('$linkTagPrefix${tabby.id}'));
      expect(tagsOf(tabby), contains('$linkTagPrefix${sib.id}'));
      expect(tabby.categoryId, 'cc_payment');
      // One question for the pair: the paying side asks, the receiving rides.
      expect(sib.reviewed, isFalse);
      expect(tabby.reviewed, isTrue);
    },
  );

  test('the receiving side arriving first still pairs', () async {
    await line(
      50000,
      'Tabby card payment',
      last4: null,
      institution: 'tabby',
      direction: 'credit',
    );
    await line(50000, 'TABBY', last4: '1111', after: const Duration(hours: 1));
    final rows = await live();
    final sib = rows.firstWhere((r) => r.accountId == sibId);
    final tabby = rows.firstWhere((r) => r.accountId == tabbyId);
    expect(tagsOf(sib), contains('$linkTagPrefix${tabby.id}'));
    expect(tagsOf(tabby), contains('$linkTagPrefix${sib.id}'));
    expect(sib.reviewed, isFalse);
    expect(tabby.reviewed, isTrue);
  });

  test(
    'a Mashreq account paying a Mashreq card: both legs out of spending',
    () async {
      await line(
        150000,
        'CREDIT CARD PAYMENT',
        last4: '9876',
        text:
            'AED 1,500 debited from your account for credit card payment 4455',
      );
      await line(
        150000,
        'PAYMENT RECEIVED',
        last4: '4455',
        direction: 'credit',
        after: const Duration(minutes: 10),
      );
      final rows = await live();
      expect(rows, hasLength(2));
      for (final r in rows) {
        expect(r.excludeFromBudget, isTrue);
        expect(r.categoryId, 'cc_payment');
        expect(tagsOf(r), contains(ownTransferTag));
      }
      final debit = rows.firstWhere((r) => r.accountId == mashreqId);
      // Paid from a bank account: not a wallet payment, no cashback.
      expect(tagsOf(debit), isNot(contains(rewardableTag)));
      expect(debit.reviewed, isFalse);
    },
  );

  test('between own accounts, wording alone is enough and it asks', () async {
    await line(500000, 'IPI TRANSFER OWN ACCOUNT', last4: '9876');
    final t = (await live()).single;
    expect(tagsOf(t), contains(ownAccountTag));
    expect(t.categoryId, 'transfer');
    expect(t.excludeFromBudget, isTrue);
    expect(t.reviewed, isFalse);
  });

  test('ordinary spending and a coincidental amount are untouched', () async {
    await line(50000, 'CARREFOUR', last4: '1111');
    // Same amount credited on another account, nothing says transfer.
    await line(
      50000,
      'NOON REFUND',
      last4: '9876',
      direction: 'credit',
      after: const Duration(hours: 1),
    );
    for (final r in await live()) {
      expect(tagsOf(r), isNot(contains(ownTransferTag)));
      expect(r.excludeFromBudget, isFalse);
    }
  });

  test('a Tabby card purchase at a shop is spending, not a transfer', () async {
    final o = await pipeline.ingest(
      IngestInput(
        channel: TxnSource.notification,
        externalId: 'tb1',
        receivedAt: now,
        rawText: 'Transaction of AED 5.00 At CAFE was successful. Your available Tabby Card limit is AED 2,623.84.',
      ),
    );
    expect(o.status, IngestStatus.stored);
    final t = (await live()).single;
    expect(tagsOf(t), isNot(contains(ownTransferTag)));
    expect(t.excludeFromBudget, isFalse);
  });

  test('confirming one leg confirms both', () async {
    await line(50000, 'TABBY', last4: '1111');
    await line(
      50000,
      'Tabby card payment',
      last4: null,
      institution: 'tabby',
      direction: 'credit',
      after: const Duration(hours: 1),
    );
    final sib = (await live()).firstWhere((r) => r.accountId == sibId);
    await repo.resolveTransfer(sib.id, isTransfer: true);
    for (final r in await live()) {
      expect(r.reviewed, isTrue);
      expect(r.excludeFromBudget, isTrue);
    }
  });

  test('"not a transfer" puts both legs back as captured', () async {
    await line(50000, 'TABBY', last4: '1111');
    await line(
      50000,
      'Tabby card payment',
      last4: null,
      institution: 'tabby',
      direction: 'credit',
      after: const Duration(hours: 1),
    );
    final before = (await live()).firstWhere((r) => r.accountId == sibId);
    await repo.resolveTransfer(before.id, isTransfer: false);
    final sib = await byId(before.id);
    expect(sib.categoryId, 'shopping');
    expect(sib.excludeFromBudget, isFalse);
    expect(sib.reviewed, isTrue);
    expect(
      tagsOf(sib).where(
        (t) =>
            t == ownTransferTag ||
            t == rewardableTag ||
            t.startsWith(linkTagPrefix) ||
            t.startsWith(origCategoryTagPrefix),
      ),
      isEmpty,
    );
    final tabby = (await live()).firstWhere((r) => r.accountId == tabbyId);
    expect(tagsOf(tabby), isNot(contains(ownTransferTag)));
    expect(tabby.excludeFromBudget, isFalse);
  });

  test('the SIB cap still counts the Tabby repayment', () async {
    await line(50000, 'TABBY', last4: '1111');
    final cards = await loadOwnedCards(db);
    final sib = cards.firstWhere((c) => c.account.id == sibId);
    final c = await cycleSpends(db, sib, toDubaiDate(now));
    expect(c.spends, hasLength(1));
    expect(c.spends.single.category, 'shopping');
    expect(c.spends.single.amountMinor, 50000);
  });

  test(
    'the transaction reaches the app marked as a transfer and first in line',
    () async {
      await line(50000, 'TABBY', last4: '1111');
      final tx = (await repo.transactions()).single;
      expect(tx.isOwnTransfer, isTrue);
      expect(tx.transferKind, 'card_bill');
      expect(tx.excluded, isTrue);
      expect(tx.confidence, lessThan(0.5));
    },
  );
}
