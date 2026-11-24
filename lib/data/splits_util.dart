import 'models.dart';

/// A single "from pays to" settlement.
class Settlement {
  const Settlement(this.from, this.to, this.amount);
  final String from;
  final String to;
  final double amount;
}

/// Net balance per member id: positive = is owed, negative = owes.
///
/// Only [SettlementStatus.confirmed] settlements move balances; a payment the
/// payee has not confirmed yet is shown as a status, not netted off.
Map<String, double> computeBalances(
  List<SplitExpense> expenses,
  List<Member> members, {
  List<SettlementRecord> settlements = const [],
}) {
  final bal = {for (final m in members) m.id: 0.0};
  for (final s in settlements) {
    if (s.status != SettlementStatus.confirmed) continue;
    bal[s.from] = (bal[s.from] ?? 0) + s.amount;
    bal[s.to] = (bal[s.to] ?? 0) - s.amount;
  }
  for (final e in expenses) {
    bal[e.paidBy] = (bal[e.paidBy] ?? 0) + e.amount;
    if (e.shares != null) {
      e.shares!.forEach((id, s) => bal[id] = (bal[id] ?? 0) - s);
    } else if (e.participants.isNotEmpty) {
      final share = e.amount / e.participants.length;
      for (final id in e.participants) {
        bal[id] = (bal[id] ?? 0) - share;
      }
    }
  }
  return bal.map((k, v) => MapEntry(k, (v * 100).round() / 100));
}

/// Greedy minimal-transfer settle-up plan.
List<Settlement> simplifyDebts(Map<String, double> balances) {
  final debtors =
      balances.entries
          .where((e) => e.value < -0.005)
          .map((e) => [e.key, -e.value])
          .toList()
        ..sort((a, b) => (b[1] as double).compareTo(a[1] as double));
  final creditors =
      balances.entries
          .where((e) => e.value > 0.005)
          .map((e) => [e.key, e.value])
          .toList()
        ..sort((a, b) => (b[1] as double).compareTo(a[1] as double));
  final out = <Settlement>[];
  var i = 0, j = 0;
  while (i < debtors.length && j < creditors.length) {
    final d = debtors[i], c = creditors[j];
    final pay = (d[1] as double) < (c[1] as double)
        ? d[1] as double
        : c[1] as double;
    out.add(
      Settlement(d[0] as String, c[0] as String, (pay * 100).round() / 100),
    );
    d[1] = (d[1] as double) - pay;
    c[1] = (c[1] as double) - pay;
    if ((d[1] as double) < 0.005) i++;
    if ((c[1] as double) < 0.005) j++;
  }
  return out;
}

/// Balances for a whole group, including confirmed settlements.
Map<String, double> groupBalances(SplitGroup g) =>
    computeBalances(g.expenses, g.members, settlements: g.settlements);

/// The settlement awaiting confirmation between [from] and [to], if any.
SettlementRecord? pendingSettlement(SplitGroup g, String from, String to) {
  for (final s in g.settlements) {
    if (s.from == from &&
        s.to == to &&
        s.status == SettlementStatus.awaitingConfirmation) {
      return s;
    }
  }
  return null;
}

/// Your net position across groups: (owed to you, you owe).
(double owed, double owe) myTotals(List<SplitGroup> groups) {
  var owed = 0.0, owe = 0.0;
  for (final g in groups) {
    final v = groupBalances(g)['me'] ?? 0;
    if (v > 0) {
      owed += v;
    } else {
      owe -= v;
    }
  }
  return (owed, owe);
}
