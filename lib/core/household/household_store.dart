import 'household_bridge.dart';
import 'household_models.dart';
import 'household_rows.dart';
import 'household_scope.dart';

/// Ownership of one item.
class Ownership {
  const Ownership({this.owner = Owner.me, this.isPrivate = false});
  final String owner;
  final bool isPrivate;
}

/// Storage for the household: the drift database on a phone, or memory
/// (demo data, web builds, tests).
abstract class HouseholdStore {
  Future<HouseholdConfig?> config();
  Future<void> saveConfig(HouseholdConfig c);

  Future<List<HMember>> members();
  Future<void> saveMember(HMember m);
  Future<void> deleteMember(String id);

  Future<List<HBill>> bills();
  Future<void> saveBill(HBill b);
  Future<void> deleteBill(String id);

  Future<List<HLimit>> limits();
  Future<void> saveLimit(HLimit l);
  Future<void> deleteLimit(String id);

  /// Everything of mine that could be shared (transactions of the sharing
  /// window, net worth lines, goals), with local owners and Private flags.
  Future<List<HRow>> ownRows();

  Future<Ownership> ownership(String table, String id);

  /// [table]: `transactions`, `lines` (id as the Wealth list names it) or
  /// `goals`. Changing a line's owner changes the account, asset or
  /// liability behind it.
  Future<void> setOwnership(String table, String id, {String? owner, bool? isPrivate});

  Future<HRows> mirror();
  Future<void> putMirror(String table, String id, Map<String, Object?>? values);

  /// Forgets every other member's mirrored rows (they come back from the
  /// log of a new household).
  Future<void> clearMirror();

  /// Puts my items assigned to [from] (a member who is gone) on [to].
  Future<void> reassignOwner(String from, String to);

  /// Leaving: forget the household, its shared rows and the mirror, and put
  /// everything of mine back to "mine".
  Future<void> clearAll();
}

/// Adapts a [HouseholdStore] to the log.
class StoreHouseholdSource implements HouseholdSource {
  StoreHouseholdSource(this.store, this.config, {this.withdrawAll = false});
  final HouseholdStore store;

  /// Leaving: offer nothing of mine, so the log retracts everything I wrote.
  final bool withdrawAll;

  @override
  final HouseholdConfig config;

  @override
  Future<List<HRow>> ownRows() async => withdrawAll ? const [] : store.ownRows();

  @override
  Future<HRows> mirrorRows() => store.mirror();

  @override
  Future<HRows> sharedRows() async => {
    HTable.members: {for (final m in await store.members()) m.id: memberToRow(m)},
    HTable.bills: {for (final b in await store.bills()) b.id: billToRow(b)},
    HTable.limits: {for (final l in await store.limits()) l.id: limitToRow(l)},
  };

  @override
  Future<void> applyMirror(String table, String id, Map<String, Object?>? values) =>
      store.putMirror(table, id, values);

  @override
  Future<void> applyShared(String table, String id, Map<String, Object?>? values) async {
    switch (table) {
      case HTable.members:
        if (values == null) {
          if (id != config.myMemberId) await store.deleteMember(id);
        } else if (memberFromRow(id, values) case final m?) {
          await store.saveMember(m);
        }
      case HTable.bills:
        if (values == null) {
          await store.deleteBill(id);
        } else if (billFromRow(id, values) case final b?) {
          await store.saveBill(b);
        }
      case HTable.limits:
        if (values == null) {
          await store.deleteLimit(id);
        } else if (limitFromRow(id, values) case final l?) {
          await store.saveLimit(l);
        }
    }
  }
}

/// In memory: demo data, web builds and tests. The rows come from [own] (a
/// test seeds it) or from [loader] (the demo derives them from the demo
/// ledger); ownership changes are kept on top of either.
class MemoryHouseholdStore implements HouseholdStore {
  MemoryHouseholdStore({List<HRow>? own, this.loader}) : own = own ?? [];

  HouseholdConfig? cfg;
  final _members = <String, HMember>{};
  final _bills = <String, HBill>{};
  final _limits = <String, HLimit>{};
  final HRows _mirror = {};
  final _ownership = <String, Ownership>{};

  /// Mutable on purpose (tests seed it).
  List<HRow> own;
  final Future<List<HRow>> Function()? loader;

  @override
  Future<HouseholdConfig?> config() async => cfg;
  @override
  Future<void> saveConfig(HouseholdConfig c) async => cfg = c;

  @override
  Future<List<HMember>> members() async => _members.values.toList();
  @override
  Future<void> saveMember(HMember m) async => _members[m.id] = m;
  @override
  Future<void> deleteMember(String id) async => _members.remove(id);

  @override
  Future<List<HBill>> bills() async => _bills.values.toList();
  @override
  Future<void> saveBill(HBill b) async => _bills[b.id] = b;
  @override
  Future<void> deleteBill(String id) async => _bills.remove(id);

  @override
  Future<List<HLimit>> limits() async => _limits.values.toList();
  @override
  Future<void> saveLimit(HLimit l) async => _limits[l.id] = l;
  @override
  Future<void> deleteLimit(String id) async => _limits.remove(id);

  static String _k(String table, String id) => '$table|$id';

  @override
  Future<List<HRow>> ownRows() async {
    final base = loader != null ? await loader!() : own;
    return [
      for (final r in base)
        if (_ownership[_k(r.table, r.id)] case final o?)
          HRow(table: r.table, id: r.id, owner: o.owner, isPrivate: o.isPrivate, values: r.values)
        else
          r,
    ];
  }

  @override
  Future<Ownership> ownership(String table, String id) async {
    final r = (await ownRows()).where((r) => r.table == table && r.id == id).firstOrNull;
    return r == null ? const Ownership() : Ownership(owner: r.owner, isPrivate: r.isPrivate);
  }

  @override
  Future<void> setOwnership(String table, String id, {String? owner, bool? isPrivate}) async {
    final cur = await ownership(table, id);
    _ownership[_k(table, id)] = Ownership(owner: owner ?? cur.owner, isPrivate: isPrivate ?? cur.isPrivate);
  }

  @override
  Future<HRows> mirror() async => {
    for (final t in _mirror.entries)
      t.key: {for (final r in t.value.entries) r.key: Map.of(r.value)},
  };

  @override
  Future<void> putMirror(String table, String id, Map<String, Object?>? values) async {
    if (values == null) {
      _mirror[table]?.remove(id);
    } else {
      _mirror.putIfAbsent(table, () => {})[id] = Map.of(values);
    }
  }

  @override
  Future<void> clearMirror() async => _mirror.clear();

  @override
  Future<void> reassignOwner(String from, String to) async {
    for (final r in await ownRows()) {
      if (r.owner == from)
        _ownership[_k(r.table, r.id)] = Ownership(
          owner: to,
          isPrivate: r.isPrivate,
        );
    }
  }

  @override
  Future<void> clearAll() async {
    cfg = null;
    _members.clear();
    _bills.clear();
    _limits.clear();
    _mirror.clear();
    for (final r in await ownRows()) {
      _ownership[_k(r.table, r.id)] = Ownership(isPrivate: r.isPrivate);
    }
  }
}
