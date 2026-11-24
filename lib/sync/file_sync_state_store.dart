import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../core/sync/sync_state.dart';
import '../data/local/database.dart';

/// Keeps the sync state in a file beside the database, and ties it to that
/// exact database content with an epoch token.
///
/// Why not a table: the state names this device (its id, its log position).
/// A table would be copied by backup and restore onto another phone, and two
/// phones must never share a device id.
///
/// Why an epoch: every save writes a fresh random token to the state file and
/// to the database (`app_settings`). If the database is replaced by a restore
/// (older rows, or another phone's rows) the tokens differ, the state is
/// discarded, and the device starts over as a new one: it reads everyone
/// else's log first and only then compares its own data. That is safe; the
/// alternative (trusting a stale state against restored rows) would look like
/// mass deletes to the other devices.
class FileSyncStateStore implements SyncStateStore {
  FileSyncStateStore({required this.locate, required this.db});

  /// Resolved lazily (the app-support directory is found asynchronously).
  final Future<File> Function() locate;
  final PulseDatabase db;

  static const settingKey = 'sync_epoch';

  @override
  Future<SyncState?> load() async {
    try {
      final file = await locate();
      if (!await file.exists()) return null;
      final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final epoch = j['epoch'] as String?;
      if (epoch == null || epoch != await db.setting(settingKey)) return null;
      return SyncState.decode(j['state'] as String);
    } catch (_) {
      return null; // unreadable: start over, which is always safe
    }
  }

  @override
  Future<void> save(SyncState state) async {
    final epoch = base64Url.encode(
      List.generate(12, (_) => Random.secure().nextInt(256)),
    );
    final file = await locate();
    final tmp = File('${file.path}.tmp');
    await file.parent.create(recursive: true);
    await tmp.writeAsString(jsonEncode({'epoch': epoch, 'state': state.encode()}), flush: true);
    await tmp.rename(file.path);
    await db.putSetting(settingKey, epoch);
  }

  Future<void> clear() async {
    final file = await locate();
    if (await file.exists()) await file.delete();
  }
}
