import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where this phone keeps the backup data key so automatic backups can run
/// without asking for the passphrase. It lives in the platform keystore, is
/// never synced (iOS: this-device-only) and never leaves the phone.
abstract class BackupKeyStore {
  Future<Uint8List?> load();
  Future<void> save(Uint8List dataKey);
  Future<void> clear();
}

class SecureBackupKeyStore implements BackupKeyStore {
  SecureBackupKeyStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );
  final FlutterSecureStorage _storage;
  static const _key = 'pulse.backup.datakey.v1';

  @override
  Future<Uint8List?> load() async {
    final v = await _storage.read(key: _key);
    return v == null || v.isEmpty ? null : base64.decode(v);
  }

  @override
  Future<void> save(Uint8List dataKey) =>
      _storage.write(key: _key, value: base64.encode(dataKey));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class MemoryBackupKeyStore implements BackupKeyStore {
  Uint8List? key;
  @override
  Future<Uint8List?> load() async => key;
  @override
  Future<void> save(Uint8List dataKey) async => key = dataKey;
  @override
  Future<void> clear() async => key = null;
}
