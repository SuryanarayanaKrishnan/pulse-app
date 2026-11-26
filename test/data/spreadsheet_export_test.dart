import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/spreadsheet_export.dart';

void main() {
  test('every payment field reaches the sheet, newest first, pending holds marked', () {
    final t = transactionsTable([
      Transaction(
        id: 'a',
        merchant: 'Spinneys',
        amount: 120.5,
        category: const SpendCategory('groceries', 'Groceries'),
        date: DateTime(2026, 11, 20),
        source: TxSource.sms,
        cardId: 'c1',
        accountLabel: 'ENBD Go4it',
      ),
      Transaction(
        id: 'b',
        merchant: 'Regeny EV charging',
        amount: 100,
        category: const SpendCategory('transport', 'Transport'),
        date: DateTime(2026, 11, 25),
        source: TxSource.applePayShortcut,
        cardId: 'c1',
        accountLabel: 'ENBD Go4it',
        excluded: true,
        pendingHold: true,
        reviewed: false,
      ),
    ]);
    expect(t.rows.first.length, 11);
    expect(t.rows[1][1], 'Regeny EV charging');
    expect(t.rows[1].sublist(3, 5), [100.0, 'Expense']);
    expect(t.rows[1].sublist(7, 10), ['No', 'Yes', 'Yes']);
    expect(t.rows[2][0], '2026-11-20');
    expect(t.rows[2][3], 120.5);
  });
}
