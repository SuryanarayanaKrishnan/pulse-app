import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';

/// What a brand-new on-device ledger returns: nothing at all.
class _EmptyLedger extends MockPulseRepository {
  _EmptyLedger() : super(latency: Duration.zero);
  @override
  Future<List<Transaction>> transactions() async => const [];
  @override
  Future<List<CreditCard>> myCards() async => const [];
  @override
  Future<List<BankAccount>> bankAccounts() async => const [];
}

Future<void> _pump(WidgetTester tester, String location) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(_EmptyLedger()),
        analyticsProvider.overrideWithValue(NoopAnalytics()),
        sessionProvider.overrideWith(
          (ref) => SessionController(onboarded: true, signedIn: true, connected: true),
        ),
      ],
      child: PulseApp(initialLocation: location),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('an empty ledger shows a first-run prompt, not zeros', (tester) async {
    await _pump(tester, '/home');
    expect(find.text('Let us set up your money'), findsOneWidget);
    expect(find.text('Safe to spend today'), findsNothing);
    await tester.tap(find.text('Add an account or card'));
    await tester.pumpAndSettle();
    expect(find.text('Credit card'), findsOneWidget);
    expect(find.text('Bank account or wallet'), findsOneWidget);
    expect(find.text('Asset or loan'), findsOneWidget);
  });

  testWidgets('cards and accounts offer to add the first one', (tester) async {
    await _pump(tester, '/cards');
    expect(find.text('No cards yet'), findsOneWidget);
    expect(find.text('Pick your cards'), findsOneWidget);
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('No accounts yet'), findsOneWidget);
    expect(find.text('Add an account'), findsOneWidget);
  });
}
