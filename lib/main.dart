import 'core/learning/global_merchant_map_loader.dart';
import 'core/learning/learning_controller.dart';

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'bugreport/bug_log.dart';
import 'capture/kv_store.dart';
import 'core/analytics/analytics.dart';
import 'core/analytics/gated_analytics.dart';
import 'core/analytics/privacy_controller.dart';
import 'core/env/env.dart';
import 'core/network/api_client.dart';
import 'core/engine/sms_parser.dart' show defaultParserRegistry;
import 'core/packs/content_packs.dart';
import 'core/packs/parser_rules.dart';
import 'core/remote_config/remote_config.dart';
import 'data/local/catalog_service.dart';
import 'backup/background.dart';
import 'data/local/database.dart';
import 'data/local/open.dart';
import 'data/providers.dart';
import 'features/auth/session.dart';
import 'features/onboarding/start_choice.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BugLog.instance.installErrorHooks();

  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  }

  // Sharing is off until the person says yes; everything goes through the gate.
  final privacy = PrivacyController(SharedPrefsKvStore());
  await privacy.load();
  // "Help improve categories": off until chosen; no upload endpoint is
  // configured in this build, so nothing is sent (docs/LEARNING.md).
  final learningKv = SharedPrefsKvStore();
  final merchantMap = await GlobalMerchantMapLoader(kv: learningKv).load();
  final learning = LearningController(learningKv, map: merchantMap);
  await learning.load();
  final analytics = GatedAnalytics(buildAnalytics(), privacy);
  try {
    await analytics.init();
  } catch (e) {
    debugPrint('Analytics init failed: $e');
  }

  // Feature flags: bundled/cached first, a signed refresh in the background.
  final remoteConfig = RemoteConfigService(
    kv: SharedPrefsKvStore(),
    dio: Env.useApi ? buildApiClient() : null,
    publicKeyB64: Env.configPublicKey,
  );
  await remoteConfig.load();
  final packs = ContentPackService(
    kv: SharedPrefsKvStore(),
    config: remoteConfig,
    dio: Env.useApi ? buildApiClient() : null,
  );
  await packs.load(const ['tips', 'walkthrough', 'parser_rules']);
  // Bank-text wordings from the pack (bundled or last verified download).
  applyParserRules(defaultParserRegistry, packs.pack('parser_rules'));
  unawaited(
    remoteConfig.refresh().then((_) => packs.refresh()).then((changed) {
      if (changed.contains('parser_rules')) {
        applyParserRules(defaultParserRegistry, packs.pack('parser_rules'));
      }
    }),
  );

  // The ledger lives in an encrypted database on this phone. Without it the
  // app must not pretend to work, so a failure stops here.
  PulseDatabase? db;
  if (!Env.demoData) {
    try {
      db = await openEncryptedDatabase();
      final catalog = CatalogService(
        db: db,
        dio: Env.useApi ? buildApiClient() : null,
      );
      await catalog.loadBundled();
      // A newer catalog is a bonus; never block start-up on the network.
      unawaited(catalog.checkForUpdate());
      // Registers the daily backup task with the OS (no-op where unsupported).
      await initBackgroundBackup();
    } catch (e, s) {
      debugPrint('Local database failed to open: $e\n$s');
      runApp(_StartupError(message: '$e'));
      return;
    }
  }

  // Remembered first-launch steps and the sample/fresh choice: a returning
  // person goes straight in.
  final kv = SharedPrefsKvStore();
  final session = await SessionController.load(kv);
  String? choice;
  try {
    choice = await kv.read(startChoiceKey);
  } catch (_) {}
  final sample = StartChoice.parse(choice) == StartChoice.sample;

  runApp(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWith((ref) {
          ref.onDispose(session.dispose);
          return session;
        }),
        remoteConfigProvider.overrideWithValue(remoteConfig),
        contentPacksProvider.overrideWithValue(packs),
        privacyControllerProvider.overrideWithValue(privacy),
        learningControllerProvider.overrideWithValue(learning),
        globalMerchantMapProvider.overrideWithValue(merchantMap),
        analyticsProvider.overrideWithValue(
          LoggingAnalytics(analytics, BugLog.instance),
        ),
        if (db != null)
          databaseHolderProvider.overrideWith(
            () => DatabaseHolder(sample ? null : db, db),
          ),
      ],
      child: const PulseApp(),
    ),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your data could not be opened',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pulse keeps your money data in an encrypted database on this '
                'phone and will not start without it, so nothing is lost or '
                'shown in plain text. Restart the app and try again.',
              ),
              const SizedBox(height: 16),
              Text(message, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    ),
  );
}
