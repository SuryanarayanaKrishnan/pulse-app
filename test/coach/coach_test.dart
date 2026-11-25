import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/tour/tour_progress.dart';

Future<void> pumpApp(WidgetTester tester, MemoryKvStore kv) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tourKvProvider.overrideWithValue(kv),
        repositoryProvider.overrideWithValue(
          MockPulseRepository(latency: Duration.zero),
        ),
        analyticsProvider.overrideWithValue(NoopAnalytics()),
        sessionProvider.overrideWith(
          (ref) =>
              SessionController(onboarded: true, signedIn: true, connected: true),
        ),
      ],
      child: const PulseApp(),
    ),
  );
  await settle(tester);
}

Future<void> settle(WidgetTester tester, [int n = 30]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('quiet until the intro tour has been seen', (tester) async {
    await pumpApp(tester, MemoryKvStore());
    expect(find.byKey(const Key('coach_card')), findsNothing);
  });

  testWidgets('Home walkthrough runs once, steps, finishes and stays seen', (
    tester,
  ) async {
    final kv = MemoryKvStore()..data['tour.seen'] = '1';
    await pumpApp(tester, kv);
    expect(find.byKey(const Key('coach_card')), findsOneWidget);
    expect(find.text('Your number for today'), findsOneWidget);

    await tester.tap(find.byKey(const Key('coach_next')));
    await settle(tester, 8);
    expect(find.byKey(const Key('coach_card')), findsOneWidget);

    await tester.tap(find.byKey(const Key('coach_skip')));
    await settle(tester, 8);
    expect(find.byKey(const Key('coach_card')), findsNothing);
    expect(kv.data['coach.seen.home'], '1');
  });

  testWidgets('the help button replays a seen walkthrough', (tester) async {
    final kv = MemoryKvStore()
      ..data['tour.seen'] = '1'
      ..data['coach.seen.home'] = '1';
    await pumpApp(tester, kv);
    expect(find.byKey(const Key('coach_card')), findsNothing);
    await tester.tap(find.byKey(const Key('coach_help')));
    await settle(tester, 8);
    expect(find.byKey(const Key('coach_card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('coach_skip')));
    await settle(tester, 8);
    expect(find.byKey(const Key('coach_card')), findsNothing);
  });
}
