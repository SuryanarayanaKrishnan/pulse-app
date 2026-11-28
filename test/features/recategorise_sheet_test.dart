import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/transactions/recategorise_sheet.dart';

class _Rec implements Analytics {
  final events = <AnalyticsEvent>[];
  @override
  void track(AnalyticsEvent e) => events.add(e);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

late MockPulseRepository _repo;
late _Rec _rec;
late Transaction _tx;

Future<void> _pump(WidgetTester t) async {
  PulseTheme.useGoogleFonts = false;
  _repo = MockPulseRepository(latency: Duration.zero);
  _rec = _Rec();
  _tx = (await _repo.transactions()).firstWhere((x) => x.merchant == 'Talabat');
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(_repo),
        analyticsProvider.overrideWithValue(_rec),
      ],
      child: MaterialApp(
        theme: PulseTheme.light,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => recategoriseWithScope(
                context,
                ref,
                tx: _tx,
                to: SpendCategory.shopping,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('go'));
  await t.pumpAndSettle();
}

Future<int> _inShopping() async => (await _repo.transactions())
    .where(
      (x) => x.merchant == 'Talabat' && x.category == SpendCategory.shopping,
    )
    .length;

void main() {
  testWidgets('shows three choices and how many past ones would change', (
    t,
  ) async {
    await _pump(t);
    expect(find.text('Just this one'), findsOneWidget);
    expect(find.text('All future from Talabat'), findsOneWidget);
    expect(find.text('All past and future from Talabat'), findsOneWidget);
    expect(
      find.textContaining('earlier transactions will change'),
      findsOneWidget,
    );
  });

  testWidgets('past and future changes history, then Undo reverts it', (
    t,
  ) async {
    await _pump(t);
    final rulesBefore = (await _repo.rules()).length;
    await t.tap(find.text('All past and future from Talabat'));
    await t.pump();
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    expect(await _inShopping(), greaterThan(1));
    expect((await _repo.rules()).length, rulesBefore + 1);
    expect(_rec.events.map((e) => e.name), contains('recategorise_scope'));
    expect(
      _rec.events.firstWhere((e) => e.name == 'recategorise_scope').properties,
      {'scope': 'all'},
    );

    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(await _inShopping(), 0);
    expect((await _repo.rules()).length, rulesBefore);
  });

  testWidgets('just this one changes a single transaction with no Undo', (
    t,
  ) async {
    await _pump(t);
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();
    expect(await _inShopping(), 1);
    expect(find.text('Undo'), findsNothing);
    expect(
      _rec.events.firstWhere((e) => e.name == 'recategorise_scope').properties,
      {'scope': 'once'},
    );
  });
}
