import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/due_notice.dart';

void main() {
  const body =
      'Your Tabby Card payment is due in 9 days 24 Oct - 23 Nov . Due on 3 '
      'December A no-fee minimum amount of 1,234.50 will be automatically '
      'deducted. 2,000.00 statement amount';

  test('reads due date, minimum and statement amount', () {
    final n = parseTabbyCardDue(body, receivedAt: DateTime(2026, 11, 24))!;
    expect(n.dueDate, DateTime(2026, 12, 3));
    expect(n.minDueMinor, 123450);
    expect(n.statementMinor, 200000);
  });

  test('rolls into next year and rejects non-notices', () {
    final n = parseTabbyCardDue(
      body.replaceAll('3 December', '5 January'),
      receivedAt: DateTime(2026, 12, 28),
    )!;
    expect(n.dueDate, DateTime(2027, 1, 5));
    expect(
      parseTabbyCardDue(
        'Low Tabby Card balance?',
        receivedAt: DateTime(2026, 11, 24),
      ),
      isNull,
    );
  });
}
