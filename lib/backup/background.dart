import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../capture/kv_store.dart';
import '../core/analytics/analytics.dart';
import '../core/env/env.dart';
import '../data/local/open.dart';
import 'backup_controller.dart';
import 'backup_keystore.dart';
import 'backup_provider.dart';
import 'supabase_backup_provider.dart';

const backupTaskId = 'pulse.backup.daily';

bool get backgroundBackupSupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Entry point the OS wakes up (own isolate, app possibly not running).
/// Android: WorkManager with an "unmetered network" constraint. iOS:
/// BGAppRefresh through workmanager; iOS decides when (and whether) to run
/// it, so the foreground triggers remain the dependable path there.
@pragma('vm:entry-point')
void backupCallbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      return await runBackgroundBackup();
    } catch (e) {
      debugPrint('Background backup failed: $e');
      return false; // let the OS retry with backoff
    }
  });
}

/// One unattended backup. Returns false only when a retry makes sense.
Future<bool> runBackgroundBackup() async {
  WidgetsFlutterBinding.ensureInitialized();
  final kv = SharedPrefsKvStore();
  // Cheap exit before opening anything: is backup even on?
  final probe = await _peek(kv);
  if (!probe) return true;
  if (Env.hasSupabase) {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
      );
    } catch (_) {
      // Already initialised in a warm isolate.
    }
  }
  final db = await openEncryptedDatabase(background: false);
  try {
    final BackupProvider? cloud = Env.hasSupabase
        ? SupabaseBackupProvider(Supabase.instance.client)
        : null;
    final svc = await BackupService(
      db: db,
      kv: kv,
      keys: SecureBackupKeyStore(),
      cloud: cloud,
      analytics: NoopAnalytics(),
      exportDir: () async =>
          throw UnsupportedError('no export in the background'),
    ).load();
    if (!svc.state.cloud || !svc.state.auto) return true;
    await svc.backupNow(trigger: 'daily');
    final failedHard = svc.state.lastError != null && svc.state.failures >= 1;
    svc.dispose();
    return !failedHard;
  } finally {
    await db.close();
  }
}

Future<bool> _peek(KvStore kv) async {
  final s = await kv.read('backup.state');
  return s != null && s.contains('"enabled":true');
}

/// Registers or cancels the daily task to match the current setting. Safe to
/// call on every start.
Future<void> syncBackgroundSchedule({
  required bool enabled,
  required bool wifiOnly,
}) async {
  if (!backgroundBackupSupported || Env.demoData) return;
  try {
    final wm = Workmanager();
    if (!enabled) {
      await wm.cancelByUniqueName(backupTaskId);
      return;
    }
    await wm.registerPeriodicTask(
      backupTaskId,
      backupTaskId,
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  } catch (e) {
    debugPrint('Could not schedule the daily backup: $e');
  }
}

Future<void> initBackgroundBackup() async {
  if (!backgroundBackupSupported || Env.demoData) return;
  try {
    await Workmanager().initialize(backupCallbackDispatcher);
  } catch (e) {
    debugPrint('Background backup unavailable: $e');
  }
}
