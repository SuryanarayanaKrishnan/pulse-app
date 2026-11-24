import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/local/database.dart';

/// All rows of one table, column-name keyed so a newer or older schema can
/// still read it.
class TableDump {
  TableDump(this.name, this.columns, this.rows);
  final String name;
  final List<String> columns;
  final List<List<Object?>> rows;

  int indexOfColumn(String c) => columns.indexOf(c);
}

Object? _encode(Object? v) => v is Uint8List ? {r'$b': base64.encode(v)} : v;
Object? _decode(Object? v) => v is Map && v[r'$b'] is String ? base64.decode(v[r'$b'] as String) : v;

String _q(String ident) => '"${ident.replaceAll('"', '""')}"';

Future<List<String>> userTables(GeneratedDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
      )
      .get();
  return [for (final r in rows) r.read<String>('name')];
}

/// A consistent read of every table (one transaction).
Future<List<TableDump>> dumpTables(PulseDatabase db) => db.transaction(() async {
  final out = <TableDump>[];
  for (final t in await userTables(db)) {
    final rows = await db.customSelect('SELECT * FROM ${_q(t)} ORDER BY rowid').get();
    final cols = rows.isEmpty
        ? [
            for (final r in await db.customSelect('PRAGMA table_info(${_q(t)})').get()) r.read<String>('name'),
          ]
        : rows.first.data.keys.toList();
    out.add(TableDump(t, cols, [for (final r in rows) [for (final c in cols) r.data[c]]]));
  }
  return out;
});

List<int> encodeChunk(String table, List<String> columns, List<List<Object?>> rows) => utf8.encode(
  jsonEncode({
    't': table,
    'c': columns,
    'r': [
      for (final row in rows) [for (final v in row) _encode(v)],
    ],
  }),
);

TableDump decodeChunk(List<int> bytes) {
  final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  return TableDump(
    j['t'] as String,
    (j['c'] as List).cast<String>(),
    [
      for (final r in (j['r'] as List)) [for (final v in (r as List)) _decode(v)],
    ],
  );
}

Variable<Object> _variable(Object? v) => Variable<Object>(v);

class ImportCounts {
  ImportCounts(this.tables, this.rows);
  final int tables;
  final int rows;
}

/// Replaces the content of every table present in [dumps] with the backup's
/// rows. Only columns that exist in this app's schema are written (columns it
/// has not got are dropped, new columns keep their defaults). Runs in one
/// transaction with foreign keys off, then checks they all hold.
Future<ImportCounts> importTables(PulseDatabase db, Iterable<TableDump> dumps) async {
  final present = (await userTables(db)).toSet();
  var rowTotal = 0;
  var tableTotal = 0;
  await db.customStatement('PRAGMA foreign_keys = OFF');
  try {
    await db.transaction(() async {
      for (final d in dumps) {
        if (!present.contains(d.name)) continue;
        final known = {
          for (final r in await db.customSelect('PRAGMA table_info(${_q(d.name)})').get()) r.read<String>('name'),
        };
        final idx = <int>[for (var i = 0; i < d.columns.length; i++) if (known.contains(d.columns[i])) i];
        await db.customStatement('DELETE FROM ${_q(d.name)}');
        tableTotal++;
        if (idx.isEmpty) continue;
        final sql =
            'INSERT OR REPLACE INTO ${_q(d.name)} (${idx.map((i) => _q(d.columns[i])).join(',')}) '
            'VALUES (${idx.map((_) => '?').join(',')})';
        for (final row in d.rows) {
          await db.customInsert(sql, variables: [for (final i in idx) _variable(row[i])]);
          rowTotal++;
        }
      }
      final bad = await db.customSelect('PRAGMA foreign_key_check').get();
      if (bad.isNotEmpty) throw const FormatException('The backup is internally inconsistent');
    });
  } finally {
    await db.customStatement('PRAGMA foreign_keys = ON');
  }
  return ImportCounts(tableTotal, rowTotal);
}
