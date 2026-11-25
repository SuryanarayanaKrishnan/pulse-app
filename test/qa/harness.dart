import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/bugreport/shake_detector.dart';
import 'package:pulse/bugreport/shake_host.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/analytics/privacy_controller.dart';
import 'package:pulse/core/learning/learning_controller.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/tour/tour_progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the data comes from in a QA scenario.
enum QaData {
  /// Fresh install: an in-memory ledger with the card catalog and nothing else.
  empty,

  /// No database at all: the in-memory demo repository (as in DEMO_DATA builds).
  demo,
}

/// Collects every framework error (overflow, build, layout) instead of letting
/// the first one hide the rest. Each entry is "summary @ creator widget".
class ErrorLog {
  final List<String> entries = [];
  void Function(FlutterErrorDetails)? _prev;

  void install() {
    _prev = FlutterError.onError;
    FlutterError.onError = (d) {
      final where =
          d.informationCollector
              ?.call()
              .map((n) => n.toString())
              .where((t) => t.contains('.dart'))
              .take(1)
              .join() ??
          '';
      final summary = d.summary.toString();
      final creator =
          RegExp(r'file:///[^\s:]+/(lib/[^\s]+)')
              .firstMatch(d.toString())
              ?.group(1) ??
          '';
      entries.add(
        '$summary${creator.isEmpty ? '' : ' @ $creator'}${where.isEmpty ? '' : ' $where'}',
      );
    };
  }

  void uninstall() => FlutterError.onError = _prev;

  /// Returns and clears what was collected.
  List<String> drain() {
    final r = entries.toSet().toList();
    entries.clear();
    return r;
  }
}

/// A running app under test.
class QaApp {
  QaApp(this.tester, this.db);
  final WidgetTester tester;
  final PulseDatabase? db;
  final errors = ErrorLog();

  /// Lets real async work (drift) finish, then pumps frames.
  Future<void> settle([int frames = 6]) async {
    for (var i = 0; i < frames; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  ProviderContainer get container =>
      ProviderScope.containerOf(tester.element(find.byType(PulseApp)));

  /// Runs real async work (drift) outside the fake-async zone.
  Future<T> real<T>(Future<T> Function() f) async =>
      (await tester.runAsync(f)) as T;

  /// Navigates the router, as a deep link or a tap would.
  Future<void> go(String location) async {
    final ctx = tester.element(find.byType(Navigator).first);
    GoRouter.of(ctx).go(location);
    await settle(8);
  }

  /// Text currently on screen, for failure messages.
  List<String> get visibleText => [
    for (final w in tester.widgetList<Text>(find.byType(Text)))
      if (w.data != null) w.data!,
  ];
}

/// Pumps the real app root, signed in, at [location], with fakes for native plugins.
Future<QaApp> launchApp(
  WidgetTester tester, {
  required QaData data,
  String location = '/home',
  bool dark = false,
  Size size = const Size(1170, 2532),
  double dpr = 3,
  Future<void> Function(PulseDatabase db)? seed,
  List<Override> overrides = const [],
  bool signedIn = true,
}) async {
  PulseTheme.useGoogleFonts = false;
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = dpr;
  tester.platformDispatcher.platformBrightnessTestValue = dark
      ? Brightness.dark
      : Brightness.light;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });

  final secure = <String, String>{};
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (c) async {
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
    },
  );
  for (final name in [
    'dev.fluttercommunity.plus/connectivity',
    'dev.fluttercommunity.plus/connectivity_status',
  ]) {
    messenger.setMockMethodCallHandler(
      MethodChannel(name),
      (c) async => c.method == 'check' ? ['wifi'] : null,
    );
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

  PulseDatabase? db;
  if (data != QaData.demo) {
    db = PulseDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final d = db;
    await tester.runAsync(() async {
      final catalog = CatalogService(
        db: d,
        bundled: () async =>
            File('assets/catalog/cards.json').readAsStringSync(),
      );
      await catalog.loadBundled();
      if (seed != null) await seed(d);
    });
  }
  final kv = MemoryKvStore();
  final privacy = PrivacyController(kv);
  await privacy.load();
  final learning = LearningController(kv);
  await learning.load();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        tourKvProvider.overrideWithValue(MemoryKvStore()),
        privacyControllerProvider.overrideWithValue(privacy),
        learningControllerProvider.overrideWithValue(learning),
        analyticsProvider.overrideWithValue(NoopAnalytics()),
        shakeSourceProvider.overrideWithValue(
          () => const Stream<Accel>.empty(),
        ),
        sessionProvider.overrideWith((ref) {
          final s = SessionController(
            onboarded: true,
            signedIn: signedIn,
            connected: signedIn,
          );
          ref.onDispose(s.dispose);
          return s;
        }),
        if (db != null)
          databaseHolderProvider.overrideWith(() => DatabaseHolder(db!)),
        ...overrides,
      ],
      child: PulseApp(initialLocation: location),
    ),
  );
  final app = QaApp(tester, db);
  app.errors.install();
  addTearDown(app.errors.uninstall);
  await app.settle(8);
  return app;
}

/// Unmounts so providers and timers are disposed before the test ends.
Future<void> shutDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 7));
}
