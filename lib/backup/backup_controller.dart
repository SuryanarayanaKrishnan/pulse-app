import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, StorageException;

import '../core/analytics/analytics.dart';
import '../capture/kv_store.dart';
import '../data/local/database.dart';
import 'archive_file.dart';
import 'backup_crypto.dart';
import 'backup_engine.dart';
import 'backup_keystore.dart';
import 'backup_provider.dart';
import 'backup_state.dart';
import 'key_envelope.dart';
import 'recovery_phrase.dart';

/// What the Backup screens talk to. The real implementation is
/// [BackupService]; demo builds (no on-device database) get a canned one.
abstract class BackupController {
  BackupState get state;
  Stream<BackupState> get changes;

  /// True when this build can reach a cloud destination (Supabase configured).
  bool get cloudAvailable;

  /// Turns backup on with a new secret. Throws [BackupAlreadyExists] when the
  /// cloud account already holds a backup and [replaceExisting] is false.
  Future<void> enable({
    required String secret,
    required String secretKind,
    required BackupDestination destination,
    bool replaceExisting = false,
  });
  Future<BackupStats?> backupNow({String trigger = 'manual'});
  Future<void> changePassphrase({
    required String current,
    required String next,
    required String nextKind,
  });
  Future<void> setAuto(bool v);
  Future<void> setWifiOnly(bool v);
  Future<void> setKeep(int n);
  Future<void> setDestination(BackupDestination d);

  /// Writes an encrypted `.pulsebak` file and returns its path.
  Future<String> exportArchive();
  Future<void> deleteCloudBackup();
  Future<void> disable();
}

class BackupAlreadyExists implements Exception {
  const BackupAlreadyExists();
  @override
  String toString() => 'This account already has a backup.';
}

/// A calm sentence for the user and a coarse reason code for analytics.
({String message, String reason}) describeBackupError(Object e) {
  if (e is WrongPassphrase) {
    return (
      message: 'That passphrase or recovery phrase is not right.',
      reason: 'wrong_passphrase',
    );
  }
  if (e is SocketException ||
      e is TimeoutException ||
      e.runtimeType.toString().contains('ClientException')) {
    return (
      message: 'No connection right now. We will try again on Wi-Fi.',
      reason: 'offline',
    );
  }
  if (e is AuthException ||
      (e is StorageException &&
          (e.statusCode == '401' || e.statusCode == '403'))) {
    return (
      message: 'Please sign in again so backups can continue.',
      reason: 'signed_out',
    );
  }
  if (e is StorageException &&
      (e.statusCode == '413' ||
          e.statusCode == '507' ||
          e.message.toLowerCase().contains('quota'))) {
    return (
      message: 'Your free cloud storage is full. Free some space or export a backup file.',
      reason: 'storage_full',
    );
  }
  if (e is BackupProviderUnavailable)
    return (message: e.message, reason: 'provider_unavailable');
  if (e is StateError && e.message == 'keys_missing') {
    return (
      message: 'This phone no longer has the backup key. Turn backup on again with your passphrase.',
      reason: 'keys_missing',
    );
  }
  return (
    message: 'Backup did not finish. We will try again soon.',
    reason: 'other',
  );
}

class BackupService implements BackupController {
  BackupService({
    required this.db,
    required this.kv,
    required this.keys,
    required this.cloud,
    required this.analytics,
    required this.exportDir,
    this.kdf = KdfParams.production,
    DateTime Function()? clock,
    this.chunkSize = 2 * 1024 * 1024,
  }) : _clock = clock ?? DateTime.now;

  final PulseDatabase db;
  final KvStore kv;
  final BackupKeyStore keys;

  /// Null when no cloud is configured in this build.
  final BackupProvider? cloud;
  final Analytics analytics;
  final Future<Directory> Function() exportDir;
  final KdfParams kdf;
  final int chunkSize;
  final DateTime Function() _clock;

  static const _stateKey = 'backup.state';
  static const _envelopeKey = 'backup.envelope';
  BackupState _state = const BackupState();
  final _ctl = StreamController<BackupState>.broadcast();
  Future<BackupStats?>? _inflight;

  /// Must be awaited once after construction (SharedPreferences is async).
  Future<BackupService> load() async {
    _state = BackupState.fromJson(await kv.read(_stateKey));
    // A crash mid-backup must not leave the screen "running" forever.
    if (_state.running) _state = _state.copyWith(running: false);
    if (!_ctl.isClosed) _ctl.add(_state);
    return this;
  }

