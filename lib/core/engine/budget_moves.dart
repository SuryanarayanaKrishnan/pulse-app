/// "Move money" between categories, for one month. Pure logic.
///
/// A move shifts planned amount from one category to another inside a single
/// month and a single scope (Mine, or Joint). Total planned never changes.
/// Undo is removing the move; nothing else is touched.
library;

enum MoveScope {
  mine('me'),
  joint('shared');

  const MoveScope(this.key);
  final String key;
  static MoveScope fromKey(String? k) => k == 'shared' ? joint : mine;
}

class BudgetMove {
  const BudgetMove({
    required this.id,
    required this.month,
    required this.fromId,
    required this.toId,
    required this.amountMinor,
    this.scope = MoveScope.mine,
    this.undone = false,
  });
  final String id;

  /// `YYYY-MM-01`.
  final String month;
  final String fromId;
  final String toId;
  final int amountMinor;
  final MoveScope scope;
  final bool undone;
}

enum MoveProblem { sameCategory, notPositive, exceedsSource, wrongMonthOrScope }

/// Why a move cannot be made, or null when it can. [plannedMinor] is what
/// the source category has to give right now (its planned amount with moves
/// already applied).
MoveProblem? checkMove({
  required String fromId,
  required String toId,
  required int amountMinor,
  required int sourcePlannedMinor,
}) {
  if (fromId == toId) return MoveProblem.sameCategory;
  if (amountMinor <= 0) return MoveProblem.notPositive;
  if (amountMinor > sourcePlannedMinor) return MoveProblem.exceedsSource;
  return null;
}

Iterable<BudgetMove> activeMoves(
  Iterable<BudgetMove> moves, {
  required String month,
  required MoveScope scope,
}) => moves.where((m) => !m.undone && m.month == month && m.scope == scope);

/// Net change per category from the moves of [month] and [scope].
Map<String, int> moveDeltas(
  Iterable<BudgetMove> moves, {
  required String month,
  required MoveScope scope,
}) {
  final d = <String, int>{};
  for (final m in activeMoves(moves, month: month, scope: scope)) {
    d[m.fromId] = (d[m.fromId] ?? 0) - m.amountMinor;
    d[m.toId] = (d[m.toId] ?? 0) + m.amountMinor;
  }
  return d;
}

/// [planned] with the month's moves applied. The sum is unchanged.
Map<String, int> applyMoves(
  Map<String, int> planned,
  Iterable<BudgetMove> moves, {
  required String month,
  required MoveScope scope,
}) {
  final out = {...planned};
  moveDeltas(
    moves,
    month: month,
    scope: scope,
  ).forEach((k, v) => out[k] = (out[k] ?? 0) + v);
  return out;
}

/// Categories with room to give, most spare first: planned (moves applied)
/// minus spent, above zero. Used to pre-pick the "from" of an overspend fix.
List<(String, int)> spareMoney(
  Map<String, int> plannedAfterMoves,
  Map<String, int> spent, {
  String? except,
}) {
  final out = <(String, int)>[];
  plannedAfterMoves.forEach((id, p) {
    if (id == except) return;
    final spare = p - (spent[id] ?? 0);
    if (spare > 0) out.add((id, spare));
  });
  out.sort(
    (a, b) => b.$2 != a.$2 ? b.$2.compareTo(a.$2) : a.$1.compareTo(b.$1),
  );
  return out;
}
