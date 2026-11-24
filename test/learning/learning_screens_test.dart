import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/analytics/event_schema.dart';
import 'package:pulse/core/analytics/privacy_controller.dart';
import 'package:pulse/core/learning/global_merchant_map.dart';
import 'package:pulse/core/learning/learning_controller.dart';
import 'package:pulse/core/router/router.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/features/privacy/learning_preview_screen.dart';
import 'package:pulse/features/privacy/privacy_screen.dart';

class _Sink implements Analytics {
  final events = <AnalyticsEvent>[];
  @override
  Future<void> init() async {}
  @override
  void track(AnalyticsEvent e) => events.add(e);
  @override
  void screen(String name) {}
  @override
  void identify(String userId) {}
  @override
  void reset() {}
}

final _map = GlobalMerchantMap(version: 1, entries: const {'carrefour': 'groceries', 'spinneys': 'groceries'});

Future<({LearningController learning, _Sink sink, PrivacyController privacy})> _pump(
  WidgetTester tester, {
  String start = Routes.privacy,
}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 3200);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final learning = LearningController(MemoryKvStore(), map: _map);
  final privacy = PrivacyController(MemoryKvStore());
  final sink = _Sink();
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(path: Routes.privacy, builder: (_, _) => const PrivacyScreen()),
      GoRoute(path: Routes.learningPreview, builder: (_, _) => const LearningPreviewScreen()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        learningControllerProvider.overrideWithValue(learning),
        privacyControllerProvider.overrideWithValue(privacy),
        analyticsProvider.overrideWithValue(sink),
      ],
      child: MaterialApp.router(theme: PulseTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (learning: learning, sink: sink, privacy: privacy);
}


void main() {
  testWidgets('Privacy: the toggle is off by default, independent of usage sharing', (tester) async {
    final t = await _pump(tester);
    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(2));
    // First switch: anonymous usage. Second: help improve categories.
    expect(tester.widget<Switch>(switches.at(0)).value, isFalse);
    expect(tester.widget<Switch>(switches.at(1)).value, isFalse);
    expect(find.text('Off. Nothing is shared.'), findsOneWidget);

    await tester.tap(switches.at(1));
    await tester.pumpAndSettle();
    expect(t.learning.optIn, isTrue);
    expect(t.privacy.sharing, isFalse, reason: 'analytics consent is untouched');
    expect(tester.widget<Switch>(find.byType(Switch).at(1)).value, isTrue);

    await tester.tap(find.byType(Switch).at(0));
    await tester.pumpAndSettle();
    expect(t.privacy.sharing, isTrue);
    await tester.tap(find.byType(Switch).at(0));
    await tester.pumpAndSettle();
    expect(t.learning.optIn, isTrue, reason: 'turning usage off does not turn this off');
  });

  testWidgets('Privacy: explains plainly what leaves the phone', (tester) async {
    await _pump(tester);
    expect(find.textContaining('shop name in plain lower case'), findsOneWidget);
    expect(find.textContaining('confirmed at least twice'), findsOneWidget);
    expect(find.textContaining('left out at random'), findsOneWidget);
    expect(find.textContaining('deletes anything waiting to be shared'), findsOneWidget);
    expect(find.text('See what would be shared'), findsOneWidget);
  });

  testWidgets('Privacy: toggling reports only yes or no through the analytics gate', (tester) async {
    final t = await _pump(tester);
    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    final ev = t.sink.events.where((e) => e.name == 'learning_opt_in').toList();
    expect([for (final e in ev) e.properties['enabled']], [true, false]);
    for (final e in ev) {
      expect(AnalyticsSchema.clean(e.name, e.properties), e.properties);
      expect(e.properties.keys, ['enabled']);
    }
  });

  testWidgets('Privacy: turning it off deletes what was queued', (tester) async {
    final t = await _pump(tester);
    await t.learning.setOptIn(true);
    await t.learning.recordConfirmation(paymentId: '1', merchant: 'Carrefour', categoryId: 'groceries');
    expect(t.learning.queue.isEmpty, isFalse);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    expect(t.learning.optIn, isFalse);
    expect(t.learning.queue.isEmpty, isTrue);
  });

  testWidgets('Preview: reachable from Privacy and empty while off', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('See what would be shared'));
    await tester.pumpAndSettle();
    expect(find.text('What would be shared'), findsOneWidget);
    expect(find.textContaining('is off, so nothing is kept'), findsOneWidget);
    expect(find.byKey(const Key('learning-empty')), findsOneWidget);
  });

  testWidgets('Preview: lists eligible pairs, counts the rest, offers deletion', (tester) async {
    final t = await _pump(tester, start: Routes.learningPreview);
    await t.learning.setOptIn(true);
    for (final id in ['1', '2']) {
      await t.learning.recordConfirmation(paymentId: id, merchant: 'Carrefour', categoryId: 'groceries');
    }
    await t.learning.recordConfirmation(paymentId: '3', merchant: 'Spinneys', categoryId: 'groceries');
    // Private ones never show up.
    await t.learning.recordConfirmation(paymentId: '4', merchant: 'Mohammed Ali', categoryId: 'dining');
    await t.learning.recordConfirmation(paymentId: '5', merchant: '0501234567', categoryId: 'dining');
    await tester.pumpAndSettle();

    expect(find.text('carrefour'), findsOneWidget);
    expect(find.text('groceries, seen 2x'), findsOneWidget);
    expect(find.text('spinneys'), findsNothing);
    expect(find.textContaining('1 more shop waiting'), findsOneWidget);
    expect(find.textContaining('mohammed'), findsNothing);
    expect(find.textContaining('0501'), findsNothing);
    expect(find.textContaining('Sharing is not switched on in this version'), findsOneWidget);

    await tester.tap(find.text('Delete everything waiting'));
    await tester.pumpAndSettle();
    expect(t.learning.queue.isEmpty, isTrue);
    expect(t.learning.optIn, isTrue);
    expect(find.byKey(const Key('learning-empty')), findsOneWidget);
  });
}
