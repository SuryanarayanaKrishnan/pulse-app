import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/features/transactions/tx_detail_sheet.dart';

import 'household/household_widget_test.dart'
    show Rig, pumpApp, pumpWidgetUnderTest, reveal;

Transaction _tx({String? notes, String? ref}) => Transaction(
  id: 't1',
  merchant: 'Talabat Mart',
  amount: 74,
  category: SpendCategory.groceries,
  date: DateTime(2026, 3, 14, 10),
  source: TxSource.manual,
  cardId: 'c',
  accountLabel: 'Card',
  receiptNotes: notes,
  receiptRef: ref,
);

void main() {
  testWidgets(
    'Settings > Connected sources shows Email receipts: off, explained, disabled',
    (tester) async {
      await pumpApp(tester, Rig(), '/settings');
      final row = find.byKey(const Key('settings_email_receipts'));
      await reveal(tester, row);
      expect(find.text('Connected sources'), findsOneWidget);
      expect(find.text('Email receipts'), findsOneWidget);
      expect(find.textContaining('Not available yet'), findsOneWidget);
      final sw = tester.widget<Switch>(
        find.byKey(const Key('settings_email_receipts_switch')),
      );
      expect(sw.value, isFalse);
      expect(
        sw.onChanged,
        isNull,
        reason: 'disabled until Gmail is configured',
      );
    },
  );

  testWidgets('a transaction with a matched receipt shows its item notes', (
    tester,
  ) async {
    await pumpWidgetUnderTest(
      tester,
      Rig(),
      Scaffold(
        body: SingleChildScrollView(
          child: TxDetailSheet(
            tx: _tx(
              notes:
                  '1 x Fresh Milk 2L, 2 x Eggs dozen\nDelivery fee: AED 4.00',
              ref: 'msg-1',
            ),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('tx_receipt_card')), findsOneWidget);
    expect(find.text('From your email receipt'), findsOneWidget);
    expect(find.textContaining('Fresh Milk 2L'), findsOneWidget);
    expect(find.textContaining('still your bank'), findsOneWidget);
  });

  testWidgets('a transaction without a receipt shows no receipt card', (
    tester,
  ) async {
    await pumpWidgetUnderTest(
      tester,
      Rig(),
      Scaffold(
        body: SingleChildScrollView(child: TxDetailSheet(tx: _tx())),
      ),
    );
    expect(find.byKey(const Key('tx_receipt_card')), findsNothing);
  });
}
