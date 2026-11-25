import '../sync/change.dart';
import '../sync/sync_bridge.dart';
import '../sync/sync_state.dart';
import 'household_models.dart';
import 'household_scope.dart';

/// Table -> row id -> column -> value.
typedef HRows = Map<String, Map<String, Map<String, Object?>>>;

/// What the household log needs from the phone. Implemented over drift for
/// the app and over maps for tests.
abstract class HouseholdSource {
  HouseholdConfig get config;

  /// Everything of mine that could be shared, Private items included (the
  /// gate in `household_scope.dart` decides). Local owners (`me`).
  Future<List<HRow>> ownRows();

  /// Rows in the tables both members edit (`members`, `bills`, `limits`),
  /// in log form (absolute owners / member ids).
  Future<HRows> sharedRows();

  /// What the other members shared with me, read-only.
  Future<HRows> mirrorRows();

  /// Writes a merged row of a shared table, or deletes it (null).
  Future<void> applyShared(String table, String id, Map<String, Object?>? values);

  /// Writes a merged row of the mirror, or deletes it (null).
  Future<void> applyMirror(String table, String id, Map<String, Object?>? values);
}

/// The household log's view of the phone, for the sync engine.
///
/// `read()` is what this phone knows: my exportable rows (through the gate),
/// the shared tables, and the mirror of everyone else's. Including the mirror
/// matters: the engine treats rows it knows but cannot see as deleted by this
/// phone, so the mirror must be part of the snapshot.
class HouseholdBridge implements SyncBridge {
  HouseholdBridge(this.source);
  final HouseholdSource source;

  @override
  int get schemaVersion => householdLogVersion;

  @override
  Future<LocalSnapshot> read() async {
    final cfg = source.config;
    // Every table is present even when empty: the engine only looks for rows
    // that vanished inside the tables it is shown.
    final out = <String, Map<String, Map<String, Object?>>>{
      for (final t in HTable.all) t: {},
    };
    void merge(HRows rows) {
      rows.forEach((t, m) {
        final dst = out.putIfAbsent(t, () => {});
        m.forEach((id, v) => dst[id] = Map.of(v));
      });
    }

    merge(await source.mirrorRows());
    merge(await source.sharedRows());
    merge(
      exportSnapshot(
        await source.ownRows(),
        myMemberId: cfg.myMemberId,
        shareMine: cfg.shareMine,
      ),
    );
    return out;
  }

  @override
  Future<Set<RowKey>> write(List<RowWrite> writes) async {
    final failed = <RowKey>{};
    for (final w in writes) {
      try {
        if (!HTable.all.contains(w.table)) continue; // unknown: ignore
        final values = w.values == null ? null : importRow(w.table, w.values!);
        if (HTable.shared.contains(w.table)) {
          await source.applyShared(w.table, w.id, values);
        } else {
          await source.applyMirror(w.table, w.id, values);
        }
      } catch (_) {
        failed.add(w.key);
      }
    }
    return failed;
  }
}
