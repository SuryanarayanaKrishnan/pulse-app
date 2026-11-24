import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:path/path.dart' as p;

import '../core/analytics/analytics.dart';
import '../data/local/database.dart';
import '../data/local/db_key.dart';
import '../data/local/open.dart';
import 'backup_controller.dart';
import 'backup_crypto.dart';
import 'backup_engine.dart';
import 'backup_format.dart';
import 'backup_provider.dart';
import 'backup_state.dart';
import 'key_envelope.dart';
import 'recovery_phrase.dart';

/// A backup that has been opened with the right secret.
class UnlockedBackup {
  UnlockedBackup({
    required this.provider,
    required this.envelope,
    required this.dataKey,
    required this.versions,
    required this.corrupt,
    required this.source,
  });
  final BackupProvider provider;
  final KeyEnvelope envelope;
  final Uint8List dataKey;
  final List<BackupVersion> versions;

  /// Snapshots that were listed but failed authentication.
  final int corrupt;

  /// `cloud` or `file` (analytics, and where backups continue afterwards).
  final String source;
}

/// Where a restored database goes. The default talks to the real files and
/// keystore; tests substitute a temp directory.
abstract class RestoreHost {
  /// Whether this phone already holds user data a restore would replace.
  Future<bool> hasExistingData();

  /// A brand-new, empty, correctly keyed database that is NOT the live one.
  Future<PulseDatabase> createFresh();
  Directory get attachmentsDir;

  /// Makes [fresh] the live database. The old one is kept as a safety copy.
  Future<void> swapIn(PulseDatabase fresh);

  /// Throws the fresh database away (restore failed or was cancelled).
  Future<void> discard(PulseDatabase fresh);
}

class DeviceRestoreHost implements RestoreHost {
  DeviceRestoreHost({
    required this.supportDir,
    required this.attachmentsDir,
    required this.keys,
    required this.live,
    this.fileName = 'pulse.db',
    this.allowPlaintext = false,
    this.safetyCopyTtl = const Duration(days: 7),
  });

  final Directory supportDir;
  @override
  final Directory attachmentsDir;
  final DatabaseKeyStore keys;

  /// The open database (closed during the swap); null if none is open.
  final PulseDatabase? live;
  final String fileName;
  final bool allowPlaintext;
  final Duration safetyCopyTtl;
  String? _newKey;

  File _f(String n) => File(p.join(supportDir.path, n));
  static const _suffixes = ['', '-wal', '-shm', '-journal'];

  @override
  Future<bool> hasExistingData() async {
    final db = live;
    if (db == null) return false;
    for (final t in const ['transactions', 'accounts', 'assets', 'jewellery_items', 'document_attachments', 'fund_holdings']) {
      final n = await db.customSelect('SELECT count(*) AS n FROM $t').getSingle();
      if (n.read<int>('n') > 0) return true;
    }
    return false;
  }

  @override
  Future<PulseDatabase> createFresh() async {
    for (final s in _suffixes) {
      final f = _f('$fileName.restore$s');
      if (f.existsSync()) f.deleteSync();
    }
    // Two databases are open at once on purpose: different files.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    _newKey = generateDatabaseKey();
    return openEncryptedDatabase(
      keys: MemoryKeyStore(_newKey),
      directory: supportDir,
      fileName: '$fileName.restore',
      background: false,
      allowPlaintext: allowPlaintext,
    );
  }

  @override
  Future<void> swapIn(PulseDatabase fresh) async {
    final key = _newKey ?? (throw StateError('createFresh was not called'));
    // Checkpoint and release both files before touching them.
    await fresh.close();
    await live?.close();
    final safety = '$fileName.before-restore';
    for (final s in _suffixes) {
      final old = _f('$safety$s');
      if (old.existsSync()) old.deleteSync();
    }
    // 1. current -> safety copy   2. restored -> current   3. new key.
    // Any failure rolls the files back before the key is changed.
    final moved = <String>[];
    try {
      for (final s in _suffixes) {
        final cur = _f('$fileName$s');
        if (cur.existsSync()) {
          cur.renameSync(_f('$safety$s').path);
          moved.add(s);
        }
      }
      for (final s in _suffixes) {
        final r = _f('$fileName.restore$s');
        if (r.existsSync()) r.renameSync(_f('$fileName$s').path);
      }
      await keys.replace(key);
    } catch (_) {
      for (final s in _suffixes) {
        final cur = _f('$fileName$s');
        if (cur.existsSync()) cur.deleteSync();
      }
      for (final s in moved) {
        _f('$safety$s').renameSync(_f('$fileName$s').path);
      }
      rethrow;
    }
  }

