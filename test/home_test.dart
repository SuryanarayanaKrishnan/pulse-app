import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';

Future<void> _pump(WidgetTester tester, {String? location}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(
          MockPulseRepository(latency: Duration.zero),
        ),
        analyticsProvider.overrideWithValue(NoopAnalytics()),
        sessionProvider.overrideWith(
          (ref) => SessionController(
            onboarded: true,
            signedIn: true,
            connected: true,
          ),
        ),
      ],
      child: PulseApp(initialLocation: location),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('home leads with safe to spend, health and which card', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Safe to spend today'), findsOneWidget);
    expect(find.text('Which card should I use?'), findsOneWidget);
    expect(find.textContaining('Financial health'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Recent'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    expect(find.text('Recent'), findsOneWidget);
  });

  testWidgets('which card sheet recommends a card for a category', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Which card should I use?'));
    await tester.pumpAndSettle();
    expect(find.text('Live rates, after this month\'s caps'), findsOneWidget);
    await tester.tap(find.text('Dining & Delivery').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Next best'), findsOneWidget);
  });

  testWidgets('budget tab shows status, automatic share and cashflow', (
    tester,
  ) async {
    await _pump(tester, location: '/budget');
    expect(
      find.textContaining(RegExp('On track|Nearing limit|Over')),
      findsWidgets,
    );
    expect(find.textContaining('automatic'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Cashflow'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    expect(find.textContaining('Projected on'), findsOneWidget);
  });

  testWidgets('cards tab shows payment, verified reward rules and due dates', (
    tester,
  ) async {
    await _pump(tester, location: '/cards');
    await tester.dragUntilVisible(
      find.text('Rewards on this card'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    expect(find.text('Full amount'), findsOneWidget);
    expect(find.textContaining('Verified on'), findsWidgets);
    await tester.dragUntilVisible(
      find.text('Due dates'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    expect(find.text('Due dates'), findsOneWidget);
  });

  testWidgets('simulated card tap shows the rewards moment', (tester) async {
    await _pump(tester, location: '/settings');
    await tester.dragUntilVisible(
      find.text('Simulate a card tap'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.tap(find.text('Simulate a card tap'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('at Talabat'), findsOneWidget);
    await tester.tap(find.textContaining('at Talabat'));
    await tester.pumpAndSettle();
    expect(find.text('Rewards earned'), findsOneWidget);
    expect(find.textContaining('Cap reached'), findsWidgets);
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('family lists members and the legacy vault is a placeholder', (
    tester,
  ) async {
    await _pump(tester, location: '/family');
    expect(find.text('What you share'), findsOneWidget);
    expect(find.text('Invite by phone'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Nominees & legacy'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.tap(find.text('Nominees & legacy'));
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsOneWidget);
  });
}
