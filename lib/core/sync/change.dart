import 'hlc.dart';

/// The pseudo-field that carries a row's existence: `true` = deleted
/// (tombstone), `false` = alive (re-created after a delete). A row with no
/// such register is alive.
const deletedField = '_del';

/// Identifies one row of one table.
class RowKey {
  const RowKey(this.table, this.id);
  final String table;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is RowKey && other.table == table && other.id == id;
  @override
  int get hashCode => Object.hash(table, id);
  @override
  String toString() => '$table/$id';
}

/// One field write: the unit of the change log. Values are JSON scalars
/// (null, bool, int, double, String) or bytes.
class Change {
  const Change(this.table, this.row, this.field, this.value, this.hlc);

  final String table;
  final String row;
  final String field;
  final Object? value;
  final Hlc hlc;

  RowKey get key => RowKey(table, row);
  bool get isTombstone => field == deletedField && value == true;

  List<Object?> toJson() => [table, row, field, value, hlc.toString()];

  static Change fromJson(List<dynamic> j) {
    if (j.length != 5) throw const FormatException('Bad change');
    return Change(
      j[0] as String,
      j[1] as String,
      j[2] as String,
      j[3],
      Hlc.parse(j[4] as String),
    );
  }

  @override
  String toString() => 'Change($table/$row.$field=$value @$hlc)';
}

/// The winning write of one field.
class Register {
  const Register(this.value, this.hlc);
  final Object? value;
  final Hlc hlc;
}

/// Value equality that treats `1` and `1.0` alike and compares bytes by
/// content (a database may hand back either).
bool sameValue(Object? a, Object? b) {
  if (a == null || b == null) return a == b;
  if (a is List<int> && b is List<int>) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
  return a == b;
}
