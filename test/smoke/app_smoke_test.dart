import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/widgets/widgets.dart';
import 'package:pulse/features/cards/quick_pick_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/bugreport/shake_detector.dart';
import 'package:pulse/bugreport/shake_host.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/analytics/privacy_controller.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/learning/learning_controller.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/tour/tour_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-free smoke test of the real app root on an in-memory ledger.
///
/// Walks the first-run path a person takes: tour, start fresh, add cards,
/// a simulated card tap (right/wrong card note), then Review, Budget, Wealth
/// and Settings > Privacy. Any exception thrown by the framework while doing
/// so fails the test. Runs in CI under `flutter test` (no emulator needed).
void main() {
  testWidgets('first run end to end', (tester) async {
    // Any framework error (build/layout/paint) fails the test by default.
    PulseTheme.useGoogleFonts = false;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Native plugins do not exist under `flutter test`: answer their channels
    // with harmless in-memory fakes so the app's own code is what gets tested.
    final secure = <String, String>{};
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'), (c) async {
      final key = (c.arguments as Map?)?['key'] as String?;
      switch (c.method) {
        case 'read':
          return secure[key];
        case 'write':
          secure[key!] = (c.arguments as Map)['value'] as String;
          return null;
        case 'delete':
          secure.remove(key);
          return null;
        case 'containsKey':
          return secure.containsKey(key);
        case 'readAll':
          return secure;
        default:
          return null;
      }
    });
    for (final name in ['dev.fluttercommunity.plus/connectivity', 'dev.fluttercommunity.plus/connectivity_status']) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (c) async => c.method == 'check' ? ['wifi'] : null);
    }
    addTearDown(() {
      for (final name in [
        'plugins.it_nomads.com/flutter_secure_storage',
        'dev.fluttercommunity.plus/connectivity',
        'dev.fluttercommunity.plus/connectivity_status',
      ]) {
        messenger.setMockMethodCallHandler(MethodChannel(name), null);
      }
    });

    final db = PulseDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final kv = MemoryKvStore();
    final privacy = PrivacyController(kv);
    await privacy.load();
    final learning = LearningController(kv);
    await learning.load();

    await tester.runAsync(() async {
      final catalog = CatalogService(
        db: db,
        bundled: () async => File('assets/catalog/cards.json').readAsStringSync(),
      );
      await catalog.loadBundled();
    });

    /// Lets real async work (drift) finish, then pumps frames.
    Future<void> settle([int frames = 6]) async {
      for (var i = 0; i < frames; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    Future<void> tapText(String text) async {
      // A first-visit walkthrough may be waiting; a real person skips it.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 800));
        final skip = find.byKey(const Key('coach_skip'));
        final next = find.byKey(const Key('coach_next'));
        if (skip.evaluate().isNotEmpty) {
          await tester.tap(skip);
        } else if (next.evaluate().isNotEmpty) {
          await tester.tap(next);
        } else {
          break;
        }
        await tester.pump(const Duration(milliseconds: 400));
      }
      final f = find.text(text);
      final vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axis == Axis.vertical);
      for (final delta in [300.0, -300.0, -300.0]) {
        if (f.evaluate().isNotEmpty || vertical.evaluate().isEmpty) break;
        try {
          await tester.scrollUntilVisible(f, delta, scrollable: vertical.last, maxScrolls: 20);
        } on Object {
          // Reported below with what is on screen.
        }
      }
      final onScreen = [for (final w in tester.widgetList<Text>(find.byType(Text))) w.data].whereType<String>().toList();
      expect(f, findsWidgets, reason: 'expected "$text"; on screen: $onScreen');
      await tester.ensureVisible(f.first);
      await tester.tap(f.first, warnIfMissed: false);
      await settle();
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tourKvProvider.overrideWithValue(MemoryKvStore()),
          privacyControllerProvider.overrideWithValue(privacy),
          learningControllerProvider.overrideWithValue(learning),
          analyticsProvider.overrideWithValue(NoopAnalytics()),
          shakeSourceProvider.overrideWithValue(() => const Stream<Accel>.empty()),
          databaseHolderProvider.overrideWith(() => DatabaseHolder(db)),
        ],
        child: const PulseApp(),
      ),
    );
    await settle();

    // Fresh install: the tour comes first. Skip it, answer the usage prompt.
    expect(find.text('Skip'), findsOneWidget);
    await tapText('Skip');
    await settle(8);
    if (find.text('No thanks').evaluate().isNotEmpty) await tapText('No thanks');

    // Intro -> Start fresh -> connect (later) -> home. No sign-in without a backend.
    await tapText('Start fresh with Pulse');
    await tapText('Skip for now');
    expect(find.text('Home'), findsWidgets);

    // Add two cards through the quick picker: tick both, one button, no per-card popup.
    await tapText('Cards');
    await settle();
    await tapText('Pick your cards');
    for (final search in ['Emirates NBD', 'Mashreq']) {
      await tester.enterText(find.byType(TextField).first, search);
      await settle();
      final tile = find.descendant(of: find.byType(QuickPickCardsSheet), matching: find.byType(ListRow));
      expect(tile, findsWidgets, reason: 'catalog entry for "$search"');
      await tester.tap(tile.first);
      await settle();
    }
    await tapText('Add 2 cards');
    await settle();
    final cards = await tester.runAsync(() => db.select(db.accounts).get());
    expect(cards!.length, 2);
    // Quick-add skips the digits; give the cards some so simulated alerts can match them.
    await tester.runAsync(() async {
      var i = 1234;
      for (final a in cards) {
        await (db.update(db.accounts)..where((t) => t.id.equals(a.id))).write(AccountsCompanion(last4: Value('${i++}')));
      }
    });
    final owned = await tester.runAsync(() => db.select(db.accounts).get());
    expect(owned!.length, 2, reason: 'both cards saved');

    // Simulated card tap from Settings -> reward banner and card-check note.
    await tapText('Home');
    await tester.tap(find.byIcon(Icons.account_circle_outlined).first, warnIfMissed: false);
    await settle();
    await tapText('Simulate a card tap');
    await settle(10);
    expect(
      find.byKey(const ValueKey('card-check-nudge')),
      findsOneWidget,
      reason: 'right/wrong card note after a tap',
    );
    expect(
      find.textContaining(RegExp('Right card|would have earned')),
      findsWidgets,
    );

    // Settings > Privacy. Park the row mid-screen, clear of the app bar and the reward banner.
    final privacyRow = find.text('Not sharing anything');
    final pos = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    pos.jumpTo(0);
    await settle();
    await tester.scrollUntilVisible(privacyRow, 300, scrollable: find.byType(Scrollable).first);
    await settle();
    pos.jumpTo(pos.pixels + tester.getCenter(privacyRow).dy - 420);
    await settle();
    await tester.tap(privacyRow);
    await settle();
    expect(find.text('Share anonymous usage'), findsWidgets, reason: 'Privacy screen open');
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await settle();

    // Settings > Beta tools > Report a bug opens the sheet (testers who cannot shake).
    final reportRow = find.text('Report a bug');
    await tester.scrollUntilVisible(reportRow, 300, scrollable: find.byType(Scrollable).first);
    pos.jumpTo(pos.pixels + tester.getCenter(reportRow).dy - 420);
    await settle();
    await tester.tap(reportRow);
    await settle(16);
    expect(find.byKey(const Key('bug-note')), findsOneWidget, reason: 'bug report sheet open');
    Navigator.of(tester.element(find.byKey(const Key('bug-note'))), rootNavigator: true).pop();
    await settle();
    expect(find.byKey(const Key('bug-note')), findsNothing);

    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await settle();

    // Review (from Home), then Budget and Wealth tabs.
    await tapText('Home');
    final review = find.byKey(const ValueKey('review-card-home'));
    expect(review, findsOneWidget, reason: 'Review card on Home');
    await tester.ensureVisible(review);
    // Lift it clear of the floating tab bar before tapping.
    final reviewY = tester.getCenter(review).dy;
    final viewH = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    if (reviewY > viewH * 0.6) {
      await tester.drag(find.byType(Scrollable).first, Offset(0, viewH * 0.6 - reviewY));
      await settle();
    }
    await tester.tap(review, warnIfMissed: false);
    await settle(8);
    expect(review, findsNothing, reason: 'Review screen opened');
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await settle();
    await tapText('Budget');
    await tapText('Wealth');

    expect(tester.takeException(), isNull);

    // Unmount so providers and timers are disposed before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 7));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
