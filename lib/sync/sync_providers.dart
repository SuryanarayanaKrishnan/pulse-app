import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../backup/backup_providers.dart';
import '../core/analytics/analytics.dart';
import '../core/env/env.dart';
import '../core/sync/sync_engine.dart';
import '../core/sync/sync_scope.dart';
import '../core/sync/sync_transport.dart';
import '../data/providers.dart';
import 'drift_sync_bridge.dart';
import 'file_sync_state_store.dart';
import 'supabase_sync_transport.dart';
import 'sync_service.dart';

final syncTransportProvider = Provider<SyncTransport?>((ref) {
  if (Env.demoData || !Env.hasSupabase) return null;
  return SupabaseSyncTransport(Supabase.instance.client);
});

/// Null where sync cannot run: demo data, web, no on-device database.
final syncServiceProvider = Provider<SyncService?>((ref) {
  final db = ref.watch(localDatabaseProvider);
  if (Env.demoData || db == null || kIsWeb) return null;
  final svc = SyncService(
    kv: ref.watch(backupKvProvider),
    keys: ref.watch(backupKeyStoreProvider),
    transport: ref.watch(syncTransportProvider),
    analytics: ref.watch(analyticsProvider),
    engineFor: (dataKey) => SyncEngine(
      bridge: DriftSyncBridge(db),
      transport: ref.read(syncTransportProvider)!,
      store: FileSyncStateStore(locate: _stateFile, db: db),
      dataKey: dataKey,
    ),
  );
  unawaited(svc.load());
  // Debounced sync after local writes to synced tables only.
  final sub = db.tableUpdates().listen((u) {
    if (u.any((t) => syncedTables.contains(t.table))) svc.onLocalWrite();
  });
  ref.onDispose(() {
    sub.cancel();
    svc.dispose();
  });
  return svc;
});

Future<File> _stateFile() async => File(
  '${(await getApplicationSupportDirectory()).path}/pulse-sync-state.json',
);

class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    final s = ref.watch(syncServiceProvider);
    if (s == null) return const SyncStatus();
    final sub = s.changes.listen((v) => state = v);
    ref.onDispose(sub.cancel);
    return s.status;
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(
  SyncStatusNotifier.new,
);
