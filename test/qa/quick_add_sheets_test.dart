import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/transactions/tx_detail_sheet.dart';
import 'package:pulse/features/wallet/add_sheets.dart';

class _Spy extends MockPulseRepository {
  _Spy() : super(latency: Duration.zero);
  final calls = <String>[];
  @override
  Future<Transaction> addManualTransaction({required String merchant, required double amount, required SpendCategory category}) {
    calls.add('tx $merchant $amount ${category.id}');
    return super.addManualTransaction(merchant: merchant, amount: amount, category: category);
  }

  @override
  Future<Asset> addAsset({required String name, required AssetKind kind, required double value}) async {
    calls.add('asset $name ${kind.name} $value');
    return Asset(id: 'x', name: name, kind: kind, value: value);
  }

  @override
  Future<BankAccount> addBankAccount({required String bank, required String name, required BankAccountKind kind, String? last4, double balance = 0}) async {
    calls.add('account $bank $name ${kind.name} $balance');
    return (await bankAccounts()).first;
  }
}

Future<_Spy> _open(WidgetTester tester, Widget sheet) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final spy = _Spy();
  await tester.pumpWidget(ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(spy), analyticsProvider.overrideWithValue(NoopAnalytics())],
    child: MaterialApp(theme: PulseTheme.light, home: Scaffold(body: sheet)),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  return spy;
}

bool _enabled(WidgetTester tester, String label) {
  final b = find.widgetWithText(InkWell, label);
  return b.evaluate().isNotEmpty || find.text(label).evaluate().isNotEmpty;
}

void main() {
  testWidgets('cash expense: amount, one category tap, save (note optional)', (tester) async {
    final spy = await _open(tester, const AddManualTxSheet());
    await tester.tap(find.text('Save'), warnIfMissed: false);
    await tester.pump();
    expect(spy.calls, isEmpty, reason: 'Save does nothing without an amount');
    await tester.enterText(find.byType(TextField).first, '25');
    await tester.pump();
    await tester.tap(find.text('Groceries'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(spy.calls, ['tx Groceries 25.0 groceries']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cash expense rejects zero, negative and infinite amounts', (tester) async {
    final spy = await _open(tester, const AddManualTxSheet());
    for (final bad in ['0', '-5', 'abc', 'Infinity', 'NaN']) {
      await tester.enterText(find.byType(TextField).first, bad);
      await tester.pump();
      await tester.tap(find.text('Save'), warnIfMissed: false);
      await tester.pump();
    }
    expect(spy.calls, isEmpty);
  });

  testWidgets('asset: value alone is enough, name defaults to the kind', (tester) async {
    final spy = await _open(tester, const AddAssetSheet());
    await tester.tap(find.text('Gold'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '5,000');
    await tester.pump();
    await tester.tap(find.text('Add'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(spy.calls, ['asset Gold gold 5000.0']);
  });

  testWidgets('account: tap a bank chip, enter balance, add', (tester) async {
    final spy = await _open(tester, const AddAccountSheet());
    await tester.tap(find.text('Mashreq'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '1200');
    await tester.pump();
    await tester.tap(find.text('Add account'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(spy.calls.single, startsWith('account Mashreq'));
    expect(_enabled(tester, 'Add account'), isTrue);
  });
}
