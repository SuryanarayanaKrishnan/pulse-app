import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/types.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/goals.dart';
import 'package:pulse/data/api/api_exception.dart';
import 'package:pulse/data/goal_models.dart';
import 'package:pulse/data/local/goal_store.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/rules.dart';

final _now = DateTime.utc(2026, 3, 12, 8);
const _enbd = 'emirates-nbd-skywards-infinite';

class Rig {
  Rig(this.db, this.repo, this.pipeline);
  final PulseDatabase db;
  final LocalPulseRepository repo;
  final IngestPipeline pipeline;

  Future<IngestOutcome> sms(String text, {String sender = 'ENBD', String? id, DateTime? at}) => pipeline.ingest(
    IngestInput(channel: TxnSource.sms, rawText: text, sender: sender, receivedAt: at ?? DateTime.utc(2026, 3, 12, 9), externalId: id),
  );
}

Future<Rig> rig() async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = PulseDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final catalog = CatalogService(db: db, bundled: () async => File('assets/catalog/cards.json').readAsStringSync());
  await catalog.loadBundled();
  final pipeline = IngestPipeline(db, clock: () => _now);
  addTearDown(pipeline.dispose);
  return Rig(db, LocalPulseRepository(db: db, catalog: catalog, pipeline: pipeline, clock: () => _now), pipeline);
}

Future<Rig> withCard() async {
  final r = await rig();
  await r.repo.addBankAccount(bank: 'Emirates NBD', name: 'Current', kind: BankAccountKind.current, last4: '5678', balance: 10000);
  await r.repo.addCard(catalogId: _enbd, last4: '1234', limit: 20000, statementDay: 1, dueDay: 25);
  return r;
}

