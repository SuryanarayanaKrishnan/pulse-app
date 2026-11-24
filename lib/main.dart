import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/analytics/analytics.dart';
import 'core/env/env.dart';
import 'core/network/api_client.dart';
import 'data/local/catalog_service.dart';
import 'backup/background.dart';
import 'data/local/database.dart';
import 'data/local/open.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
  }

  final analytics = buildAnalytics();
  try {
    await analytics.init();
  } catch (e) {
    debugPrint('Analytics init failed: $e');
  }

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

  runApp(
    ProviderScope(
      overrides: [
        analyticsProvider.overrideWithValue(analytics),
        if (db != null)
          databaseHolderProvider.overrideWith(() => DatabaseHolder(db)),
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
