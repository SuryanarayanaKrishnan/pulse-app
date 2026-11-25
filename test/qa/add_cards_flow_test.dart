import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

/// Ease of use: a person with three cards adds them in one sheet, with no
/// last-four digits required, instead of three trips through the form.
void main() {
  testWidgets('tick three cards and add them together', (tester) async {
    final app = await launchApp(tester, data: QaData.empty, location: '/cards');
    final db = app.db!;
    expect(await app.real(() => db.select(db.accounts).get()), isEmpty);

    await tester.tap(find.text('Add a card').first);
    await app.settle();
    expect(find.text('Which cards do you have?'), findsOneWidget);
    expect(find.text('Add this card'), findsNothing, reason: 'no button until something is ticked');

    final rows = find.byIcon(Icons.circle_outlined);
    expect(rows, findsWidgets);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.circle_outlined).first, warnIfMissed: false);
      await app.settle(2);
    }
    expect(find.text('Add 3 cards'), findsOneWidget);
    await tester.ensureVisible(find.text('Add 3 cards'));
    await tester.tap(find.text('Add 3 cards'), warnIfMissed: false);
    await app.settle(10);

    final saved = await app.real(() => db.select(db.accounts).get());
    expect(saved.length, 3);
    expect(saved.every((a) => a.last4 == null), isTrue, reason: 'last four stay optional');
    expect(find.text('Which cards do you have?'), findsNothing, reason: 'sheet closed');
    expect(tester.takeException(), isNull);
    await shutDown(tester);
  });

  testWidgets('a single card can still be added with details', (tester) async {
    final app = await launchApp(tester, data: QaData.empty, location: '/cards');
    await tester.tap(find.text('Add a card').first);
    await app.settle();
    await tester.tap(find.byIcon(Icons.circle_outlined).first, warnIfMissed: false);
    await app.settle(2);
    expect(find.text('Add this card'), findsOneWidget);
    await tester.ensureVisible(find.text('Add with details'));
    await tester.tap(find.text('Add with details'), warnIfMissed: false);
    await app.settle();
    await tester.enterText(find.byType(TextField).first, '4321');
    await app.settle(2);
    await tester.tap(find.text('Add card').last, warnIfMissed: false);
    await app.settle(10);
    final saved = await app.real(() => app.db!.select(app.db!.accounts).get());
    expect(saved.single.last4, '4321');
    expect(tester.takeException(), isNull);
    await shutDown(tester);
  });
}
