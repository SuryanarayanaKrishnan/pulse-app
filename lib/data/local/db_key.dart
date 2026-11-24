import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the database passphrase lives. Production keeps it in the platform
/// keystore (iOS Keychain, Android Keystore); it never touches the database
/// file, preferences or logs.
abstract class DatabaseKeyStore {
  /// The existing key, or a freshly generated one stored first.
  Future<String> loadOrCreate();
}

/// 256 random bits, base64url without padding (safe inside a PRAGMA literal).
String generateDatabaseKey([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => r.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

class SecureStorageKeyStore implements DatabaseKeyStore {
  SecureStorageKeyStore({FlutterSecureStorage? storage, this.storageKey = 'pulse.db.key.v1'})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Readable after the first unlock so the background Apple Pay
            // intent can reach the database; never synced to iCloud.
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
          );

  final FlutterSecureStorage _storage;
  final String storageKey;
  Future<String>? _pending;

  @override
  Future<String> loadOrCreate() => _pending ??= _load();

  Future<String> _load() async {
    final existing = await _storage.read(key: storageKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final key = generateDatabaseKey();
    await _storage.write(key: storageKey, value: key);
    return key;
  }
}

/// For tests.
class MemoryKeyStore implements DatabaseKeyStore {
  MemoryKeyStore([this._key]);
  String? _key;
  @override
  Future<String> loadOrCreate() async => _key ??= generateDatabaseKey();
}
