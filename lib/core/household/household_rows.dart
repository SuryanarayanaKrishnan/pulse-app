import 'dart:convert';

import 'household_models.dart';
import 'household_scope.dart';

/// Conversions between typed household objects and log rows. `fromRow`
/// returns null for a row that is incomplete or malformed (a buggy or newer
/// build): such rows are skipped, never thrown on, so one bad row cannot
/// stall the log.

int? _int(Object? v) => v is int ? v : (v is num && v == v.roundToDouble() ? v.toInt() : null);
String? _str(Object? v) => v is String ? v : null;

Map<String, Object?> memberToRow(HMember m) => {
  'name': m.name,
  'joined_at': m.joinedAt?.toUtc().toIso8601String(),
};

HMember? memberFromRow(String id, Map<String, Object?> r) {
  final name = _str(r['name']);
  if (name == null || name.isEmpty) return null;
  return HMember(id: id, name: name, joinedAt: DateTime.tryParse(_str(r['joined_at']) ?? ''));
}

Map<String, Object?> billToRow(HBill b) => {
  'name': b.name,
  'amount_minor': b.amountMinor,
  'currency': b.currency,
  'due_day': b.dueDay,
  'category_id': b.categoryId,
  'split': jsonEncode(b.split),
};

HBill? billFromRow(String id, Map<String, Object?> r) {
  final name = _str(r['name']);
  final amount = _int(r['amount_minor']);
  final day = _int(r['due_day']);
  if (name == null || amount == null || day == null || day < 1 || day > 31) return null;
  Map<String, int> split;
  try {
    final j = jsonDecode(_str(r['split']) ?? '{}') as Map;
    split = {for (final e in j.entries) e.key as String: _int(e.value) ?? 0};
  } catch (_) {
    return null;
  }
  return HBill(
    id: id,
    name: name,
    amountMinor: amount,
    currency: _str(r['currency']) ?? 'AED',
    dueDay: day,
    categoryId: _str(r['category_id']),
    split: split,
  );
}

Map<String, Object?> limitToRow(HLimit l) => {
  'category_id': l.categoryId,
  'limit_minor': l.limitMinor,
  'currency': l.currency,
};

HLimit? limitFromRow(String id, Map<String, Object?> r) {
  final cat = _str(r['category_id']);
  final limit = _int(r['limit_minor']);
  if (cat == null || limit == null) return null;
  return HLimit(id: id, categoryId: cat, limitMinor: limit, currency: _str(r['currency']) ?? 'AED');
}

HTx? txFromRow(String id, Map<String, Object?> r) {
  final amount = _int(r['amount_minor']);
  final posted = DateTime.tryParse(_str(r['posted_at']) ?? '');
  final owner = _str(r['owner']);
  final dir = _str(r['direction']);
  if (amount == null || posted == null || owner == null || dir == null) return null;
  return HTx(
    id: id,
    owner: owner,
    categoryId: _str(r['category_id']),
    amountMinor: amount,
    currency: _str(r['currency']) ?? 'AED',
    isDebit: dir == 'debit',
    postedAt: posted.toUtc(),
    excluded: r['excluded'] == true || r['excluded'] == 1,
    merchant: _str(r['merchant']) ?? '',
  );
}

HLine? lineFromRow(String id, Map<String, Object?> r) {
  final value = _int(r['value_minor']);
  final owner = _str(r['owner']);
  final name = _str(r['name']);
  if (value == null || owner == null || name == null) return null;
  return HLine(
    id: id,
    name: name,
    isLiability: r['liability'] == true || r['liability'] == 1,
    valueMinor: value,
    currency: _str(r['currency']) ?? 'AED',
    owner: owner,
  );
}

HGoal? goalFromRow(String id, Map<String, Object?> r) {
  final name = _str(r['name']);
  final owner = _str(r['owner']);
  final target = _int(r['target_minor']);
  final current = _int(r['current_minor']);
  final bps = _int(r['progress_bps']);
  if (name == null || owner == null || target == null || current == null || bps == null) return null;
  return HGoal(
    id: id,
    name: name,
    kind: _str(r['kind']) ?? 'save',
    iconKey: _str(r['icon_key']),
    targetMinor: target,
    currentMinor: current,
    progressBps: bps,
    targetDate: _str(r['target_date']),
    paused: r['paused'] == true || r['paused'] == 1,
    owner: owner,
  );
}

/// The mirror's rows of one table, typed. Malformed rows are left out.
List<T> mirrorOf<T>(
  Map<String, Map<String, Map<String, Object?>>> mirror,
  String table,
  T? Function(String, Map<String, Object?>) fromRow,
) => [
  for (final e in (mirror[table] ?? const <String, Map<String, Object?>>{}).entries)
    if (fromRow(e.key, e.value) case final T v) v,
];

/// Tables a typed reader exists for (documentation and tests).
const mirrorTables = HTable.personal;
