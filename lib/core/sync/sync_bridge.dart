import 'change.dart';
import 'sync_state.dart';

/// A merged row to put into the local database.
class RowWrite {
  const RowWrite(this.table, this.id, this.values);

  final String table;
  final String id;

  /// Null means "delete this row".
  final Map<String, Object?>? values;

  RowKey get key => RowKey(table, id);
}

/// The only thing the engine knows about the local database.
abstract class SyncBridge {
  /// App database schema version; segments from a newer one are not applied.
  int get schemaVersion;

  /// Rows of the synced tables and columns. Never includes anything outside
  /// the allow-list in `sync_scope.dart`.
  Future<LocalSnapshot> read();

  /// Applies merged rows (inserts or updates, or deletes). Returns the rows
  /// that could not be written (they are retried next time).
  Future<Set<RowKey>> write(List<RowWrite> writes);
}

/// A database made of maps, for tests: a "device".
class MemoryBridge implements SyncBridge {
  MemoryBridge({this.schemaVersion = 1});

  @override
  int schemaVersion;

  final LocalSnapshot tables = {};

  /// Rows that refuse to be written (a constraint failure).
  final Set<RowKey> rejecting = {};

  void put(String table, String id, Map<String, Object?> values) {
    final row = tables.putIfAbsent(table, () => {}).putIfAbsent(id, () => {});
    row.addAll(values);
  }

  void remove(String table, String id) => tables[table]?.remove(id);

  Map<String, Object?>? row(String table, String id) => tables[table]?[id];

  @override
  Future<LocalSnapshot> read() async => {
    for (final t in tables.entries)
      t.key: {
        for (final r in t.value.entries)
          r.key: Map<String, Object?>.of(r.value),
      },
  };

  @override
  Future<Set<RowKey>> write(List<RowWrite> writes) async {
    final failed = <RowKey>{};
    for (final w in writes) {
      if (rejecting.contains(w.key)) {
        failed.add(w.key);
        continue;
      }
      if (w.values == null) {
        remove(w.table, w.id);
      } else {
        put(w.table, w.id, w.values!);
      }
    }
    return failed;
  }
}
