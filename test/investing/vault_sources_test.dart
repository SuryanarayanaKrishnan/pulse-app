import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/investing.dart';
import 'package:pulse/core/vault/vault_models.dart';
import 'package:pulse/data/vault_service.dart';
import 'package:pulse/data/wealth_models.dart';

void main() {
  test('documents and standing buys reach the family vault suggestions', () {
    final s = sourcesFrom(
      VaultSourceData(
        documents: [
          WealthDocument(
            id: 'd1',
            title: 'Marina flat title deed',
            category: DocCategory.titleDeed,
            createdAt: DateTime(2026),
          ),
          WealthDocument(
            id: 'd2',
            title: 'Gold bill, Joyalukkas',
            category: DocCategory.other,
            createdAt: DateTime(2026),
          ),
        ],
        rules: const [
          InvestRule(
            id: 'r1',
            symbol: 'VOO',
            amountMinor: 20000,
            currency: 'USD',
            day: 5,
            startDate: CalDate(2026, 11, 1),
          ),
          InvestRule(
            id: 'r2',
            symbol: 'MF:f1',
            name: 'Parag Parikh Flexi Cap Fund',
            amountMinor: 500000,
            currency: 'INR',
            day: 7,
            startDate: CalDate(2026, 11, 1),
          ),
        ],
      ),
    );
    final byRef = {for (final x in s) x.ref: x};
    expect(byRef['doc:d1']!.type, VaultType.property);
    expect(byRef['doc:d2']!.type, VaultType.documents);
    expect(byRef['rule:r1']!.type, VaultType.investment);
    expect(byRef['rule:r1']!.institution, 'VOO');
    expect(byRef['rule:r1']!.title, contains('USD 200'));
    expect(byRef['rule:r2']!.institution, 'Parag Parikh Flexi Cap Fund');
    expect(byRef['rule:r2']!.title, contains('INR 5000'));
  });
}
