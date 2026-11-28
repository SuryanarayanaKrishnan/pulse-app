import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/review/review_screen.dart';

/// A card bill payment waiting in the review queue: one tap each way, never a
/// category picker.
void main() {
  late MockPulseRepository repo;
  final card = find.byKey(const ValueKey('review-card'));

  Future<void> pump(WidgetTester t) async {
    PulseTheme.useGoogleFonts = false;
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (c) async => null,
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    repo = MockPulseRepository(latency: Duration.zero)
      ..seedTransaction(
        Transaction(
          id: 'bill',
          merchant: 'Tabby',
          amount: 9999,
          category: SpendCategory.cardPayments,
          date: DateTime(2026, 11, 28, 9),
          source: TxSource.sms,
          cardId: 'enbd-sky',
          accountLabel: 'SIB Cashback ····1111',
          excluded: true,
          reviewed: false,
          confidence: 0.2,
          transferKind: 'card_bill',
        ),
      );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repo),
          kvStoreProvider.overrideWithValue(MemoryKvStore()),
        ],
        child: MaterialApp(theme: PulseTheme.light, home: const ReviewScreen()),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<Transaction> bill() async =>
      (await repo.transactions()).firstWhere((x) => x.id == 'bill');

  testWidgets('it comes first and says it is not counted as spending', (
    t,
  ) async {
    await pump(t);
    expect(
      find.descendant(of: card, matching: find.text('Tabby')),
      findsOneWidget,
    );
    expect(find.textContaining('Not counted as spending'), findsOneWidget);
    expect(find.text('Yes, a transfer'), findsOneWidget);
    expect(find.text('Not a transfer'), findsOneWidget);
    expect(find.text('Looks right'), findsNothing);
  });

  testWidgets('Yes keeps it out of spending, reviewed, no popup', (t) async {
    await pump(t);
    await t.tap(find.text('Yes, a transfer'));
    await t.pumpAndSettle();
    final b = await bill();
    expect(b.reviewed, isTrue);
    expect(b.isOwnTransfer, isTrue);
    expect(b.excluded, isTrue);
    expect(find.text('Fix category'), findsNothing);
  });

  testWidgets('Not a transfer is one tap and counts it as spending', (t) async {
    await pump(t);
    await t.tap(find.text('Not a transfer'));
    await t.pumpAndSettle();
    final b = await bill();
    expect(b.reviewed, isTrue);
    expect(b.isOwnTransfer, isFalse);
    // No category picker, no scope sheet.
    expect(find.text('Fix category'), findsNothing);
  });

  testWidgets('swiping left on it is the same as Not a transfer', (t) async {
    await pump(t);
    await t.drag(card, const Offset(-320, 0));
    await t.pumpAndSettle();
    expect(find.text('Fix category'), findsNothing);
    expect((await bill()).isOwnTransfer, isFalse);
  });
}
