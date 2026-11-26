import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/learning/learning_controller.dart';
import 'package:pulse/core/learning/merchant_memory.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/transactions/tx_detail_sheet.dart';

Transaction _tx({required bool learned}) => Transaction(
  id: 't1',
  merchant: 'Zed Corner Shop',
  amount: 40,
  category: SpendCategory.groceries,
  date: DateTime(2026, 11, 1, 9),
  source: TxSource.sms,
  cardId: 'c',
  accountLabel: 'Card',
  learned: learned,
);

Future<MerchantMemory> _pump(
  WidgetTester t,
  Transaction tx,
  Brightness b,
  double scale,
) async {
  PulseTheme.useGoogleFonts = false;
  t.view.physicalSize = const Size(360 * 3, 800 * 3);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final memory = MerchantMemory(MemoryKvStore());
  await memory.confirm('Zed Corner Shop', 'groceries', weight: fixWeight);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(
          MockPulseRepository(latency: Duration.zero),
        ),
        merchantMemoryProvider.overrideWithValue(memory),
      ],
      child: MaterialApp(
        theme: b == Brightness.dark ? PulseTheme.dark : PulseTheme.light,
        builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: w!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(child: TxDetailSheet(tx: tx)),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return memory;
}

void main() {
  for (final b in Brightness.values) {
    testWidgets(
      'learned row shows and Forget works (${b.name}, 360px, 1.5x text)',
      (t) async {
        final memory = await _pump(t, _tx(learned: true), b, 1.5);
        expect(find.byKey(const Key('tx_learned_row')), findsOneWidget);
        expect(find.text('Learned from your choice'), findsOneWidget);
        expect(t.takeException(), isNull);
        expect(memory.lookup('Zed Corner Shop'), isNotNull);
        await t.ensureVisible(find.byKey(const Key('tx_learned_forget')));
        await t.tap(find.byKey(const Key('tx_learned_forget')));
        await t.pumpAndSettle();
        expect(memory.lookup('Zed Corner Shop'), isNull);
        expect(find.byKey(const Key('tx_learned_row')), findsNothing);
      },
    );
  }

  testWidgets('no learned row on an ordinary payment', (t) async {
    await _pump(t, _tx(learned: false), Brightness.light, 1);
    expect(find.byKey(const Key('tx_learned_row')), findsNothing);
  });
}