  @override
  Future<void> discard(PulseDatabase fresh) async {
    try {
      await fresh.close();
    } catch (_) {}
    for (final s in _suffixes) {
      final f = _f('$fileName.restore$s');
      if (f.existsSync()) f.deleteSync();
    }
  }

  /// Removes the safety copy once it is older than [safetyCopyTtl].
  Future<void> purgeOldSafetyCopy() async {
    final f = _f('$fileName.before-restore');
    if (!f.existsSync()) return;
    if (DateTime.now().difference(f.lastModifiedSync()) < safetyCopyTtl) return;
    for (final s in _suffixes) {
      final x = _f('$fileName.before-restore$s');
      if (x.existsSync()) x.deleteSync();
    }
  }
}

/// Opens a backup with a secret and restores it onto this phone.
class RestoreService {
  RestoreService({required this.host, required this.analytics, this.adopt, this.upgraders = const {}});
  final RestoreHost host;
  final Analytics analytics;
  final Map<int, RowUpgrader> upgraders;

  /// Told about the keys after a successful restore so backups continue.
  final Future<void> Function(KeyEnvelope, Uint8List, BackupDestination)? adopt;

  /// Reads the key file, opens it with [rawSecret] and lists the snapshots.
  /// Throws [NoBackupFound], [WrongPassphrase] or a [FormatException].
  Future<UnlockedBackup> unlock(BackupProvider provider, String rawSecret, {required String source}) async {
    await provider.ensureReady();
    final env = await BackupEngine.readEnvelope(provider) ?? (throw const NoBackupFound());
    final dataKey = await env.unwrap(RecoveryPhrase.secretFrom(rawSecret));
    final engine = BackupEngine(provider: provider, dataKey: dataKey);
    final versions = await engine.versions();
    if (versions.isEmpty) throw const NoBackupFound();
    return UnlockedBackup(
      provider: provider,
      envelope: env,
      dataKey: dataKey,
      versions: versions,
      corrupt: engine.corruptManifests,
      source: source,
    );
  }

  /// Restores into a fresh database, verifies it, then swaps it in. The
  /// caller must have confirmed replacing existing data (see
  /// [RestoreHost.hasExistingData]) and must reopen the database afterwards.
  Future<RestoreStats> restore(UnlockedBackup u, BackupVersion version, {void Function(double)? onProgress}) async {
    analytics.track(AnalyticsEvent.restoreStarted(u.source));
    PulseDatabase? fresh;
    try {
      fresh = await host.createFresh();
      final stats = await BackupEngine(provider: u.provider, dataKey: u.dataKey).restoreInto(
        target: fresh,
        manifestName: version.objectName,
        attachmentsDir: host.attachmentsDir,
        upgraders: upgraders,
        onProgress: onProgress,
      );
      await host.swapIn(fresh);
      fresh = null;
      await adopt?.call(
        u.envelope,
        u.dataKey,
        u.source == 'cloud' ? BackupDestination.cloud : BackupDestination.file,
      );
      analytics.track(AnalyticsEvent.restoreCompleted(u.source));
      return stats;
    } catch (e) {
      if (fresh != null) await host.discard(fresh);
      analytics.track(AnalyticsEvent.restoreFailed(source: u.source, reason: restoreFailureReason(e)));
      rethrow;
    }
  }
}

String restoreFailureReason(Object e) => switch (e) {
  WrongPassphrase() => 'wrong_passphrase',
  NoBackupFound() => 'not_found',
  BackupIncomplete() => 'incomplete',
  BackupIntegrityError() => 'corrupt',
  BackupTooNew() => 'too_new',
  _ => 'other',
};

/// Friendly text for any restore error.
String describeRestoreError(Object e) => switch (e) {
  WrongPassphrase() => 'That passphrase or recovery phrase is not right. Check it and try again.',
  NoBackupFound() => 'No backup was found here.',
  BackupIncomplete() => 'This backup is incomplete, so it was not used. Nothing on this phone was changed.',
  BackupIntegrityError() => 'This backup failed its safety check and may be damaged. Nothing on this phone was changed.',
  BackupTooNew() => 'This backup was made by a newer version of Pulse. Update the app, then try again.',
  FormatException(:final message) => '$message. Nothing on this phone was changed.',
  _ => describeBackupError(e).message,
};
