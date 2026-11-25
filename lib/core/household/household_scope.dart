/// What may enter the shared household log, as an explicit allow-list, and
/// the gate every row passes on its way out.
///
/// The rule that matters: a row marked Private never reaches the log, and
/// neither does anything outside the column lists below (notes, tags, raw
/// merchant text, account ids, file paths...). The gate lives here, in pure
/// code, so it is covered by unit tests and by the two-member simulation.
library;

import 'household_models.dart';

/// Version of the log's row layout. A phone refuses a segment from a newer
/// layout ("update the app") instead of misreading it.
const householdLogVersion = 1;

/// Object-name namespace of a household's log.
String householdNamespace(String householdId) => 'household/$householdId';

/// HKDF purpose of the log key (a sub-key of the 32-byte household key).
const householdKeyPurpose = 'household.segments';

abstract final class HTable {
  /// Rows both members edit; they live in real local tables.
  static const members = 'members';
  static const bills = 'bills';
  static const limits = 'limits';

  /// Rows each member authors about their own things; others only mirror
  /// them (read-only, never merged into the other's ledger).
  static const transactions = 'transactions';
  static const lines = 'lines';
  static const goals = 'goals';

  static const shared = {members, bills, limits};
  static const personal = {transactions, lines, goals};
  static const all = {...shared, ...personal};
}

/// Columns that may be written to the log, per table. `owner` is absolute.
const householdColumns = <String, Set<String>>{
  HTable.members: {'name', 'joined_at', 'removed_by'},
  HTable.bills: {
    'name',
    'amount_minor',
    'currency',
    'due_day',
    'category_id',
    'split',
  },
  HTable.limits: {'category_id', 'limit_minor', 'currency'},
  HTable.transactions: {
    'category_id',
    'amount_minor',
    'currency',
    'direction',
    'merchant',
    'posted_at',
    'excluded',
    'owner',
  },
  HTable.lines: {'name', 'liability', 'value_minor', 'currency', 'owner'},
  HTable.goals: {
    'name',
    'kind',
    'icon_key',
    'target_minor',
    'current_minor',
    'progress_bps',
    'target_date',
    'paused',
    'owner',
  },
};

/// A local item that might be shared: table, id, who owns it (local form),
/// whether it is Private, and its values (any columns; the gate trims them).
class HRow {
  const HRow({
    required this.table,
    required this.id,
    this.owner = Owner.me,
    this.isPrivate = false,
    required this.values,
  });
  final String table, id, owner;
  final bool isPrivate;
  final Map<String, Object?> values;
}

/// Whether an item with this ownership may be seen by the household.
///
/// * Private: never.
/// * Mine: only while [shareMine] is on.
/// * Shared, or another member's (recorded here on their behalf): yes.
bool visibleToHousehold({
  required String owner,
  required bool isPrivate,
  required bool shareMine,
}) {
  if (isPrivate) return false;
  if (owner == Owner.me) return shareMine;
  return true;
}

/// The one gate. Returns what goes into the log for [row], or null when it
/// must not (private, mine while not shared, unknown table). Columns outside
/// the allow-list are dropped; `owner` is rewritten to its absolute form.
Map<String, Object?>? exportRow(
  HRow row, {
  required String myMemberId,
  required bool shareMine,
}) {
  final cols = householdColumns[row.table];
  if (cols == null || !HTable.personal.contains(row.table)) return null;
  if (!visibleToHousehold(
    owner: row.owner,
    isPrivate: row.isPrivate,
    shareMine: shareMine,
  )) {
    return null;
  }
  final out = <String, Object?>{
    for (final e in row.values.entries)
      if (cols.contains(e.key) && e.key != 'owner') e.key: e.value,
    'owner': Owner.absolute(row.owner, myMemberId),
  };
  return out;
}

/// The snapshot of my personal rows for the log: table -> id -> columns.
Map<String, Map<String, Map<String, Object?>>> exportSnapshot(
  Iterable<HRow> rows, {
  required String myMemberId,
  required bool shareMine,
}) {
  final out = <String, Map<String, Map<String, Object?>>>{};
  for (final r in rows) {
    final x = exportRow(r, myMemberId: myMemberId, shareMine: shareMine);
    if (x == null) continue;
    out.putIfAbsent(r.table, () => {})[r.id] = x;
  }
  return out;
}

/// Keeps only allow-listed columns of a row that arrived from the log. A
/// build that sends more (or fewer) columns never reaches SQL or the mirror
/// with unknown names.
Map<String, Object?> importRow(String table, Map<String, Object?> values) {
  final cols = householdColumns[table] ?? const <String>{};
  return {
    for (final e in values.entries)
      if (cols.contains(e.key)) e.key: e.value,
  };
}
