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
  testWidgets('home renders hero, budget and recents', (tester) async {
    await _pump(tester);
    expect(find.textContaining('Left to spend'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Recent'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    expect(find.text('Recent'), findsOneWidget);
  });

  testWidgets('budget tab shows safe-to-spend and auto-capture', (
    tester,
  ) async {
    await _pump(tester, location: '/budget');
    expect(find.textContaining('Safe to spend'), findsOneWidget);
    expect(find.textContaining('automatic'), findsOneWidget);
  });
}
