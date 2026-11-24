import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/local/db_key.dart';
import '../data/local/database.dart';
import 'archive_file.dart';
import 'backup_provider.dart';
import 'restore_service.dart';
import 'supabase_backup_provider.dart';

enum RestoreSource { cloud, file }

/// One snapshot as the restore screen lists it.
class BackupChoice {
  const BackupChoice({
    required this.id,
    required this.createdAt,
    required this.rows,
    required this.photos,
  });
  final String id;
  final DateTime createdAt;
  final int rows;
  final int photos;
}

class UnlockResult {
  const UnlockResult(this.choices, {this.damaged = 0});
  final List<BackupChoice> choices;
  final int damaged;
}

/// What the restore screen needs. [RealRestoreFlow] drives [RestoreService];
/// the demo build gets a scripted one.
abstract class RestoreFlow {
  bool get cloudAvailable;

  /// Cloud restore needs the signed-in account first.
  bool get needsSignIn;
  Future<bool> hasExistingData();

  /// Opens the chosen source with [secret]. For [RestoreSource.file] pass
  /// [filePath]. Throws the errors [describeRestoreError] understands.
  Future<UnlockResult> unlock(
    RestoreSource source,
    String secret, {
    String? filePath,
  });
  Future<void> restore(String choiceId, {void Function(double)? onProgress});

  /// Opens the database again after the swap.
  Future<void> reopen();
}

class RealRestoreFlow implements RestoreFlow {
  RealRestoreFlow({
    required this.service,
    required this.cloud,
    required this.reopenDb,
  });
  final RestoreService service;
  final BackupProvider? cloud;
  final Future<void> Function() reopenDb;
  UnlockedBackup? _open;

  @override
  bool get cloudAvailable => cloud != null;

  @override
  bool get needsSignIn =>
      cloud is SupabaseBackupProvider &&
      Supabase.instance.client.auth.currentUser == null;

  @override
  Future<bool> hasExistingData() => service.host.hasExistingData();

  @override
  Future<UnlockResult> unlock(
    RestoreSource source,
    String secret, {
    String? filePath,
  }) async {
    final BackupProvider provider = switch (source) {
      RestoreSource.cloud =>
        cloud ??
            (throw const BackupProviderUnavailable(
              'Cloud backup is not set up in this build.',
            )),
      RestoreSource.file => await ArchiveReaderProvider.open(
        filePath ?? (throw const ArchiveFormatError()),
      ),
    };
    final u = await service.unlock(
      provider,
      secret,
      source: source == RestoreSource.cloud ? 'cloud' : 'file',
    );
    _open = u;
    return UnlockResult([
      for (final v in u.versions)
        BackupChoice(
          id: v.objectName,
          createdAt: v.manifest.createdAt.toLocal(),
          rows: v.manifest.rowCount,
          photos: v.manifest.attachments.length,
        ),
    ], damaged: u.corrupt);
  }

  @override
  Future<void> restore(
    String choiceId, {
    void Function(double)? onProgress,
  }) async {
    final u = _open ?? (throw StateError('unlock first'));
    final v = u.versions.firstWhere((x) => x.objectName == choiceId);
    await service.restore(u, v, onProgress: onProgress);
  }

  @override
  Future<void> reopen() => reopenDb();
}

/// Resolves the folders a real restore needs.
Future<DeviceRestoreHost> buildDeviceHost({
  required PulseDatabase? live,
  required DatabaseKeyStore keys,
}) async {
  if (kIsWeb) throw UnsupportedError('Restore needs the iOS or Android app.');
  final support = await getApplicationSupportDirectory();
  final docs = await getApplicationDocumentsDirectory();
  return DeviceRestoreHost(
    supportDir: support,
    attachmentsDir: Directory(p.join(docs.path, 'attachments')),
    keys: keys,
    live: live,
  );
}

/// Scripted flow for the demo build (no database, no network): the screens
/// can be walked through and screenshotted. The secret "demo" style check is
/// only a UI stand-in; real restores always go through [RealRestoreFlow].
class DemoRestoreFlow implements RestoreFlow {
  DemoRestoreFlow({DateTime? now}) : _now = now ?? DateTime.now();
  final DateTime _now;
  @override
  bool get cloudAvailable => true;
  @override
  bool get needsSignIn => false;
  @override
  Future<bool> hasExistingData() async => false;

  @override
  Future<UnlockResult> unlock(
    RestoreSource source,
    String secret, {
    String? filePath,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return UnlockResult([
      BackupChoice(
        id: 'v3',
        createdAt: _now.subtract(const Duration(hours: 5)),
        rows: 1342,
        photos: 14,
      ),
      BackupChoice(
        id: 'v2',
        createdAt: _now.subtract(const Duration(days: 2)),
        rows: 1318,
        photos: 14,
      ),
      BackupChoice(
        id: 'v1',
        createdAt: _now.subtract(const Duration(days: 9)),
        rows: 1204,
        photos: 11,
      ),
    ]);
  }

  @override
  Future<void> restore(
    String choiceId, {
    void Function(double)? onProgress,
  }) async {
    for (var i = 1; i <= 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      onProgress?.call(i / 5);
    }
  }

  @override
  Future<void> reopen() async {}
}

String formatWhen(DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.inHours < 24 && t.day == now.day) return 'Today, ${_hm(t)}';
  if (d.inDays < 2 && now.day - t.day == 1) return 'Yesterday, ${_hm(t)}';
  const m = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${t.day} ${m[t.month - 1]} ${t.year}, ${_hm(t)}';
}

String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
