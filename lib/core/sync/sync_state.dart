import 'dart:convert';
import 'dart:typed_data';

import 'change.dart';
import 'hlc.dart';

/// What the local database looks like right now, restricted to synced tables
/// and columns: table -> row id -> column -> value.
typedef LocalSnapshot = Map<String, Map<String, Map<String, Object?>>>;

/// A segment that has been numbered and is waiting for (or in the middle of)
/// upload. It is persisted before the upload so a retry sends exactly the
/// same changes under the same number: a reader that already took the
/// segment never misses anything.
class PendingSegment {
  PendingSegment(this.seq, this.changes);
  final int seq;
  final List<Change> changes;
}

/// Everything the sync engine remembers between runs: the clock, the winning
/// write of every field (which doubles as the baseline local edits are
/// detected against), the outbox, and how far each other device's log has
/// been read. Pure data plus the merge rules; no I/O.
///
/// Merge rules (all commutative, associative and idempotent):
/// * per field, the write with the greatest [Hlc] wins (last writer wins);
/// * a row is deleted while its `_del` register is `true`; the delete is an
///   ordinary register, so a later `_del=false` (re-created) beats it;
/// * edits that lose to nothing but happened on a row that is deleted stay in
///   the registers and come back if the row is re-created.
class SyncState {
  SyncState(this.deviceId, {int wall = 0, int counter = 0})
    : clock = HlcClock(deviceId, wall: wall, counter: counter);

  final String deviceId;
  final HlcClock clock;

  /// table -> row -> field -> register.
  final Map<String, Map<String, Map<String, Register>>> data = {};
  final List<Change> outbox = [];
  PendingSegment? inflight;
  int pushedSeq = 0;
  final Map<String, int> cursors = {};

  /// Rows whose merged value could not be written to the database yet; they
  /// are retried every sync and meanwhile excluded from local-change
  /// detection (their absence is not a delete).
  final Set<RowKey> unapplied = {};

  /// False until the first sync completed: then the other devices' log is
  /// read before local data is compared, so a restored phone cannot
  /// overwrite newer edits with stale rows.
  bool bootstrapped = false;

  Register? register(String table, String row, String field) =>
      data[table]?[row]?[field];

  bool isDeleted(String table, String row) =>
      data[table]?[row]?[deletedField]?.value == true;

  bool hasRow(String table, String row) => data[table]?[row] != null;

  /// Merges one change. Returns true when it became the winner of its field.
  bool apply(Change c) {
    final fields = data
        .putIfAbsent(c.table, () => {})
        .putIfAbsent(c.row, () => {});
    final cur = fields[c.field];
    if (cur != null && !(c.hlc > cur.hlc)) return false;
    fields[c.field] = Register(c.value, c.hlc);
    return true;
  }

  Change _local(
    String table,
    String row,
    String field,
    Object? value,
    int now,
  ) {
    final c = Change(table, row, field, value, clock.tick(now));
    apply(c);
    outbox.add(c);
    return c;
  }

  /// Compares the database with the registers and records what the user
  /// changed since last time as new local writes. Returns how many.
  int captureLocal(LocalSnapshot snap, int nowMs) {
    var n = 0;
    snap.forEach((table, rows) {
      for (final e in rows.entries) {
        final row = e.key;
        if (unapplied.contains(RowKey(table, row))) continue;
        if (isDeleted(table, row)) {
          _local(table, row, deletedField, false, nowMs);
          n++;
        }
        for (final f in e.value.entries) {
          final cur = register(table, row, f.key);
          if (cur == null || !sameValue(cur.value, f.value)) {
            _local(table, row, f.key, f.value, nowMs);
            n++;
          }
        }
      }
      // Rows we know but the database no longer has were deleted here.
      final known = data[table];
      if (known == null) return;
      for (final row in known.keys.toList()) {
        if (rows.containsKey(row) ||
            isDeleted(table, row) ||
            unapplied.contains(RowKey(table, row))) {
          continue;
        }
        _local(table, row, deletedField, true, nowMs);
        n++;
      }
    });
    return n;
  }

  /// The merged content of a row: null when deleted.
  Map<String, Object?>? materialize(String table, String row) {
    if (isDeleted(table, row)) return null;
    final fields = data[table]?[row];
    if (fields == null) return null;
    return {
      for (final f in fields.entries)
        if (f.key != deletedField) f.key: f.value.value,
    };
  }