  @override
  BackupState get state => _state;
  @override
  Stream<BackupState> get changes => _ctl.stream;
  @override
  bool get cloudAvailable => cloud != null;

  Future<void> _set(BackupState s, {bool persist = true}) async {
    _state = s;
    if (!_ctl.isClosed) _ctl.add(s);
    if (persist) await kv.write(_stateKey, s.toJson());
  }

  Future<void> markDirty() async {
    if (!_state.enabled || _state.dirty) return;
    await _set(_state.copyWith(dirty: true));
  }

  Future<KeyEnvelope?> _localEnvelope() async {
    final s = await kv.read(_envelopeKey);
    return s == null
        ? null
        : KeyEnvelope.decode(Uint8List.fromList(utf8.encode(s)));
  }

  Future<void> _saveEnvelope(KeyEnvelope e) =>
      kv.write(_envelopeKey, utf8.decode(e.encode()));

  /// Stores the keys of a backup restored onto this phone, so backups carry
  /// on from here with no new passphrase. Static: the service of the old
  /// database is discarded when the restored one is swapped in.
  static Future<void> adoptRestored({
    required KvStore kv,
    required BackupKeyStore keys,
    required KeyEnvelope envelope,
    required Uint8List dataKey,
    required BackupDestination destination,
    DateTime? now,
  }) async {
    await keys.save(dataKey);
    await kv.write(_envelopeKey, utf8.decode(envelope.encode()));
    await kv.write(
      _stateKey,
      BackupState(
        enabled: true,
        destination: destination,
        secretKind: envelope.secretKind,
        lastSuccess: (now ?? DateTime.now()).toUtc(),
      ).toJson(),
    );
  }

  @override
  Future<void> enable({
    required String secret,
    required String secretKind,
    required BackupDestination destination,
    bool replaceExisting = false,
  }) async {
    final secretNorm = RecoveryPhrase.secretFrom(secret);
    if (destination == BackupDestination.cloud) {
      final c =
          cloud ??
          (throw const BackupProviderUnavailable(
            'Cloud backup is not set up in this build.',
          ));
      await c.ensureReady();
      if (await c.read(keyObject) != null) {
        if (!replaceExisting) throw const BackupAlreadyExists();
        await BackupEngine.deleteEverything(c);
      }
    }
    final (env, dataKey) = await KeyEnvelope.create(
      secretNorm,
      secretKind: secretKind,
      kdf: kdf,
      now: _clock().toUtc(),
    );
    if (destination == BackupDestination.cloud)
      await cloud!.write(keyObject, env.encode());
    await keys.save(dataKey);
    await _saveEnvelope(env);
    await _set(
      BackupState(
        enabled: true,
        destination: destination,
        secretKind: secretKind,
        dirty: true,
      ),
    );
    analytics.track(
      AnalyticsEvent.backupEnabled(
        secretKind: secretKind,
        destination: destination.analyticsName,
      ),
    );
    if (destination == BackupDestination.cloud)
      await backupNow(trigger: 'setup');
  }

  @override
  Future<BackupStats?> backupNow({String trigger = 'manual'}) {
    if (!_state.cloud) return Future.value(null);
    return _inflight ??= _run(trigger).whenComplete(() => _inflight = null);
  }

  Future<BackupStats?> _run(String trigger) async {
    final started = _clock();
    await _set(
      _state.copyWith(running: true, progress: 0, lastAttempt: started.toUtc()),
      persist: false,
    );
    try {
      final dataKey = await keys.load() ?? (throw StateError('keys_missing'));
      final c =
          cloud ??
          (throw const BackupProviderUnavailable(
            'Cloud backup is not set up in this build.',
          ));
      await c.ensureReady();
      // Heal a missing key file (deleted, or a new account on this phone).
      if (await c.read(keyObject) == null) {
        final env =
            await _localEnvelope() ?? (throw StateError('keys_missing'));
        await c.write(keyObject, env.encode());
      }
      final engine = BackupEngine(
        provider: c,
        dataKey: dataKey,
        chunkSize: chunkSize,
        clock: _clock,
      );
      final stats = await engine.backup(
        db: db,
        keep: _state.keep,
        onProgress: (v) => _set(_state.copyWith(progress: v), persist: false),
      );
      await _set(
        _state.copyWith(
          running: false,
          progress: 1,
          lastSuccess: stats.createdAt,
          lastError: null,
          failures: 0,
          dirty: false,
          lastBytes: stats.bytesUploaded,
        ),
      );
      analytics.track(
        AnalyticsEvent.backupCompleted(
          trigger: trigger,
          sizeBucket: sizeBucket(stats.bytesUploaded),
          seconds: _clock().difference(started).inSeconds,
        ),
      );
      return stats;
    } catch (e) {
      final d = describeBackupError(e);
      await _set(
        _state.copyWith(
          running: false,
          lastError: d.message,
          failures: _state.failures + 1,
        ),
      );
      analytics.track(
        AnalyticsEvent.backupFailed(trigger: trigger, reason: d.reason),
      );
      return null;
    }
  }

