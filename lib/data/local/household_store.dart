import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/household/household_bridge.dart';
import '../../core/household/household_models.dart';
import '../../core/household/household_scope.dart';
import '../../core/household/household_store.dart';
import '../goal_models.dart';
import '../models.dart' show Asset;
import 'database.dart';

/// Months of transactions a household log carries: this month and the one
/// before. A fixed calendar window (not "last 60 days") so rows only leave
/// it once a month.
DateTime sharingWindowStart(DateTime now) =>
    DateTime.utc(now.year, now.month - 1, 1);

/// The household on the on-device database.
class LocalHouseholdStore implements HouseholdStore {
  LocalHouseholdStore(
    this.db, {
    required this.wealth,
    required this.goals,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PulseDatabase db;

  /// The Wealth list (accounts, assets, loans, card balances), already
  /// valued; ownership is looked up here by id.
  final Future<List<Asset>> Function() wealth;

  /// Goals with their progress worked out.
  final Future<List<GoalView>> Function() goals;
  final DateTime Function() _clock;

  // ---- config, members, bills, limits ------------------------------------

  @override
  Future<HouseholdConfig?> config() async {
    final r = await db.select(db.householdConfigs).getSingleOrNull();
    return r == null
        ? null
        : HouseholdConfig(
            id: r.id,
            name: r.name,
            myMemberId: r.myMemberId,
            shareMine: r.shareMine,
            createdAt: r.createdAt,
          );
  }

  @override
  Future<void> saveConfig(HouseholdConfig c) async {
    await db.transaction(() async {
      await db.delete(db.householdConfigs).go();
      await db
          .into(db.householdConfigs)
          .insert(
            HouseholdConfigsCompanion.insert(
              id: c.id,
              name: c.name,
              myMemberId: c.myMemberId,
              shareMine: Value(c.shareMine),
              createdAt: Value(c.createdAt),
            ),
          );
    });
  }

  @override
  Future<List<HMember>> members() async => [
    for (final r
        in await (db.select(db.householdMembers)..orderBy([
              (t) => OrderingTerm.asc(t.joinedAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
            .get())
      HMember(
        id: r.id,
        name: r.name,
        joinedAt: r.joinedAt,
        removedBy: r.removedBy,
      ),
  ];

  @override
  Future<void> saveMember(HMember m) => db
      .into(db.householdMembers)
      .insertOnConflictUpdate(
        HouseholdMembersCompanion.insert(
          id: m.id,
          name: m.name,
          joinedAt: Value(m.joinedAt),
          removedBy: Value(m.removedBy),
        ),
      );

  @override
  Future<void> deleteMember(String id) =>
      (db.delete(db.householdMembers)..where((t) => t.id.equals(id))).go();

  @override
  Future<List<HBill>> bills() async => [
    for (final r in await db.select(db.householdBills).get())
      HBill(
        id: r.id,
        name: r.name,
        amountMinor: r.amountMinor,
        currency: r.currency,
        dueDay: r.dueDay,
        categoryId: r.categoryId,
        split: _split(r.split),
      ),
  ];

  static Map<String, int> _split(String json) {
    try {
      final m = jsonDecode(json) as Map;
      return {
        for (final e in m.entries) e.key as String: (e.value as num).toInt(),
      };
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> saveBill(HBill b) => db
      .into(db.householdBills)
      .insertOnConflictUpdate(
        HouseholdBillsCompanion.insert(
          id: b.id,
          name: b.name,
          amountMinor: b.amountMinor,
          currency: Value(b.currency),
          dueDay: b.dueDay,
          categoryId: Value(b.categoryId),
          split: Value(jsonEncode(b.split)),
        ),
      );

  @override
  Future<void> deleteBill(String id) =>
      (db.delete(db.householdBills)..where((t) => t.id.equals(id))).go();

  @override
  Future<List<HLimit>> limits() async => [
    for (final r in await db.select(db.householdLimits).get())
      HLimit(
        id: r.id,
        categoryId: r.categoryId,
        limitMinor: r.limitMinor,
        currency: r.currency,
      ),
  ];

  @override
  Future<void> saveLimit(HLimit l) => db
      .into(db.householdLimits)
      .insertOnConflictUpdate(
        HouseholdLimitsCompanion.insert(
          id: l.id,
          categoryId: l.categoryId,
          limitMinor: l.limitMinor,
          currency: Value(l.currency),
        ),
      );

  @override
  Future<void> deleteLimit(String id) =>
      (db.delete(db.householdLimits)..where((t) => t.id.equals(id))).go();

  // ---- my rows --------------------------------------------------------------

  @override
  Future<List<HRow>> ownRows() async {
    final out = <HRow>[];

    final from = sharingWindowStart(_clock());
    final txs =
        await (db.select(db.transactions)..where(
              (t) =>
                  t.deletedAt.isNull() & t.postedAt.isBiggerOrEqualValue(from),
            ))
            .get();
    for (final t in txs) {
      out.add(
        HRow(
          table: HTable.transactions,
          id: t.id,
          owner: t.owner,
          isPrivate: t.isPrivate,
          values: {
            'category_id': t.categoryId,
            'amount_minor': t.amountMinor,
            'currency': t.currency,
            'direction': t.direction,
            'merchant': t.merchantNormalized ?? t.merchantRaw ?? '',
            'posted_at': t.postedAt.toUtc().toIso8601String(),
            'excluded': t.excludeFromBudget,
          },
        ),
      );
    }

    final own = await _lineOwnership();
    for (final a in await wealth()) {
      final o = own[a.id] ?? const Ownership(isPrivate: true);
      out.add(
        HRow(
          table: HTable.lines,
          id: a.id,
          owner: o.owner,
          isPrivate: o.isPrivate,
          values: {
            'name': a.name,
            'liability': a.isLiability,
            'value_minor': (a.value.abs() * 100).round(),
            'currency': 'AED',
          },
        ),
      );
    }

    final goalOwn = {
      for (final g in await db.select(db.savingsGoals).get())
        g.id: Ownership(owner: g.owner, isPrivate: g.isPrivate),
    };
    for (final g in await goals()) {
      final o = goalOwn[g.id] ?? const Ownership();
      out.add(
        HRow(
          table: HTable.goals,
          id: g.id,
          owner: o.owner,
          isPrivate: o.isPrivate,
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

  /// Ownership of every Wealth line by its Wealth-list id (`jewel:` and
  /// `fund:` rows included). Lines with no ownership columns (stocks) are
  /// absent: the caller treats them as Private.
  Future<Map<String, Ownership>> _lineOwnership() async {
    final m = <String, Ownership>{};
    for (final a in await db.select(db.accounts).get()) {
      final o = Ownership(owner: a.owner, isPrivate: a.isPrivate);
      m['account:${a.id}'] = o;
      m['card:${a.id}'] = o;
    }
    for (final a in await db.select(db.assets).get()) {
      m[a.id] = Ownership(owner: a.owner, isPrivate: a.isPrivate);
    }
    for (final l in await db.select(db.liabilities).get()) {
      m[l.id] = Ownership(owner: l.owner, isPrivate: l.isPrivate);
    }
    for (final j in await db.select(db.jewelleryItems).get()) {
      m['jewel:${j.id}'] = Ownership(owner: j.owner, isPrivate: j.isPrivate);
    }
    for (final f in await db.select(db.fundHoldings).get()) {
      m['fund:${f.id}'] = Ownership(owner: f.owner, isPrivate: f.isPrivate);
    }
    return m;
  }

  @override
  Future<Ownership> ownership(String table, String id) async {
    switch (table) {
      case HTable.transactions:
        final r = await (db.select(
          db.transactions,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return r == null
            ? const Ownership()
            : Ownership(owner: r.owner, isPrivate: r.isPrivate);
      case HTable.goals:
        final r = await (db.select(
          db.savingsGoals,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        return r == null
            ? const Ownership()
            : Ownership(owner: r.owner, isPrivate: r.isPrivate);
      case HTable.lines:
        return (await _lineOwnership())[id] ?? const Ownership(isPrivate: true);
    }
    return const Ownership();
  }

  @override
  Future<void> setOwnership(
    String table,
    String id, {
    String? owner,
    bool? isPrivate,
  }) async {
    Value<String> o() => owner == null ? const Value.absent() : Value(owner);
    Value<bool> p() =>
        isPrivate == null ? const Value.absent() : Value(isPrivate);
    switch (table) {
      case HTable.transactions:
        await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
          TransactionsCompanion(owner: o(), isPrivate: p()),
        );
      case HTable.goals:
        await (db.update(db.savingsGoals)..where((t) => t.id.equals(id))).write(
          SavingsGoalsCompanion(owner: o(), isPrivate: p()),
        );
      case HTable.lines:
        if (id.startsWith('account:') || id.startsWith('card:')) {
          final aid = id.substring(id.indexOf(':') + 1);
          await (db.update(db.accounts)..where((t) => t.id.equals(aid))).write(
            AccountsCompanion(owner: o(), isPrivate: p()),
          );
        } else if (id.startsWith('jewel:')) {
          await (db.update(db.jewelleryItems)
                ..where((t) => t.id.equals(id.substring(6))))
              .write(JewelleryItemsCompanion(owner: o(), isPrivate: p()));
        } else if (id.startsWith('fund:')) {
          await (db.update(db.fundHoldings)
                ..where((t) => t.id.equals(id.substring(5))))
              .write(FundHoldingsCompanion(owner: o(), isPrivate: p()));
        } else {
          await (db.update(db.assets)..where((t) => t.id.equals(id))).write(
            AssetsCompanion(owner: o(), isPrivate: p()),
          );
          await (db.update(db.liabilities)..where((t) => t.id.equals(id)))
              .write(LiabilitiesCompanion(owner: o(), isPrivate: p()));
        }
    }
  }

  // ---- mirror ----------------------------------------------------------------

  @override
  Future<HRows> mirror() async {
    final out = <String, Map<String, Map<String, Object?>>>{};
    for (final r in await db.select(db.householdMirror).get()) {
      try {
        out.putIfAbsent(r.kind, () => {})[r.rowId] = Map<String, Object?>.from(
          jsonDecode(r.payload) as Map,
        );
      } catch (_) {
        // an unreadable copy is just absent; the next sync rewrites it
      }
    }
    return out;
  }

  @override
  Future<void> putMirror(
    String table,
    String id,
    Map<String, Object?>? values,
  ) async {
    if (values == null) {
      await (db.delete(
        db.householdMirror,
      )..where((t) => t.kind.equals(table) & t.rowId.equals(id))).go();
      return;
    }
    await db
        .into(db.householdMirror)
        .insertOnConflictUpdate(
          HouseholdMirrorCompanion.insert(
            kind: table,
            rowId: id,
            payload: jsonEncode(values),
          ),
        );
  }

  @override
  Future<void> clearMirror() => db.delete(db.householdMirror).go();

  @override
  Future<void> reassignOwner(String from, String to) async {
    for (final t in [
      'accounts',
      'transactions',
      'assets',
      'liabilities',
      'savings_goals',
      'jewellery_items',
      'fund_holdings',
    ]) {
      await db.customUpdate(
        'UPDATE $t SET owner = ? WHERE owner = ?',
        variables: [Variable<String>(to), Variable<String>(from)],
        updates: {
          db.accounts,
          db.transactions,
          db.assets,
          db.liabilities,
          db.savingsGoals,
          db.jewelleryItems,
          db.fundHoldings,
        },
        updateKind: UpdateKind.update,
      );
    }
  }

  @override
  Future<void> clearAll() async {
    await db.transaction(() async {
      await db.delete(db.householdConfigs).go();
      await db.delete(db.householdMembers).go();
      await db.delete(db.householdBills).go();
      await db.delete(db.householdLimits).go();
      await db.delete(db.householdMirror).go();
      for (final t in [
        'accounts',
        'transactions',
        'assets',
        'liabilities',
        'savings_goals',
        'jewellery_items',
        'fund_holdings',
      ]) {
        await db.customUpdate(
          "UPDATE $t SET owner = 'me' WHERE owner <> 'me'",
          updates: {
            db.accounts,
            db.transactions,
            db.assets,
            db.liabilities,
            db.savingsGoals,
            db.jewelleryItems,
            db.fundHoldings,
          },
          updateKind: UpdateKind.update,
        );
      }
    });
  }
}
