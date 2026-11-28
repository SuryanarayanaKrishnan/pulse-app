import 'package:drift/drift.dart';

import '../core/sync/change.dart';
import '../core/sync/sync_bridge.dart';
import '../core/sync/sync_scope.dart';
import '../core/sync/sync_state.dart';
import '../data/local/database.dart';

String _q(String ident) => '"${ident.replaceAll('"', '""')}"';

class _TableInfo {
  _TableInfo(this.columns, this.pk);
  final Set<String> columns;
  final List<String> pk;
}

/// Reads and writes the synced tables of the on-device database. Table and
/// column names that reach SQL are always checked against the allow-list and
/// the real schema first: segments are authenticated, but another device's
/// build may be newer or buggy, and nothing it sends is trusted as SQL.
class DriftSyncBridge implements SyncBridge {
  DriftSyncBridge(this.db);
  final PulseDatabase db;

  /// Row ids of composite keys are the key parts joined with this.
  static const keySep = '\u0001';

  @override
  int get schemaVersion => PulseDatabase.currentSchemaVersion;

  Future<_TableInfo?> _info(String table) async {
    if (!syncedTables.contains(table)) return null;
    final rows = await db.customSelect('PRAGMA table_info(${_q(table)})').get();
    if (rows.isEmpty) return null;
    final cols = <String>{};
    final pk = <(int, String)>[];
    for (final r in rows) {
      final name = r.read<String>('name');
      if (isSyncedColumn(table, name)) cols.add(name);
      final p = r.read<int>('pk');
      if (p > 0) pk.add((p, name));
    }
    pk.sort((a, b) => a.$1.compareTo(b.$1));
    if (pk.isEmpty || pk.any((p) => !cols.contains(p.$2))) return null;
    return _TableInfo(cols, [for (final p in pk) p.$2]);
  }

  @override
  Future<LocalSnapshot> read() async {
    final out = <String, Map<String, Map<String, Object?>>>{};
    for (final t in syncedTables) {
      final info = await _info(t);
      if (info == null) continue;
      final cols = info.columns.toList();
      final rows = await db
          .customSelect('SELECT ${cols.map(_q).join(',')} FROM ${_q(t)}')
          .get();
      final map = <String, Map<String, Object?>>{};
      for (final r in rows) {
        final parts = [for (final c in info.pk) r.data[c]];
        if (parts.any((p) => p == null)) continue;
        map[parts.join(keySep)] = {for (final c in cols) c: r.data[c]};
      }
      out[t] = map;
    }
    return out;
  }

  @override
  Future<Set<RowKey>> write(List<RowWrite> writes) async {
    final failed = <RowKey>{};
    final infos = <String, _TableInfo?>{};
    await db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction(() async {
        for (final w in writes) {
          final info = infos[w.table] ??= await _info(w.table);
          if (info == null) {
            // Unknown or not allowed here: not an error to retry forever.
            continue;
          }
          try {
            final ids = w.id.split(keySep);
            if (ids.length != info.pk.length) continue;
            if (w.values == null) {
              await db.customStatement(
                'DELETE FROM ${_q(w.table)} WHERE ${info.pk.map((c) => '${_q(c)} = ?').join(' AND ')}',
                ids,
              );
              continue;
            }
            final values = <String, Object?>{
              for (final e in w.values!.entries)
                if (info.columns.contains(e.key)) e.key: e.value,
              for (var i = 0; i < ids.length; i++) info.pk[i]: ids[i],
            };
            // Primary keys are text in this schema; the row id carries them.
            final cols = values.keys.toList();
            final update = [
              for (final c in cols)
                if (!info.pk.contains(c)) '${_q(c)} = excluded.${_q(c)}',
            ];
            final sql =
                'INSERT INTO ${_q(w.table)} (${cols.map(_q).join(',')}) '
                'VALUES (${cols.map((_) => '?').join(',')}) '
                'ON CONFLICT(${info.pk.map(_q).join(',')}) '
                '${update.isEmpty ? 'DO NOTHING' : 'DO UPDATE SET ${update.join(',')}'}';
            await db.customInsert(
              sql,
              variables: [for (final c in cols) Variable<Object>(values[c])],
            );
          } catch (_) {
            failed.add(w.key);
          }
        }
      });
    } finally {
      await db.customStatement('PRAGMA foreign_keys = ON');
    }
    return failed;
  }
}
