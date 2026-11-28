import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/local/splits_store.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/splits/splits_screen.dart';

Future<void> _pump(
  WidgetTester t,
  MockPulseRepository repo,
  SplitGroup g, {
  Transaction? tx,
}) async {
  PulseTheme.useGoogleFonts = false;
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: PulseTheme.light,
        home: Scaffold(
          body: AddSplitSheet(groups: [g], initial: g, fromTransaction: tx),
        ),
      ),
    ),
  );
  await t.pump();
}

void main() {
  testWidgets('splitting a payment prefills it and links the split', (t) async {
    final repo = MockPulseRepository(latency: Duration.zero, seedGroups: false);
    final g = await repo.createSplitGroup(
      name: 'Flat',
      members: const [NewGroupMember(name: 'Ali')],
    );
    final tx = Transaction(
      id: 'tx1',
      merchant: 'Noon Minutes',
      amount: 84.5,
      category: SpendCategory.other,
      date: DateTime(2026, 3, 1),
      source: TxSource.manual,
      cardId: '',
      accountLabel: 'Cash',
    );
    await _pump(t, repo, g, tx: tx);
    expect(find.text('Noon Minutes'), findsOneWidget);
    expect(find.text('84.50'), findsOneWidget);
    // You are the payer: no picker.
    expect(find.byKey(const Key('paid-by')), findsNothing);

    await t.tap(find.text('Add expense').last);
    await t.pump();
    await t.pump();
    final e = (await repo.splitGroups()).single.expenses.single;
    expect(e.transactionId, 'tx1');
    expect(e.paidBy, 'me');
    expect(e.amount, 84.5);
    expect(e.linkedTransactionId, 'tx1');
  });

  testWidgets('typing it by hand still works and can name another payer', (
    t,
  ) async {
    final repo = MockPulseRepository(latency: Duration.zero, seedGroups: false);
    final g = await repo.createSplitGroup(
      name: 'Trip',
      members: const [NewGroupMember(name: 'Sara')],
    );
    await _pump(t, repo, g);
    expect(find.byKey(const Key('paid-by')), findsOneWidget);
    await t.tap(
      find.descendant(
        of: find.byKey(const Key('paid-by')),
        matching: find.text('Sara'),
      ),
    );
    await t.pump();
    expect(find.textContaining('Someone else paid'), findsOneWidget);
    await t.enterText(find.byType(TextField).at(0), 'Hotel');
    await t.enterText(find.byType(TextField).at(1), '300');
    await t.tap(find.text('Add expense').last);
    await t.pump();
    await t.pump();
    final e = (await repo.splitGroups()).single.expenses.single;
    expect(e.paidBy, g.members.last.id);
    expect(e.transactionId, isNull);
    expect(e.linkedTransactionId, 'split_${e.id}');
  });
}
