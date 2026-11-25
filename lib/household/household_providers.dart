import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/analytics/analytics.dart';
import '../core/env/env.dart';
import '../core/household/household_keys.dart';
import '../core/household/household_models.dart';
import '../core/household/household_store.dart';
import '../core/sync/sync_scheduler.dart';
import '../data/demo_household.dart';
import '../data/household_service.dart';
import '../data/local/household_store.dart';
import '../data/providers.dart';
import '../sync/file_sync_state_store.dart';
import 'secure_household_key_store.dart';
import 'supabase_household_transport.dart';

final householdKeyStoreProvider = Provider<HouseholdKeyStore>((ref) {
  if (Env.demoData || kIsWeb || ref.watch(localDatabaseProvider) == null) {
    return MemoryHouseholdKeyStore();
  }
  return SecureHouseholdKeyStore();
});

final householdStoreProvider = Provider<HouseholdStore>((ref) {
  final db = ref.watch(localDatabaseProvider);
  if (Env.demoData || db == null) {
    return MemoryHouseholdStore(
      loader: () => demoOwnRows(ref.read(repositoryProvider), ref.read(goalServiceProvider)),
    );
  }
  return LocalHouseholdStore(
    db,
    wealth: () => ref.read(repositoryProvider).assets(),
    goals: () => ref.read(goalServiceProvider).views(),
  );
});

Future<File> _stateFile(String id) async => File(
  '${(await getApplicationSupportDirectory()).path}/pulse-household-$id.json',
);

/// The household log's tables, to watch for local writes.
const _watched = {
  'transactions',
  'accounts',
  'assets',
  'liabilities',
  'savings_goals',
  'goal_contributions',
  'household_bills',
  'household_limits',
  'household_members',
  'household_configs',
};

final householdServiceProvider = Provider<HouseholdService>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final real = !Env.demoData && !kIsWeb && db != null;
  final svc = HouseholdService(
    store: ref.watch(householdStoreProvider),
    keys: ref.watch(householdKeyStoreProvider),
    analytics: ref.watch(analyticsProvider),
    transportFor: real && Env.hasSupabase
        ? (id) => SupabaseHouseholdTransport(Supabase.instance.client, householdId: id)
        : null,
    stateStoreFor: real
        ? (id) => FileSyncStateStore(locate: () => _stateFile(id), db: db, settingKey: 'household_epoch')
        : null,
  );
  ref.onDispose(svc.dispose);
  return svc;
});


/// Debounced sync after local writes and on resume. Null where the log
/// cannot leave the phone (demo data, web, no server).
final householdSchedulerProvider = Provider<SyncScheduler?>((ref) {
  final db = ref.watch(localDatabaseProvider);
  if (Env.demoData || kIsWeb || db == null || !Env.hasSupabase) return null;
  final svc = ref.watch(householdServiceProvider);
  final sched = SyncScheduler(
    run: (_) async {
      try {
        await svc.sync();
        return true;
      } catch (_) {
        return false;
      }
    },
  );
  final sub = db.tableUpdates().listen((u) {
    if (u.any((t) => _watched.contains(t.table))) sched.onLocalWrite();
  });
  ref.onDispose(() {
    sub.cancel();
    sched.dispose();
  });
  return sched;
});

/// The household this phone belongs to; null when there is none.
final householdConfigProvider = FutureProvider<HouseholdConfig?>(
  (ref) => ref.watch(householdServiceProvider).config(),
);

/// Joint data (null without a household). Refresh with [invalidateHousehold].
final jointDataProvider = FutureProvider<JointData?>(
  (ref) => ref.watch(householdServiceProvider).joint(),
);

class HouseholdStatusNotifier extends Notifier<HouseholdStatus> {
  @override
  HouseholdStatus build() {
    final s = ref.watch(householdServiceProvider);
    final sub = s.changes.listen((v) {
      state = v;
      if (!v.running) ref.invalidate(jointDataProvider);
    });
    ref.onDispose(sub.cancel);
    return s.status;
  }
}

final householdStatusProvider = NotifierProvider<HouseholdStatusNotifier, HouseholdStatus>(
  HouseholdStatusNotifier.new,
);

/// Refreshes everything after the household or an item's ownership changed.
void invalidateHousehold(WidgetRef ref) {
  ref.invalidate(householdConfigProvider);
  ref.invalidate(jointDataProvider);
}

/// This item's owner and Private flag (for the detail sheets).
final ownershipProvider = FutureProvider.family<Ownership, (String, String)>(
  (ref, key) => ref.watch(householdServiceProvider).ownership(key.$1, key.$2),
);
