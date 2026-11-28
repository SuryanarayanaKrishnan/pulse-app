import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/card_suggestions.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';

void main() {
  final repo = MockPulseRepository(latency: Duration.zero);

  test(
    'with no spend history it suggests from a typical month and says so',
    () async {
      final catalog = await repo.cardCatalog();
      final out = suggestCards(
        catalog: catalog,
        owned: const [],
        txs: const [],
        now: DateTime(2026, 11, 25),
      );
      expect(out, isNotEmpty);
      expect(out.length, lessThanOrEqualTo(3));
      expect(out.every((s) => s.typical && s.annualGain > 0), isTrue);
      for (var i = 1; i < out.length; i++) {
        expect(out[i - 1].annualGain, greaterThanOrEqualTo(out[i].annualGain));
      }
    },
  );

  test('never suggests a card the user already holds', () async {
    final catalog = await repo.cardCatalog();
    final owned = [catalog.first];
    final out = suggestCards(
      catalog: catalog,
      owned: owned,
      txs: const [],
      now: DateTime(2026, 11, 25),
    );
    expect(out.any((s) => s.card.id == catalog.first.id), isFalse);
  });

  test('learns from spend once there are enough transactions', () async {
    final catalog = await repo.cardCatalog();
    final now = DateTime(2026, 11, 25);
    final txs = [
      for (var i = 0; i < 20; i++)
        Transaction(
          id: 't$i',
          merchant: 'Lulu',
          amount: 300,
          category: SpendCategory.groceries,
          date: now.subtract(Duration(days: i * 3)),
          source: TxSource.sms,
          cardId: 'x',
          accountLabel: 'x',
        ),
    ];
    final learned = learnedMonthlySpend(txs, now)!;
    expect(learned.keys.single, SpendCategory.groceries);
    final out = suggestCards(
      catalog: catalog,
      owned: const [],
      txs: txs,
      now: now,
    );
    expect(
      out.every((s) => !s.typical && s.topCategory == SpendCategory.groceries),
      isTrue,
    );
    expect(learnedMonthlySpend(txs.take(5).toList(), now), isNull);
  });
}
