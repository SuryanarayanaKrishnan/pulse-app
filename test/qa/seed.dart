import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';

import 'harness.dart';

/// What a real tester's phone looks like a week in: three cards, an account,
/// some assets and a spread of spending, all written through the same
/// repository the UI uses (the on-device one, not the mock).
Future<void> seedTypical(QaApp app) async {
  final repo = app.container.read(repositoryProvider);
  await app.real(() async {
    final catalog = await repo.cardCatalog();
    CreditCard pick(String issuer, [String? name]) => catalog.firstWhere(
      (c) =>
          c.issuer.toLowerCase().contains(issuer) &&
          (name == null || c.name.toLowerCase().contains(name)),
      orElse: () => catalog.first,
    );
    var n = 0;
    for (final (c, limit, owed) in [
      (pick('first abu dhabi', 'cashback'), 30000.0, 4200.0),
      (pick('mashreq', 'cashback'), 20000.0, 1250.0),
      (pick('emirates nbd', 'skywards'), 45000.0, 9800.0),
    ]) {
      await repo.addCard(
        catalogId: c.id,
        last4: '${6600 + n++}',
        limit: limit,
        owed: owed,
        statementDay: 12,
        dueDay: 5,
      );
    }
    await repo.addBankAccount(
      bank: 'Mashreq',
      name: 'Neo',
      kind: BankAccountKind.current,
      balance: 14250,
    );
    await repo.addAsset(name: 'Gold', kind: AssetKind.values.firstWhere((k) => k.name == 'gold'), value: 18000);
    await repo.addAsset(name: 'Fixed deposit', kind: AssetKind.fixedDeposit, value: 50000);
    final cats = await repo.categories();
    SpendCategory cat(String id) => cats.firstWhere((c) => c.id == id, orElse: () => cats.first);
    for (final (m, a, c) in [
      ('Carrefour', 312.4, 'groceries'),
      ('Talabat', 64.0, 'dining'),
      ('Careem', 28.5, 'transport'),
      ('DEWA', 540.0, 'utilities'),
      ('Noon', 219.0, 'shopping'),
      ('Starbucks', 24.0, 'dining'),
      ('ADNOC', 150.0, 'transport'),
      ('Netflix', 55.0, 'entertainment'),
    ]) {
      await repo.addManualTransaction(merchant: m, amount: a, category: cat(c));
    }
  });
  // Everything that read the repository before the seed reads it again.
  app.container.invalidate(repositoryProvider);
  await app.settle(8);
}