void main() {
  group('empty database', () {
    test('every read works and nothing is invented', () async {
      final r = await rig();
      final repo = r.repo;
      expect(await repo.transactions(), isEmpty);
      expect((await repo.transactionsPage()).items, isEmpty);
      expect(await repo.myCards(), isEmpty);
      expect(await repo.bankAccounts(), isEmpty);
      expect(await repo.assets(), isEmpty);
      expect(await repo.rules(), isEmpty);
      expect(await repo.splitGroups(), isEmpty);
      expect(await repo.statements(), isEmpty);
      expect((await repo.cardCatalog()).length, 14);
      expect((await repo.categories()).length, SpendCategory.defaults.length);
      final b = await repo.budgetOverview();
      expect(b.planned, 0);
      expect(b.spent, 0);
      expect(b.lines, isEmpty);
      expect(b.trend, hasLength(6));
      final nw = await repo.netWorth();
      expect(nw.total, 0);
      expect(nw.changePct, 0);
      final s = await repo.safeToSpend();
      expect(s.available, 0);
      expect((await repo.healthScore()).insufficient, isTrue);
      final cf = await repo.cashflow();
      expect(cf.balanceNow, 0);
      expect((await repo.household()).members.single.isYou, isTrue);
      expect(await repo.bestCard(SpendCategory.dining, 100), isEmpty);
    });

    test('server-only features say so instead of failing mysteriously', () async {
      final r = await rig();
      await expectLater(
        r.repo.startGmailConnect(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'not_supported')),
      );
      await expectLater(r.repo.simulateCapture(), throwsA(isA<ApiException>()));
    });
  });

  group('accounts, cards and wealth', () {
    test('adding a card puts it in the wallet with the catalog rules', () async {
      final r = await withCard();
      final cards = await r.repo.myCards();
      expect(cards, hasLength(1));
      final c = cards.single;
      expect((c.issuer, c.name, c.last4, c.limit), ('Emirates NBD', 'Skywards Infinite', '1234', 20000));
      expect(c.categoryRates[SpendCategory.dining], closeTo(2 * 0.0357 * 100, 0.001));
      expect(c.rulesVerifiedOn, isNull, reason: 'bundled figures are unverified');
      expect(c.dueDate.day, 25);
      final accounts = await r.repo.bankAccounts();
      expect(accounts.single.balance, 10000);
      expect(accounts.single.kind, BankAccountKind.current);
    });

    test('validates last four digits and the catalog id', () async {
      final r = await rig();
      await expectLater(r.repo.addCard(catalogId: _enbd, last4: '12'), throwsA(isA<ApiException>()));
      await expectLater(r.repo.addCard(catalogId: 'nope', last4: '1234'), throwsA(isA<ApiException>()));
    });

    test('net worth counts accounts, assets and card balances', () async {
      final r = await withCard();
      await r.repo.addAsset(name: 'Gold bars', kind: AssetKind.gold, value: 5000);
      await r.repo.addAsset(name: 'Car loan', kind: AssetKind.liability, value: 2000);
      await r.sms('Purchase of AED 300.00 with Credit Card ending 1234 at CARREFOUR, DUBAI.');
      final nw = await r.repo.netWorth();
      expect(nw.total, 10000 + 5000 - 2000 - 300);
      final list = await r.repo.assets();
      expect(list.where((a) => a.isLiability).length, 2);
    });

    test('removing a card keeps its transactions', () async {
      final r = await withCard();
      await r.sms('Purchase of AED 50.00 with Credit Card ending 1234 at CARREFOUR, DUBAI.');
      final id = (await r.repo.myCards()).single.id;
      await r.repo.removeCard(id);
      expect(await r.repo.myCards(), isEmpty);
      expect(await r.repo.transactions(), hasLength(1));
    });
  });

  group('ingest pipeline', () {
    test('an SMS becomes a categorised transaction and earns rewards', () async {
      final r = await withCard();
      final o = await r.sms('Purchase of AED 200.00 with Credit Card ending 1234 at TALABAT, DUBAI.');
      expect(o.status, IngestStatus.stored);
      final tx = (await r.repo.transactions()).single;
      expect(tx.amount, 200);
      expect(tx.merchant, 'Talabat');
      expect(tx.category, SpendCategory.dining);
      expect(tx.source, TxSource.sms);
      expect(tx.accountLabel, 'Emirates NBD ••1234');
      // 2 points per AED at AED 0.0357 per point.
      expect(o.reward!.earnedValueMinor, 1428);
      expect(o.reward!.cardTitle, 'Emirates NBD Skywards Infinite');
      final moment = await r.repo.momentFor(o);
      expect(moment!.earned, closeTo(14.28, 0.001));
      expect(moment.tx.id, tx.id);
      final card = (await r.repo.myCards()).single;
      expect(card.balance, 200);
      expect(card.rewardValueAed, closeTo(14.28, 0.001));
    });

    test('OTP messages are dropped and never stored', () async {
      final r = await withCard();
      final o = await r.sms('Your OTP is 123456. Do not share. Purchase of AED 45.00 card ending 1234');
      expect(o.status, IngestStatus.ignored);
      expect(o.reason, 'otp');
      expect(await r.db.select(r.db.rawIngests).get(), isEmpty);
      expect(await r.db.select(r.db.transactions).get(), isEmpty);
    });

    test('promotions are ignored and not kept', () async {
      final r = await withCard();
      final o = await r.sms('Dear customer, visit our branch for new offers.');
      expect(o.status, IngestStatus.ignored);
      expect(await r.db.select(r.db.rawIngests).get(), isEmpty);
    });

    test('the same message twice is one transaction', () async {
      final r = await withCard();
      const text = 'Purchase of AED 45.00 with Credit Card ending 1234 at CARREFOUR, DUBAI.';
      expect((await r.sms(text, id: 'm1')).status, IngestStatus.stored);
      expect((await r.sms(text, id: 'm1')).status, IngestStatus.duplicate);
      expect(await r.repo.transactions(), hasLength(1));
    });

    test('SMS and wallet tap for one purchase merge into one row', () async {
      final r = await withCard();
      await r.sms('Purchase of AED 45.00 with Credit Card ending 1234 at CARREFOUR, DUBAI.', id: 'sms1');
      final o = await r.pipeline.ingest(
        IngestInput(
          channel: TxnSource.googleWallet,
          externalId: 'tap1',
          receivedAt: DateTime.utc(2026, 3, 12, 9, 1),
          fields: IngestFields(amountMinor: 4500, merchant: 'Carrefour', last4: '1234', postedAt: DateTime.utc(2026, 3, 12, 9, 1)),
        ),
      );
      expect(o.status, IngestStatus.merged);
      final row = (await r.db.select(r.db.transactions).get()).single;
      expect(jsonDecode(row.sources), containsAll(['sms', 'google_wallet']));
    });

    test('two coffees on the same channel stay two transactions', () async {
      final r = await withCard();
      const t = 'Purchase of AED 12.00 with Credit Card ending 1234 at STARBUCKS, DUBAI.';
      await r.sms(t, id: 'a', at: DateTime.utc(2026, 3, 12, 9));
      await r.sms(t, id: 'b', at: DateTime.utc(2026, 3, 12, 9, 20));
      expect(await r.repo.transactions(), hasLength(2));
    });

    test('an unknown account waits for review, then lands when the card is added', () async {
      final r = await rig();
      final o = await r.sms('Purchase of AED 45.00 with Credit Card ending 1234 at CARREFOUR, DUBAI.');
      expect(o.status, IngestStatus.needsReview);
      expect(await r.repo.transactions(), isEmpty);
      expect((await r.db.select(r.db.rawIngests).get()).single.parseStatus, 'needs_review');
      final seen = <IngestOutcome>[];
      r.pipeline.results.listen(seen.add);
      await r.repo.addCard(catalogId: _enbd, last4: '1234');
      expect(await r.repo.transactions(), hasLength(1));
      expect((await r.db.select(r.db.rawIngests).get()).single.parseStatus, 'parsed');
      await Future<void>.delayed(Duration.zero);
      expect(seen, hasLength(1));
    });

    test('structured fields (iOS Shortcut) skip the parser', () async {
      final r = await withCard();
      final o = await r.pipeline.ingest(
        IngestInput(
          channel: TxnSource.appleShortcut,
          externalId: 'shortcut:1',
          fields: IngestFields(amountMinor: 8000, merchant: 'Spinneys', last4: '1234', postedAt: DateTime.utc(2026, 3, 12, 8)),
        ),
      );
      expect(o.status, IngestStatus.stored);
      final tx = (await r.repo.transactions()).single;
      expect((tx.source, tx.category, tx.amount), (TxSource.applePayShortcut, SpendCategory.groceries, 80));
    });

    test('salary credits are recorded', () async {
      final r = await withCard();
      await r.sms('ENBD: Salary credited AED 15,000.00 to your account ending 5678', id: 's1');
      final salary = await r.db.select(r.db.salaryRecords).get();
      expect(salary.single.amountMinor, 1500000);
      expect((await r.repo.transactions()).single.category, SpendCategory.salary);
    });

    test('a payload from the capture queue round-trips', () async {
      final r = await withCard();
      final input = IngestInput.fromPayload(TxnSource.sms, {
        'raw_text': 'Purchase of AED 45.00 with Credit Card ending 1234 at CARREFOUR, DUBAI.',
        'sender': 'ENBD',
        'received_at': '2026-03-12T09:00:00.000Z',
        'external_id': 'abc',
      });
      expect((await r.pipeline.ingest(input)).status, IngestStatus.stored);
      final stored = IngestInput.fromStored(jsonDecode(jsonEncode(input.toJson())) as Map<String, Object?>);
      expect(stored.externalId, 'abc');
      expect(stored.channel, TxnSource.sms);
    });
  });

  group('rules and categories', () {
    test('remembering a correction categorises the next capture', () async {
      final r = await withCard();
      await r.sms('Purchase of AED 45.00 with Credit Card ending 1234 at SOME CAFE LLC, DUBAI.', id: '1');
      final tx = (await r.repo.transactions()).single;
      await r.repo.recategorise(tx.id, SpendCategory.entertainment, remember: true);
      await r.sms('Purchase of AED 30.00 with Credit Card ending 1234 at SOME CAFE LLC, DUBAI.', id: '2', at: DateTime.utc(2026, 3, 12, 9, 30));
      final all = await r.repo.transactions();
      expect(all.map((t) => t.category), everyElement(SpendCategory.entertainment));
      expect(await r.repo.rules(), hasLength(1));
    });

    test('a saved rule applies retroactively and can be previewed first', () async {
      final r = await withCard();
      await r.sms('Purchase of AED 45.00 with Credit Card ending 1234 at CARREFOUR, DUBAI.', id: '1');
      await r.sms('Purchase of AED 99.00 with Credit Card ending 1234 at CARREFOUR, DUBAI.', id: '2', at: DateTime.utc(2026, 3, 11, 9));
      await r.sms('Purchase of AED 12.00 with Credit Card ending 1234 at STARBUCKS, DUBAI.', id: '3');
      const rule = AutomationRule(
        id: '',
        field: RuleField.merchant,
        op: RuleOperator.contains,
        value: 'carrefour',
        action: RuleAction.setCategory,
        category: SpendCategory.shopping,
      );
      final preview = await r.repo.previewRule(rule);
      expect((preview!.matched, preview.wouldChange), (2, 2));
      final saved = await r.repo.saveRule(rule);
      expect(saved.id, isNotEmpty);
      expect(saved.field, RuleField.merchant);
      final txs = await r.repo.transactions();
      expect(txs.where((t) => t.category == SpendCategory.shopping), hasLength(2));
      await r.repo.deleteRule(saved.id);
      expect(await r.repo.rules(), isEmpty);
    });

    test('amount and starts-with rules survive the round trip', () async {
      final r = await withCard();
      final a = await r.repo.saveRule(
        const AutomationRule(
          id: '', field: RuleField.amount, op: RuleOperator.greaterThan, value: '500.00',
          action: RuleAction.exclude,
        ),
      );
      expect((a.field, a.op, a.value), (RuleField.amount, RuleOperator.greaterThan, '500.00'));
      final b = await r.repo.saveRule(
        const AutomationRule(
          id: '', field: RuleField.merchant, op: RuleOperator.startsWith, value: 'noon',
          action: RuleAction.rename, renameTo: 'Noon',
        ),
      );
      expect((b.op, b.value, b.renameTo), (RuleOperator.startsWith, 'noon', 'Noon'));
    });

    test('custom categories appear in the picker', () async {
      final r = await rig();
      final c = await r.repo.createCategory(name: 'Pets');
      expect((await r.repo.categories()).map((x) => x.id), contains(c.id));
    });
  });

  group('ledger views', () {
    test('manual entries go to a cash account', () async {
      final r = await rig();
      final tx = await r.repo.addManualTransaction(merchant: 'Taxi', amount: 25, category: SpendCategory.transport);
      expect((tx.source, tx.accountLabel, tx.amount), (TxSource.manual, 'Cash', 25));
      final accounts = await r.repo.bankAccounts();
      expect(accounts.single.kind, BankAccountKind.cash);
      expect(accounts.single.balance, -25);
    });

    test('pagination walks the whole ledger newest first', () async {
      final r = await rig();
      for (var i = 0; i < 7; i++) {
        await r.repo.addManualTransaction(merchant: 'M$i', amount: 1.0 + i, category: SpendCategory.other);
      }
      final seen = <String>[];
      String? cursor;
      do {
        final page = await r.repo.transactionsPage(cursor: cursor, limit: 3);
        seen.addAll(page.items.map((t) => t.id));
        cursor = page.nextCursor;
      } while (cursor != null);
      expect(seen.toSet(), hasLength(7));
      expect(seen, hasLength(7));
    });

    test('budgets, spend and the month trend line up', () async {
      final r = await withCard();
      await r.sms('Purchase of AED 200.00 with Credit Card ending 1234 at TALABAT, DUBAI.', id: '1');
      await r.sms('Purchase of AED 100.00 with Credit Card ending 1234 at CARREFOUR, DUBAI.', id: '2');
      await r.repo.setBudget(SpendCategory.dining, 500);
      await r.repo.setBudget(SpendCategory.groceries, 400);
      final b = await r.repo.budgetOverview();
      expect((b.planned, b.spent, b.remaining), (900, 300, 600));
      expect(b.daysLeft, 20);
      final dining = b.lines.firstWhere((l) => l.category == SpendCategory.dining);
      expect((dining.planned, dining.spent), (500, 200));
      expect(b.trend.last.spent, 300);
      expect(b.byCard.values.single, 300);
      expect(b.topMerchants.first.merchant, 'Talabat');
      await r.repo.setBudget(SpendCategory.dining, 0);
      expect((await r.repo.budgetOverview()).lines.map((l) => l.category), [SpendCategory.groceries]);
    });

    test('safe to spend is limited by cash and by budget', () async {
      final r = await withCard();
      var s = await r.repo.safeToSpend();
      expect(s.available, 10000, reason: 'no budget: cash only');
      expect(s.daysLeft, 20);
      await r.repo.setBudget(SpendCategory.dining, 1000);
      s = await r.repo.safeToSpend();
      expect(s.available, 1000);
      expect(s.today, 50);
    });

    test('goals reserve their monthly amount, show per goal, and pausing gives it back', () async {
      final r = await withCard();
      final store = LocalGoalStore(r.db);
      await store.saveGoal(GoalRecord(
        id: 'g1', name: 'Trip to Japan', kind: GoalKind.save, targetMinor: 2000000, monthlyMinor: 150000,
        createdAt: _now,
      ));
      await store.saveGoal(GoalRecord(
        id: 'g2', name: 'Clear the card', kind: GoalKind.paydown, targetMinor: 0, startMinor: 90000, monthlyMinor: 50000,
        createdAt: _now,
      ));
      var s = await r.repo.safeToSpend();
      expect(s.goals, 2000, reason: '1,500 + 500');
      expect(s.available, 8000);
      expect([for (final g in s.goalLines) (g.name, g.amount)], [('Trip to Japan', 1500.0), ('Clear the card', 500.0)]);

      await store.saveGoal((await store.goals()).first.copyWith(paused: true));
      s = await r.repo.safeToSpend();
      expect(s.goals, 500);
      expect(s.available, 9500);

      // money already put in this month is no longer waiting in cash
      await store.saveContribution(GoalContribution(id: 'c', goalId: 'g2', amountMinor: 20000, date: const CalDate(2026, 3, 11)));
      s = await r.repo.safeToSpend();
      expect(s.goals, 300);
    });

    test('cashflow and category trends see captured spend', () async {
      final r = await withCard();
      await r.sms('Purchase of AED 200.00 with Credit Card ending 1234 at TALABAT, DUBAI.');
      await r.sms('ENBD: Salary credited AED 15,000.00 to your account ending 5678', id: 'sal');
      final cf = await r.repo.cashflow();
      expect(cf.months.last.spend, 200);
      expect(cf.months.last.income, 15000);
      final trends = await r.repo.categoryTrends();
      expect(trends.series.first.category, SpendCategory.dining);
      expect(trends.series.first.values.last, 200);
    });

    test('best card ranks owned cards by what they earn', () async {
      final r = await withCard();
      await r.repo.addCard(catalogId: 'first-abu-dhabi-bank-cashback-card', last4: '9999');
      final picks = await r.repo.bestCard(SpendCategory.dining, 100);
      expect(picks, hasLength(2));
      expect(picks.first.estimate, greaterThanOrEqualTo(picks.last.estimate));
      expect(picks.first.verified, isFalse);
    });

    test('a health score appears once there is history', () async {
      final r = await withCard();
      await r.sms('Purchase of AED 200.00 with Credit Card ending 1234 at TALABAT, DUBAI.');
      final h = await r.repo.healthScore();
      expect(h.insufficient, isFalse);
      expect(h.score, inInclusiveRange(0, 100));
    });
  });

  group('demo capture', () {
    test('simulateCapture runs the real pipeline and emits an outcome', () async {
      final r = await withCard();
      final seen = <IngestOutcome>[];
      r.pipeline.results.listen(seen.add);
      final tx = await r.repo.simulateCapture();
      await Future<void>.delayed(Duration.zero);
      expect(tx.amount, greaterThan(0));
      expect(seen, hasLength(1));
      expect(seen.single.transactionId, tx.id);
      expect(seen.single.reward, isNotNull);
    });
  });
}
