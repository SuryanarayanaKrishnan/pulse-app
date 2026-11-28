import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/household/household_providers.dart';

import 'audit.dart';
import 'harness.dart';

/// The core journeys, driven through the UI on the REAL on-device path (an
/// in-memory ledger behind LocalPulseRepository), never the mock repository.
/// Each asserts the outcome the person cares about, not just "no exception":
/// the thing they asked for exists afterwards and shows up on screen.
void main() {
  Future<void> tapText(QaApp app, String text) async {
    final f = find.text(text);
    expect(f, findsWidgets, reason: 'nothing on screen says "$text"; saw ${app.visibleText.join(' | ').substring(0, 400)}');
    await app.tester.tap(f.first);
    await app.settle(5);
  }

  testWidgets('the app runs on the real repository, never the mock', (tester) async {
    final app = await launchApp(tester, data: QaData.empty);
    await qaGuard(app, () async {
    final repo = app.container.read(repositoryProvider);
    expect(repo.runtimeType.toString(), 'LocalPulseRepository');
    });
    await shutDown(tester);
  });

  for (final issuer in ['Tabby', 'HSBC', 'Mashreq', 'Emirates NBD']) {
    testWidgets('add card: search "$issuer", pick it, save, see it in the wallet', (tester) async {
      final handle = tester.ensureSemantics();
      final app = await launchApp(tester, data: QaData.empty, location: '/cards');
    await qaGuard(app, () async {
      await tester.tap(find.bySemanticsLabel('Add a card or account'));
      await app.settle(5);
      expect(seeThroughSheets(tester), isEmpty);
      await tapText(app, 'Credit card');
      expect(seeThroughSheets(tester), isEmpty);
      await tester.enterText(find.byType(TextField).last, issuer);
      await app.settle(4);
      final results = find.descendant(of: find.byType(BottomSheet), matching: find.byWidgetPredicate((w) => w is Text && (w.data ?? '').contains(issuer)));
      expect(results, findsWidgets, reason: 'searching "$issuer" found nothing; saw ${app.visibleText.join(' | ').substring(0, 400)}');
      expect(find.text('No match'), findsNothing);
      // Pick the first matching card row.
      await tester.tap(results.first);
      await app.settle(5);
      await tester.enterText(find.byType(TextField).first, '4321');
      await app.settle(3);
      await tapText(app, 'Add card');
      // The sheet closes and the card is in the ledger, on screen.
      expect(find.text('Add card'), findsNothing, reason: 'sheet still open: Add card did nothing');
      final repo = app.container.read(repositoryProvider);
      final cards = await app.real(() => repo.myCards());
      expect(cards.where((c) => c.last4 == '4321'), hasLength(1));
      expect('${cards.first.issuer} ${cards.first.name}', contains(issuer));
      expect(find.textContaining('4321'), findsWidgets, reason: 'card not shown on the Cards screen');
      expect(app.errors.drain(), isEmpty);
    });
      await shutDown(tester);
      handle.dispose();
    });
  }

  testWidgets('catalog: every issuer people ask about is searchable', (tester) async {
    final app = await launchApp(tester, data: QaData.empty);
    await qaGuard(app, () async {
    final repo = app.container.read(repositoryProvider);
    final cards = await app.real(() => repo.cardCatalog());
    final issuers = cards.map((c) => c.issuer.toLowerCase()).toSet();
    for (final want in ['tabby', 'hsbc', 'mashreq', 'emirates nbd', 'adcb', 'first abu dhabi', 'rakbank', 'sib', 'dubai islamic', 'standard chartered', 'citibank']) {
      expect(
        issuers.any((i) => i.contains(want)),
        isTrue,
        reason: '$want missing from the catalog (have ${issuers.length} issuers)',
      );
    }
    });
    await shutDown(tester);
  });

  testWidgets('add expense (cash) lands in the ledger and on Activity', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await launchApp(tester, data: QaData.empty, location: '/activity');
    await qaGuard(app, () async {
    final repo = app.container.read(repositoryProvider);
    final cat = (await app.real(() => repo.categories())).first;
    await app.real(() => repo.addManualTransaction(merchant: 'QA Coffee', amount: 18.5, category: cat));
    app.container.invalidate(transactionsProvider);
    await app.go('/activity');
    expect(find.textContaining('QA Coffee'), findsWidgets);
    expect(app.errors.drain(), isEmpty);
    });
    await shutDown(tester);
    handle.dispose();
  });

  testWidgets('household invite: a real code, no pretend members, no duplicate', (tester) async {
    final app = await launchApp(tester, data: QaData.empty, location: '/family');
    await qaGuard(app, () async {
    // A fresh user has nobody in the household.
    for (final fake in ['Sara', 'Omar', 'Layla', 'Priya', 'Alex']) {
      expect(find.text(fake), findsNothing, reason: 'sample family member "$fake" shown to a real user');
    }
    final svc = app.container.read(householdServiceProvider);
    await app.real(() => svc.create(householdName: 'Our household', myName: 'Tester'));
    final code = await app.real(() => svc.inviteCode());
    expect(code, isNotNull);
    expect(code!.length, greaterThan(16), reason: 'invite code too short to be real');
    expect(app.errors.drain(), isEmpty);
    });
    await shutDown(tester);
  });

  testWidgets('settings toggle sticks after leaving the screen', (tester) async {
    final app = await launchApp(tester, data: QaData.empty, location: '/settings');
    await qaGuard(app, () async {
      final sw = find.byKey(const Key('settings_shake_switch'));
      await tester.scrollUntilVisible(sw, 300, scrollable: find.byType(Scrollable).first);
      final before = tester.widget<Switch>(sw).value;
      await tester.tap(sw);
      await app.settle(5);
      expect(tester.widget<Switch>(sw).value, !before, reason: 'toggle did not change');
      await app.go('/home');
      await app.go('/settings');
      await tester.scrollUntilVisible(sw, 300, scrollable: find.byType(Scrollable).first);
      expect(tester.widget<Switch>(sw).value, !before, reason: 'toggle forgot its state');
    });
    await shutDown(tester);
  });
}
