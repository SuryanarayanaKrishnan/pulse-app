// Synthetic ledger for the Recurring, Reports and net worth screens. Every
// name here is made up.
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/recurring.dart' show addMonths;
import 'package:pulse/data/models.dart';

/// "Today" for the fixtures: mid-November 2026.
const fixtureToday = CalDate(2026, 11, 14);

Transaction _tx(
  String id,
  String merchant,
  double amount,
  SpendCategory cat,
  CalDate d, {
  bool income = false,
}) => Transaction(
  id: id,
  merchant: merchant,
  amount: amount,
  category: cat,
  date: DateTime(d.year, d.month, d.day, 9),
  source: TxSource.manual,
  cardId: 'fixture',
  accountLabel: 'Test account',
  isIncome: income,
);

/// Monthly charges: [n] of them, the last in (year, month), on [day].
Iterable<CalDate> _monthly(
  int n,
  int day, {
  int year = 2026,
  int month = 10,
}) sync* {
  for (var i = n - 1; i >= 0; i--) {
    final idx = year * 12 + month - 1 - i;
    yield addMonths(CalDate(idx ~/ 12, idx % 12 + 1, 1), 0, day);
  }
}

/// A year of plausible, made-up spending with a handful of recurring series:
///  - Streamly, a TV subscription, paid on the 3rd (paid this month);
///  - Harbour Rent, paid on the 1st (paid this month);
///  - Veg Box, weekly on Mondays (some paid, three still to come);
///  - Cloudbox Storage, 22nd, raised from 12 to 15 in October (price hint);
///  - Powergrid, a variable utility due on the 10th and not seen yet (overdue);
///  - FitBox Gym, 28th (upcoming);
///  - Annual Pass, yearly on 26 November (upcoming).
List<Transaction> syntheticLedger() {
  final out = <Transaction>[];
  var n = 0;
  String id() => 'f${n++}';
  for (final d in _monthly(6, 3, month: 11)) {
    out.add(_tx(id(), 'Streamly', 39, SpendCategory.entertainment, d));
  }
  for (final d in _monthly(6, 1, month: 11)) {
    out.add(_tx(id(), 'Harbour Rent', 6250, SpendCategory.rent, d));
  }
  var w = const CalDate(2026, 9, 21);
  while (w <= const CalDate(2026, 11, 9)) {
    out.add(_tx(id(), 'Veg Box', 45, SpendCategory.groceries, w));
    w = w.addDays(7);
  }
  final cloud = [12.0, 12.0, 12.0, 12.0, 15.0];
  for (final (i, d) in _monthly(5, 22).indexed) {
    out.add(_tx(id(), 'Cloudbox Storage', cloud[i], SpendCategory.shopping, d));
  }
  final power = [410.0, 380.0, 455.0, 620.0, 590.0, 505.0];
  for (final (i, d) in _monthly(6, 10).indexed) {
    out.add(_tx(id(), 'Powergrid', power[i], SpendCategory.utilities, d));
  }
  for (final d in _monthly(6, 28)) {
    out.add(_tx(id(), 'FitBox Gym', 349, SpendCategory.health, d));
  }
  out.add(
    _tx(
      id(),
      'Annual Pass',
      365,
      SpendCategory.entertainment,
      const CalDate(2024, 11, 26),
    ),
  );
  out.add(
    _tx(
      id(),
      'Annual Pass',
      365,
      SpendCategory.entertainment,
      const CalDate(2025, 11, 26),
    ),
  );
  // Not recurring: irregular visits and one-offs.
  const odd = [
    CalDate(2026, 8, 4),
    CalDate(2026, 8, 19),
    CalDate(2026, 9, 30),
    CalDate(2026, 10, 17),
    CalDate(2026, 11, 8),
  ];
  for (final (i, d) in odd.indexed) {
    out.add(_tx(id(), 'Corner Cafe', 22.0 + i * 7, SpendCategory.dining, d));
    out.add(
      _tx(
        id(),
        'Market Hall',
        180.0 + i * 31,
        SpendCategory.groceries,
        d.addDays(2),
      ),
    );
  }
  out.add(
    _tx(
      id(),
      'Gadget Shop',
      899,
      SpendCategory.shopping,
      const CalDate(2026, 11, 5),
    ),
  );
  out.add(
    _tx(
      id(),
      'Weekend Away',
      1450,
      SpendCategory.travel,
      const CalDate(2026, 10, 12),
    ),
  );
  out.add(
    _tx(
      id(),
      'Employer',
      28000,
      SpendCategory.salary,
      const CalDate(2026, 11, 1),
      income: true,
    ),
  );
  return out;
}