  /// Takes up to [max] outbox changes (newest write per field only) and
  /// numbers them as the next segment. Returns null when nothing is pending.
  PendingSegment? nextSegment(int max) {
    if (inflight != null) return inflight;
    if (outbox.isEmpty) return null;
    final latest = <String, Change>{};
    final order = <String>[];
    for (final c in outbox) {
      final k = '${c.table}\u0000${c.row}\u0000${c.field}';
      final prev = latest[k];
      if (prev == null) order.add(k);
      if (prev == null || c.hlc > prev.hlc) latest[k] = c;
    }
    final take = order.take(max).toSet();
    final changes = [
      for (final k in order)
        if (take.contains(k)) latest[k]!,
    ];
    // Drop what was taken, plus superseded duplicates of it.
    outbox.removeWhere(
      (c) => take.contains('${c.table}\u0000${c.row}\u0000${c.field}'),
    );
    return inflight = PendingSegment(pushedSeq + 1, changes);
  }

  void segmentPushed() {
    final s = inflight;
    if (s == null) return;
    pushedSeq = s.seq;
    inflight = null;
  }

  // ---- persistence -------------------------------------------------------

  Object? _enc(Object? v) => v is Uint8List ? {r'$b': base64.encode(v)} : v;
  Object? _dec(Object? v) =>
      v is Map && v[r'$b'] is String ? base64.decode(v[r'$b'] as String) : v;

  Map<String, Object?> toJson() => {
    'v': 1,
    'device': deviceId,
    'wall': clock.wall,
    'counter': clock.counter,
    'boot': bootstrapped,
    'pushed': pushedSeq,
    'cursors': cursors,
    'outbox': [for (final c in outbox) _changeJson(c)],
    'inflight': inflight == null
        ? null
        : {
            'seq': inflight!.seq,
            'changes': [for (final c in inflight!.changes) _changeJson(c)],
          },
    'unapplied': [
      for (final k in unapplied) [k.table, k.id],
    ],
    'data': {
      for (final t in data.entries)
        t.key: {
          for (final r in t.value.entries)
            r.key: {
              for (final f in r.value.entries)
                f.key: [_enc(f.value.value), f.value.hlc.toString()],
            },
        },
    },
  };

  List<Object?> _changeJson(Change c) => [
    c.table,
    c.row,
    c.field,
    _enc(c.value),
    c.hlc.toString(),
  ];

  Change _changeFrom(List<dynamic> j) =>
      Change.fromJson([j[0], j[1], j[2], _dec(j[3]), j[4]]);

  String encode() => jsonEncode(toJson());

  static SyncState decode(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    if (j['v'] != 1) throw const FormatException('Unknown sync state');
    final st = SyncState(
      j['device'] as String,
      wall: j['wall'] as int,
      counter: j['counter'] as int,
    );
    st.bootstrapped = j['boot'] as bool;
    st.pushedSeq = j['pushed'] as int;
    (j['cursors'] as Map).forEach((k, v) => st.cursors[k as String] = v as int);
    for (final c in (j['outbox'] as List)) {
      st.outbox.add(st._changeFrom(c as List));
    }
    final inf = j['inflight'] as Map<String, dynamic>?;
    if (inf != null) {
      st.inflight = PendingSegment(inf['seq'] as int, [
        for (final c in (inf['changes'] as List)) st._changeFrom(c as List),
      ]);
    }
    for (final u in (j['unapplied'] as List)) {
      st.unapplied.add(RowKey((u as List)[0] as String, u[1] as String));
    }
    (j['data'] as Map).forEach((t, rows) {
      final tm = st.data.putIfAbsent(t as String, () => {});
      (rows as Map).forEach((r, fields) {
        final rm = tm.putIfAbsent(r as String, () => {});
        (fields as Map).forEach((f, reg) {
          rm[f as String] = Register(
            st._dec((reg as List)[0]),
            Hlc.parse(reg[1] as String),
          );
        });
      });
    });
    return st;
  }
}

/// Where [SyncState] is kept between runs.
abstract class SyncStateStore {
  Future<SyncState?> load();
  Future<void> save(SyncState state);
}

class MemorySyncStateStore implements SyncStateStore {
  String? json;
  int saves = 0;
  @override
  Future<SyncState?> load() async =>
      json == null ? null : SyncState.decode(json!);
  @override
  Future<void> save(SyncState state) async {
    json = state.encode();
    saves++;
  }
}
