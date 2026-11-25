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

/// A user with one cash account that has no balance yet.
class _ZeroCash extends MockPulseRepository {
  _ZeroCash() : super(latency: Duration.zero);
  @override
  Future<List<Asset>> assets() async => const [
    Asset(id: 'a0', name: 'Savings', kind: AssetKind.cash, value: 0),
  ];
}

Future<void> _pump(
  WidgetTester tester,
  MockPulseRepository repo,
  String location,
) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
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
  testWidgets('a zero-balance asset gets no allocation row, just a hint', (
    tester,
  ) async {
    await _pump(tester, _ZeroCash(), '/wealth');
    expect(find.text('0%'), findsNothing);
    expect(
      find.textContaining('to see how your money is split'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'system Back from another tab goes to Home instead of closing the app',
    (tester) async {
      await _pump(
        tester,
        MockPulseRepository(latency: Duration.zero),
        '/cards',
      );
      expect(find.text('Total due'), findsOneWidget);

      final handled = await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));

      expect(
        handled,
        isTrue,
        reason: 'the app must handle Back, not let the system exit',
      );
      expect(find.text('Total due'), findsNothing);
      expect(find.text('Everyday'), findsOneWidget);
    },
  );
}
