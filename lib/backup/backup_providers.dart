import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../capture/kv_store.dart';
import '../core/analytics/analytics.dart';
import '../core/env/env.dart';
import '../data/local/catalog_service.dart';
import '../data/local/db_key.dart';
import '../data/local/open.dart';
import '../data/providers.dart';
import 'backup_controller.dart';
import 'backup_keystore.dart';
import 'backup_provider.dart';
import 'backup_scheduler.dart';
import 'backup_state.dart';
import 'background.dart';
import 'demo_backup.dart';
import 'restore_flow.dart';
import 'restore_service.dart';
import 'supabase_backup_provider.dart';

final backupKvProvider = Provider<KvStore>((ref) => SharedPrefsKvStore());
final backupKeyStoreProvider = Provider<BackupKeyStore>(
  (ref) => SecureBackupKeyStore(),
);

/// Supabase Storage when the build has Supabase configured. Drive and iCloud
/// are declared in `backup_provider.dart` but not offered here.
final cloudBackupProvider = Provider<BackupProvider?>((ref) {
  if (Env.demoData || !Env.hasSupabase) return null;
  return SupabaseBackupProvider(Supabase.instance.client);
});

/// The real service when an on-device database exists, a scripted demo
/// otherwise (demo data, web, widget tests).
final backupControllerProvider = Provider<BackupController>((ref) {
  final db = ref.watch(localDatabaseProvider);
  if (Env.demoData || db == null || kIsWeb) return DemoBackupController();
  final svc = BackupService(
    db: db,
    kv: ref.watch(backupKvProvider),
    keys: ref.watch(backupKeyStoreProvider),
    cloud: ref.watch(cloudBackupProvider),
    analytics: ref.watch(analyticsProvider),
    exportDir: () async =>
        Directory('${(await getTemporaryDirectory()).path}/pulse-export'),
  );
  unawaited(svc.load());
  ref.onDispose(svc.dispose);
  return svc;
});

/// Mirrors the controller's state for widgets.
class BackupStateNotifier extends Notifier<BackupState> {
  @override
  BackupState build() {
    final c = ref.watch(backupControllerProvider);
    final sub = c.changes.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return c.state;
  }
}

final backupStateProvider = NotifierProvider<BackupStateNotifier, BackupState>(
  BackupStateNotifier.new,
);

/// Starts the change watcher and keeps the daily task in step with the
/// settings. Watch it once from the app root.
final backupSchedulerProvider = Provider<BackupScheduler?>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final c = ref.watch(backupControllerProvider);
  if (Env.demoData || db == null || kIsWeb) return null;
  final s = BackupScheduler(service: c, db: db)..start();
  var last = '';
  void sync() {
    final st = c.state;
    final key = '${st.cloud}${st.auto}${st.wifiOnly}';
    if (key == last) return;
    last = key;
    unawaited(
      syncBackgroundSchedule(
        enabled: st.cloud && st.auto,
        wifiOnly: st.wifiOnly,
      ),
    );
  }

  final sub = c.changes.listen((_) => sync());
  ref.onDispose(() {
    sub.cancel();
    s.dispose();
  });
  return s;
});

/// Opens the (possibly just restored) database again and hands it to the app.
final reopenDatabaseProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final db = await openEncryptedDatabase();
    await CatalogService(db: db).loadBundled();
    ref.read(databaseHolderProvider.notifier).replace(db);
  };
});

final restoreFlowProvider = FutureProvider<RestoreFlow>((ref) async {
  final db = ref.read(localDatabaseProvider);
  if (Env.demoData || db == null || kIsWeb) return DemoRestoreFlow();
  final keys = SecureStorageKeyStore();
  final host = await buildDeviceHost(live: db, keys: keys);
  final kv = ref.read(backupKvProvider);
  final bkeys = ref.read(backupKeyStoreProvider);
  final service = RestoreService(
    host: host,
    analytics: ref.read(analyticsProvider),
    adopt: (env, dk, dest) => BackupService.adoptRestored(
      kv: kv,
      keys: bkeys,
      envelope: env,
      dataKey: dk,
      destination: dest,
    ),
  );
  return RealRestoreFlow(
    service: service,
    cloud: ref.read(cloudBackupProvider),
    reopenDb: ref.read(reopenDatabaseProvider),
  );
});