  @override
  Future<void> changePassphrase({
    required String current,
    required String next,
    required String nextKind,
  }) async {
    final dataKey = await keys.load() ?? (throw StateError('keys_missing'));
    final env =
        await _localEnvelope() ??
        (_state.cloud ? await BackupEngine.readEnvelope(cloud!) : null);
    if (env == null) throw StateError('keys_missing');
    final proven = await env.unwrap(RecoveryPhrase.secretFrom(current));
    if (!_same(proven, dataKey)) throw const WrongPassphrase();
    final fresh = await env.rewrap(
      dataKey,
      RecoveryPhrase.secretFrom(next),
      secretKind: nextKind,
    );
    // Remote first: if it fails nothing has changed anywhere.
    if (_state.cloud) await cloud!.write(keyObject, fresh.encode());
    await _saveEnvelope(fresh);
    await _set(_state.copyWith(secretKind: nextKind));
    analytics.track(AnalyticsEvent.backupPassphraseChanged);
  }

  static bool _same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var x = 0;
    for (var i = 0; i < a.length; i++) {
      x |= a[i] ^ b[i];
    }
    return x == 0;
  }

  @override
  Future<void> setAuto(bool v) => _set(_state.copyWith(auto: v));
  @override
  Future<void> setWifiOnly(bool v) => _set(_state.copyWith(wifiOnly: v));
  @override
  Future<void> setKeep(int n) => _set(_state.copyWith(keep: n.clamp(1, 20)));

  @override
  Future<void> setDestination(BackupDestination d) async {
    if (d == _state.destination) return;
    if (d == BackupDestination.cloud) {
      final c =
          cloud ??
          (throw const BackupProviderUnavailable(
            'Cloud backup is not set up in this build.',
          ));
      await c.ensureReady();
      final env = await _localEnvelope() ?? (throw StateError('keys_missing'));
      final remote = await c.read(keyObject);
      if (remote != null &&
          !_same(KeyEnvelope.decode(remote).wrappedKey, env.wrappedKey)) {
        // A different backup lineage lives there; never mix the two.
        throw const BackupAlreadyExists();
      }
      if (remote == null) await c.write(keyObject, env.encode());
    }
    await _set(_state.copyWith(destination: d, dirty: true));
  }

  @override
  Future<String> exportArchive() async {
    final dataKey = await keys.load() ?? (throw StateError('keys_missing'));
    final env = await _localEnvelope() ?? (throw StateError('keys_missing'));
    final dir = await exportDir();
    await dir.create(recursive: true);
    for (final old in dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.$archiveExtension'),
    )) {
      try {
        old.deleteSync();
      } catch (_) {}
    }
    final t = _clock().toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    final path = p.join(
      dir.path,
      'pulse-backup-${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}.$archiveExtension',
    );
    final sink = ArchiveWriterProvider(path);
    try {
      await sink.write(keyObject, env.encode());
      await BackupEngine(
        provider: sink,
        dataKey: dataKey,
        chunkSize: chunkSize,
        clock: _clock,
      ).backup(db: db, prune: false);
    } catch (_) {
      await sink.close();
      try {
        File(path).deleteSync();
      } catch (_) {}
      rethrow;
    }
    await sink.close();
    analytics.track(AnalyticsEvent.backupExported);
    return path;
  }

  @override
  Future<void> deleteCloudBackup() async {
    final c =
        cloud ??
        (throw const BackupProviderUnavailable(
          'Cloud backup is not set up in this build.',
        ));
    await c.ensureReady();
    await BackupEngine.deleteEverything(c);
    analytics.track(AnalyticsEvent.backupCloudDeleted);
    await disable();
  }

  @override
  Future<void> disable() async {
    await keys.clear();
    await kv.remove(_envelopeKey);
    await _set(const BackupState());
    analytics.track(AnalyticsEvent.backupDisabled);
  }

  void dispose() => _ctl.close();
}
