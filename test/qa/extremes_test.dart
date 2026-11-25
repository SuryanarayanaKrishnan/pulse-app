import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';

import 'harness.dart';

const _tabs = ['/home', '/budget', '/cards', '/splits', '/wealth'];
const _more = [
  '/activity',
  '/settings',
  '/categories',
  '/automations',
  '/statements',
  '/cards-ranked',
  '/goals',
  '/recurring',
  '/reports',
  '/review',
  '/household',
  '/family',
  '/legacy',
];

/// Everything an unusual user could have: zero, negative, huge, long and
/// right-to-left text. Written through the repository like the UI does.
Future<void> seedExtremes(QaApp app) async {
  final repo = app.container.read(repositoryProvider);
  await app.real(() async {
    final cat = (await repo.categories()).first;
    for (final (m, a) in [
      ('Zero spend', 0.0),
      ('Tiny', 0.01),
      ('Refund', -250.0),
      ('Huge purchase', 99999999999.99),
      ('Quadrillion', 1e15),
      ('مطعم الشام للمأكولات الشرقية والمشاوي', 42.5),
      (
        'A merchant name that goes on and on and on and on and on and on and on and on and on',
        12.0,
      ),
      ('Emoji 🍕🍔 shop', 33.3),
      ('', 5.0),
    ]) {
      try {
        await repo.addManualTransaction(merchant: m, amount: a, category: cat);
      } on Object {
        // Rejecting bad input is fine; crashing later is not.
      }
    }
    final cards = await repo.cardCatalog();
    var i = 0;
    for (final (limit, owed) in [
      (0.0, 0.0),
      (1000.0, 5000.0),
      (1e12, 1e11),
      (-5.0, -5.0),
    ]) {
      try {
        await repo.addCard(
          catalogId: cards[i++ % cards.length].id,
          last4: '${1000 + i}',
          limit: limit,
          owed: owed,
          statementDay: 31,
          dueDay: 0,
        );
      } on Object {
        // Rejecting bad input is fine.
      }
    }
    for (final b in [0.0, -1200.5, 1e13]) {
      try {
        await repo.addBankAccount(
          bank: 'Bank $b',
          name: 'Acct',
          kind: BankAccountKind.values.first,
          balance: b,
        );
      } on Object {
        // Rejecting bad input is fine.
      }
    }
    for (final k in AssetKind.values) {
      for (final v in [0.0, 1e14, 123.45]) {
        try {
          await repo.addAsset(name: '${k.name} $v', kind: k, value: v);
        } on Object {
          // Rejecting bad input is fine.
        }
      }
    }
  });
  for (final p in [transactionsProvider, budgetProvider]) {
    app.container.invalidate(p);
  }
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('extreme values on every screen (${dark ? "dark" : "light"})', (
      tester,
    ) async {
      final app = await launchApp(tester, data: QaData.empty, dark: dark);
      await seedExtremes(app);
      final failures = <String>[];
      for (final route in [..._tabs, ..._more]) {
        // ignore: avoid_print
        print('QA visiting $route');
        await app.go(route);
        tester.takeException();
        for (final e in app.errors.drain()) {
          failures.add('$route: $e');
        }
        if (app.visibleText.any((t) => t.contains('Something went wrong')))
          failures.add('$route shows error state');
      }
      app.errors.uninstall();
      expect(failures, isEmpty, reason: failures.join('\n'));
      await shutDown(tester);
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
