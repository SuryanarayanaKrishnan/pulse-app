import 'dart:typed_data';

/// One stored object. [modified] is optional; garbage collection uses it to
/// leave very recent uploads alone.
class BackupObject {
  const BackupObject(this.name, this.size, [this.modified]);
  final String name;
  final int size;
  final DateTime? modified;
}

/// The destination is an opaque object store: it only ever receives
/// ciphertext (plus the wrapped-key envelope, which is itself ciphertext).
/// Names are relative, e.g. `key.json`, `manifests/...`, `chunks/<id>`.
abstract class BackupProvider {
  /// Stable id stored in settings and sent (with nothing else) to analytics.
  String get id;
  String get label;

  /// Throws [BackupProviderUnavailable] when the destination cannot be used
  /// right now (signed out, not configured, native step missing).
  Future<void> ensureReady();

  /// Objects whose name starts with [prefix].
  Future<List<BackupObject>> list(String prefix);

  /// Null when the object does not exist.
  Future<Uint8List?> read(String name);
  Future<void> write(String name, Uint8List bytes);
  Future<void> delete(Iterable<String> names);
}

class BackupProviderUnavailable implements Exception {
  const BackupProviderUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reference implementation and test double.
class MemoryBackupProvider implements BackupProvider {
  MemoryBackupProvider({this.id = 'memory', this.label = 'Memory', DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  @override
  final String id;
  @override
  final String label;
  final DateTime Function() _clock;
  final objects = <String, Uint8List>{};
  final _modified = <String, DateTime>{};

  /// Set to make the next writes throw (offline, quota...).
  Object? failWith;
  int writes = 0;

  @override
  Future<void> ensureReady() async {}

  @override
  Future<List<BackupObject>> list(String prefix) async => [
    for (final e in objects.entries)
      if (e.key.startsWith(prefix)) BackupObject(e.key, e.value.length, _modified[e.key]),
  ];

  @override
  Future<Uint8List?> read(String name) async => objects[name];

  @override
  Future<void> write(String name, Uint8List bytes) async {
    if (failWith != null) throw failWith!;
    writes++;
    objects[name] = Uint8List.fromList(bytes);
    _modified[name] = _clock();
  }

  @override
  Future<void> delete(Iterable<String> names) async {
    for (final n in names) {
      objects.remove(n);
      _modified.remove(n);
    }
  }
}

/// A destination that is declared but not usable in this build. The UI lists
/// it as "needs setup" and never offers it as selectable.
class UnavailableBackupProvider implements BackupProvider {
  const UnavailableBackupProvider({required this.id, required this.label, required this.reason});
  @override
  final String id;
  @override
  final String label;
  final String reason;

  Never _no() => throw BackupProviderUnavailable(reason);
  @override
  Future<void> ensureReady() async => _no();
  @override
  Future<List<BackupObject>> list(String prefix) async => _no();
  @override
  Future<Uint8List?> read(String name) async => _no();
  @override
  Future<void> write(String name, Uint8List bytes) async => _no();
  @override
  Future<void> delete(Iterable<String> names) async => _no();
}

/// Google Drive `appDataFolder` (Android). Free, and the app-private folder is
/// invisible to the user's Drive UI and to other apps. Needs a Google Cloud
/// OAuth client (free) with the `drive.appdata` scope and `google_sign_in`
/// native configuration (SHA-1, client id): a native step that cannot be done
/// or verified here, so this stays a stub behind the interface.
UnavailableBackupProvider googleDriveProvider() => const UnavailableBackupProvider(
  id: 'google_drive',
  label: 'Google Drive (app data)',
  reason: 'Google Drive backup needs a one-time Google sign-in setup that is not enabled in this build.',
);

/// iCloud Drive document container (iOS). Free with the user's Apple ID, but
/// needs the iCloud capability and a container id in the Xcode project and a
/// native bridge for `NSFileCoordinator`: not verifiable without Xcode.
UnavailableBackupProvider iCloudProvider() => const UnavailableBackupProvider(
  id: 'icloud',
  label: 'iCloud Drive',
  reason: 'iCloud backup needs the iCloud capability in the iOS project and is not enabled in this build.',
);
