import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/family/pending_invites.dart';

Future<void> _pump(WidgetTester tester, KvStore kv) async {
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
        kvStoreProvider.overrideWithValue(kv),
        sessionProvider.overrideWith(
          (ref) => SessionController(
            onboarded: true,
            signedIn: true,
            connected: true,
          ),
        ),
      ],
      child: const PulseApp(initialLocation: '/family'),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets(
    'shows no demo members and lists a pending invite once, then cancels it',
    (tester) async {
      final kv = MemoryKvStore();
      final store = PendingInvites(kv);
      await store.add(
        name: 'Animulla',
        relation: 'Other',
        phoneInput: '0501234567',
      );
      await store.add(
        name: 'Animulla',
        relation: 'Other',
        phoneInput: '050 123 4567',
      );
      await _pump(tester, kv);

      for (final demo in ['Sara', 'Khalid', 'Noor']) {
        expect(find.textContaining(demo), findsNothing);
      }
      expect(find.text('Waiting to join'), findsOneWidget);
      expect(find.text('Animulla'), findsOneWidget);
      expect(find.textContaining('not joined yet'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Animulla'), findsNothing);
      expect(find.text('Waiting to join'), findsNothing);
      expect(await store.all(), isEmpty);
    },
  );
}
