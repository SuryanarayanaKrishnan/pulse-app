import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/engine/nw_history.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';

/// A brand-new user: no transactions, cards, accounts, assets, groups or history.
class _Nothing extends MockPulseRepository {
  _Nothing({this.zeroValueAsset = false}) : super(latency: Duration.zero);

  /// A user who added an account or asset but has not entered a balance yet.
  final bool zeroValueAsset;
  @override
  Future<List<Transaction>> transactions() async => const [];
  @override
  Future<List<CreditCard>> myCards() async => const [];
  @override
  Future<List<BankAccount>> bankAccounts() async => const [];
  @override
  Future<List<Asset>> assets() async => zeroValueAsset
      ? const [
          Asset(id: 'a0', name: 'Savings', kind: AssetKind.cash, value: 0),
          Asset(id: 'a1', name: 'Gold', kind: AssetKind.gold, value: 0),
        ]
      : const [];
  @override
  Future<List<SplitGroup>> splitGroups() async => const [];
  @override
  Future<List<NwPoint>> netWorthHistory() async => const [];
}

void main() {
  for (final route in [
    '/home',
    '/budget',
    '/cards',
    '/splits',
    '/wealth',
    '/activity',
    '/goals',
    '/recurring',
    '/reports',
    '/review',
    '/cards-ranked',
    '/household',
  ]) {
    for (final zero in [false, true])
      testWidgets(
        'zero state does not throw on $route (zero-value assets: $zero)',
        (tester) async {
          PulseTheme.useGoogleFonts = false;
          tester.view.physicalSize = const Size(1170, 2532);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                repositoryProvider.overrideWithValue(
                  _Nothing(zeroValueAsset: zero),
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
              child: PulseApp(initialLocation: route),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(seconds: 3));
          expect(tester.takeException(), isNull);
        },
      );
  }
}
