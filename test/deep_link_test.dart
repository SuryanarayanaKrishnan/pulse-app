import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/capture/ingest_queue.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/router/router.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/api/ingest_api.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';

void main() {
  testWidgets('pulse://ingest deep link is queued for apple-shortcut', (
    tester,
  ) async {
    PulseTheme.useGoogleFonts = false;
    final sent = <PendingIngest>[];
    final session = SessionController(
      onboarded: true,
      signedIn: true,
      connected: true,
    );
    final router = buildRouter(session: session, analytics: NoopAnalytics());
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(
            MockPulseRepository(latency: Duration.zero),
          ),
          kvStoreProvider.overrideWithValue(MemoryKvStore()),
          ingestSenderProvider.overrideWithValue((item) async {
            sent.add(item);
            return SendOutcome.sent;
          }),
        ],
        child: MaterialApp.router(theme: PulseTheme.dark, routerConfig: router),
      ),
    );
    router.go(
      'pulse://ingest?amount=45.50&merchant=Starbucks&card=Visa%204821',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.state.uri.path, Routes.appleIngest);
    expect(find.text('Payment captured'), findsOneWidget);
    expect(sent, hasLength(1));
    expect(sent.single.channel, IngestChannel.appleShortcut);
    expect((sent.single.payload['fields']! as Map)['amount_minor'], 4550);

    // Auto-navigates home after the confirmation.
    await tester.pump(const Duration(seconds: 2));
    expect(router.state.uri.path, Routes.home);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('invalid link shows an error instead of queueing', (
    tester,
  ) async {
    PulseTheme.useGoogleFonts = false;
    final sent = <PendingIngest>[];
    final session = SessionController(
      onboarded: true,
      signedIn: true,
      connected: true,
    );
    final router = buildRouter(session: session, analytics: NoopAnalytics());
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(
            MockPulseRepository(latency: Duration.zero),
          ),
          kvStoreProvider.overrideWithValue(MemoryKvStore()),
          ingestSenderProvider.overrideWithValue((item) async {
            sent.add(item);
            return SendOutcome.sent;
          }),
        ],
        child: MaterialApp.router(theme: PulseTheme.dark, routerConfig: router),
      ),
    );
    router.go('pulse://ingest?merchant=Nothing');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Could not read that payment'), findsOneWidget);
    expect(sent, isEmpty);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  testWidgets('Apple Pay setup shows steps, token and link template', (
    tester,
  ) async {
    PulseTheme.useGoogleFonts = false;
    tester.view.physicalSize = const Size(1170, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final session = SessionController(
      onboarded: true,
      signedIn: true,
      connected: true,
    );
    final router = buildRouter(
      session: session,
      analytics: NoopAnalytics(),
      initialLocation: Routes.applePaySetup,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [kvStoreProvider.overrideWithValue(MemoryKvStore())],
        child: MaterialApp.router(theme: PulseTheme.dark, routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Open Shortcut'), findsOneWidget);
    expect(find.textContaining('pulse://ingest?amount='), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('pls_'), 200);
    expect(find.textContaining('pls_'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
