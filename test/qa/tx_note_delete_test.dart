import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/transactions/tx_detail_sheet.dart';

void main() {
  testWidgets(
    'a payment can take a note and be deleted from its detail sheet',
    (tester) async {
      PulseTheme.useGoogleFonts = false;
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final repo = MockPulseRepository(latency: Duration.zero);
      final tx = await repo.addManualTransaction(
        merchant: 'Taxi',
        amount: 20,
        category: SpendCategory.transport,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            analyticsProvider.overrideWithValue(NoopAnalytics()),
          ],
          child: MaterialApp(
            theme: PulseTheme.light,
            home: Scaffold(body: TxDetailSheet(tx: tx)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byKey(const Key('tx_note')), 'airport run');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        (await repo.transactions()).firstWhere((t) => t.id == tx.id).note,
        'airport run',
      );

      await tester.ensureVisible(find.byKey(const Key('tx_delete')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('tx_delete')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('tx_delete_confirm')));
      await tester.pump(const Duration(milliseconds: 300));
      expect((await repo.transactions()).any((t) => t.id == tx.id), isFalse);
    },
  );
}
