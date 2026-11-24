import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/household/household_models.dart';
import 'package:pulse/core/household/household_scope.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/household_store.dart';
import 'package:pulse/data/models.dart';

import '../backup/support.dart' show memoryDb;

void main() {
  late PulseDatabase db;
  late LocalHouseholdStore store;
  final now = DateTime.utc(2026, 11, 24);

  setUp(() async {
    db = memoryDb();
    store = LocalHouseholdStore(
      db,
      clock: () => now,
      wealth: () async => const [
        Asset(id: 'account:a1', name: 'Salary', kind: AssetKind.cash, value: 12000),
        Asset(id: 'as1', name: 'Gold coins', kind: AssetKind.gold, value: 5000),
        Asset(id: 'l1', name: 'Car loan', kind: AssetKind.liability, value: 4000),
        Asset(id: 'jewel:1', name: 'Necklace', kind: AssetKind.gold, value: 9000),
      ],
      goals: () async => const [],
    );
    await db.into(db.accounts).insert(AccountsCompanion.insert(id: 'a1', type: 'bank', name: 'Salary'));
    await db.into(db.assets).insert(AssetsCompanion.insert(id: 'as1', kind: 'gold', name: 'Gold coins'));
    await db.into(db.liabilities).insert(LiabilitiesCompanion.insert(id: 'l1', kind: 'loan', name: 'Car loan', outstandingMinor: 400000));
    for (final (id, m, d) in [('t_new', 11, 3), ('t_prev', 10, 20), ('t_old', 9, 28)]) {
      await db.into(db.transactions).insert(
        TransactionsCompanion.insert(
          id: id,
          accountId: 'a1',
          amountMinor: 1000,
          direction: 'debit',
          postedAt: DateTime.utc(2026, m, d),
          source: 'manual',
          merchantRaw: const Value('Carrefour'),
        ),
      );
    }
  });

  tearDown(() => db.close());

  test('only this and the previous month of transactions are offered', () async {
    final ids = [for (final r in await store.ownRows()) if (r.table == HTable.transactions) r.id]..sort();
    expect(ids, ['t_new', 't_prev']);
  });

  test('wealth lines carry their account, asset or loan ownership; unsupported kinds are private', () async {
    await store.setOwnership(HTable.lines, 'account:a1', owner: Owner.shared);
    await store.setOwnership(HTable.lines, 'as1', isPrivate: true);
    final rows = {for (final r in await store.ownRows()) if (r.table == HTable.lines) r.id: r};
    expect(rows['account:a1']!.owner, Owner.shared);
    expect(rows['as1']!.isPrivate, isTrue);
    expect(rows['l1']!.owner, Owner.me);
    expect(rows['l1']!.values['liability'], isTrue);
    expect(rows['l1']!.values['value_minor'], 400000);
    expect(rows['jewel:1']!.isPrivate, isTrue, reason: 'no ownership support yet: stays private');
    expect(await db.customSelect("SELECT owner FROM accounts WHERE id = 'a1'").getSingle().then((r) => r.data['owner']), 'shared');
  });

  test('exported transactions carry only the allowed columns', () async {
    final r = (await store.ownRows()).firstWhere((r) => r.id == 't_new');
    expect(r.values.keys.toSet(), {'category_id', 'amount_minor', 'currency', 'direction', 'merchant', 'posted_at', 'excluded'});
    expect(r.values['merchant'], 'Carrefour');
  });

  test('config, members, bills, limits and mirror round trip; leaving clears them and resets owners', () async {
    await store.saveConfig(HouseholdConfig(id: 'h', name: 'Us', myMemberId: 'm1', createdAt: now));
    await store.saveMember(HMember(id: 'm1', name: 'Maya', joinedAt: now));
    await store.saveBill(const HBill(id: 'b', name: 'Rent', amountMinor: 650000, dueDay: 1, split: {'m1': 6000, 'm2': 4000}));
    await store.saveLimit(const HLimit(id: 'l', categoryId: 'groceries', limitMinor: 200000));
    await store.putMirror(HTable.transactions, 'x', {'amount_minor': 5, 'owner': 'm2'});
    await store.setOwnership(HTable.transactions, 't_new', owner: 'm2', isPrivate: true);

    expect((await store.config())!.shareMine, isTrue);
    expect((await store.members()).single.name, 'Maya');
    expect((await store.bills()).single.split, {'m1': 6000, 'm2': 4000});
    expect((await store.limits()).single.limitMinor, 200000);
    expect((await store.mirror())[HTable.transactions]!['x']!['owner'], 'm2');

    await store.clearAll();
    expect(await store.config(), isNull);
    expect(await store.members(), isEmpty);
    expect(await store.bills(), isEmpty);
    expect(await store.limits(), isEmpty);
    expect(await store.mirror(), isEmpty);
    final o = await store.ownership(HTable.transactions, 't_new');
    expect(o.owner, Owner.me);
    expect(o.isPrivate, isTrue);
  });
}
