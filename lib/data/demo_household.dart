import '../core/household/household_models.dart';
import '../core/household/household_scope.dart';
import '../core/household/household_store.dart';
import 'goal_service.dart';
import 'repository.dart';

/// Rows for the household in demo mode: derived from the demo ledger, so the
/// joint views have something to show. Real phones read their database.
Future<List<HRow>> demoOwnRows(
  PulseRepository repo,
  GoalService goals, {
  DateTime? now,
}) async {
  final n = now ?? DateTime.now();
  final from = DateTime.utc(n.year, n.month - 1, 1);
  final out = <HRow>[];
  for (final t in await repo.transactions()) {
    if (t.date.isBefore(from)) continue;
    out.add(
      HRow(
        table: HTable.transactions,
        id: t.id,
        values: {
          'category_id': t.category.id,
          'amount_minor': (t.amount * 100).round(),
          'currency': 'AED',
          'direction': t.isIncome ? 'credit' : 'debit',
          'merchant': t.merchant,
          'posted_at': t.date.toUtc().toIso8601String(),
          'excluded': t.excluded,
        },
      ),
    );
  }
  for (final a in await repo.assets()) {
    out.add(
      HRow(
        table: HTable.lines,
        id: a.id,
        values: {
          'name': a.name,
          'liability': a.isLiability,
          'value_minor': (a.value.abs() * 100).round(),
          'currency': 'AED',
        },
      ),
    );
  }
  for (final g in await goals.views()) {
    out.add(
      HRow(
        table: HTable.goals,
        id: g.id,
        values: {
          'name': g.record.name,
          'kind': g.record.kind.key,
          'icon_key': g.record.iconKey,
          'target_minor': g.record.targetMinor,
          'current_minor': g.state.currentMinor,
          'progress_bps': (g.state.progress * 10000).round(),
          'target_date': g.record.targetDate?.toIso(),
          'paused': g.record.paused,
        },
      ),
    );
  }
  return out;
}

const demoMe = 'm_maya', demoPartner = 'm_omar';

/// A household with a partner already in it (screenshots, widget tests, the
/// web demo): the partner's shared items sit in the mirror, there are two
/// bills and three joint limits, and a few of my own rows are marked Shared,
/// Omar's or Private.
///
/// [own] supplies my rows (see [demoOwnRows]); the marks are applied on top.
Future<MemoryHouseholdStore> demoJoinedHousehold(
  Future<List<HRow>> Function() own, {
  DateTime? now,
}) async {
  final n = now ?? DateTime.now();
  final store = MemoryHouseholdStore(loader: own);
  await store.saveConfig(
    HouseholdConfig(
      id: 'd' * 32,
      name: 'Maya & Omar',
      myMemberId: demoMe,
      createdAt: n,
    ),
  );
  await store.saveMember(HMember(id: demoMe, name: 'Maya', joinedAt: n));
  await store.saveMember(HMember(id: demoPartner, name: 'Omar', joinedAt: n));

  String iso(int day) =>
      DateTime.utc(n.year, n.month, day.clamp(1, 28), 9).toIso8601String();
  Future<void> m(String table, String id, Map<String, Object?> v) =>
      store.putMirror(table, id, v);
  Map<String, Object?> tx(
    String cat,
    int amount,
    String merchant,
    int day, [
    String owner = demoPartner,
  ]) => {
    'category_id': cat,
    'amount_minor': amount,
    'currency': 'AED',
    'direction': 'debit',
    'merchant': merchant,
    'posted_at': iso(day),
    'excluded': false,
    'owner': owner,
  };
  await m(
    HTable.transactions,
    'o1',
    tx('groceries', 41250, 'Spinneys', 3, 'shared'),
  );
  await m(
    HTable.transactions,
    'o2',
    tx('groceries', 28600, 'Carrefour', 9, demoPartner),
  );
  await m(HTable.transactions, 'o3', tx('dining', 18400, 'Zuma', 11, 'shared'));
  await m(HTable.transactions, 'o4', tx('transport', 32000, 'ENOC fuel', 6));
  await m(HTable.transactions, 'o5', tx('dining', 9600, 'Tom&Serg', 14));
  await m(HTable.transactions, 'o6', tx('shopping', 74500, 'Amazon.ae', 12));
  await m(HTable.lines, 'omar:cash', {
    'name': 'Omar current account',
    'liability': false,
    'value_minor': 3820000,
    'currency': 'AED',
    'owner': demoPartner,
  });
  await m(HTable.lines, 'omar:car', {
    'name': 'Car loan',
    'liability': true,
    'value_minor': 1450000,
    'currency': 'AED',
    'owner': demoPartner,
  });
  await m(HTable.lines, 'home', {
    'name': 'Marina apartment',
    'liability': false,
    'value_minor': 160000000,
    'currency': 'AED',
    'owner': 'shared',
  });
  await m(HTable.lines, 'mortgage', {
    'name': 'Mortgage',
    'liability': true,
    'value_minor': 98000000,
    'currency': 'AED',
    'owner': 'shared',
  });
  await m(HTable.goals, 'omar:home', {
    'name': 'Furnish the apartment',
    'kind': 'save',
    'icon_key': 'home',
    'target_minor': 4000000,
    'current_minor': 1640000,
    'progress_bps': 4100,
    'paused': false,
    'owner': 'shared',
  });

  await store.saveBill(
    const HBill(
      id: 'b_rent',
      name: 'Rent',
      amountMinor: 650000,
      dueDay: 1,
      categoryId: 'rent',
      split: {demoMe: 5000, demoPartner: 5000},
    ),
  );
  await store.saveBill(
    const HBill(
      id: 'b_net',
      name: 'Internet and TV',
      amountMinor: 52900,
      dueDay: 18,
      categoryId: 'telecom',
      split: {demoMe: 6000, demoPartner: 4000},
    ),
  );
  await store.saveBill(
    const HBill(
      id: 'b_help',
      name: 'Housekeeping',
      amountMinor: 120000,
      dueDay: 27,
      split: {demoMe: 5000, demoPartner: 5000},
    ),
  );
  await store.saveLimit(
    const HLimit(id: 'l_groc', categoryId: 'groceries', limitMinor: 220000),
  );
  await store.saveLimit(
    const HLimit(id: 'l_dine', categoryId: 'dining', limitMinor: 120000),
  );
  await store.saveLimit(
    const HLimit(id: 'l_trans', categoryId: 'transport', limitMinor: 90000),
  );
  return store;
}
