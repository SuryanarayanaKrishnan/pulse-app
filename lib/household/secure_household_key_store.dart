import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/household/household_keys.dart';

/// The household key in the iOS Keychain (this device only) or the Android
/// Keystore. Same approach as the backup data key.
class SecureHouseholdKeyStore implements HouseholdKeyStore {
  SecureHouseholdKeyStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );
  final FlutterSecureStorage _storage;
  static const _key = 'pulse.household.key.v1';

  @override
  Future<Uint8List?> load() async {
    final v = await _storage.read(key: _key);
    return v == null || v.isEmpty ? null : base64.decode(v);
  }

  @override
  Future<void> save(Uint8List key) =>
      _storage.write(key: _key, value: base64.encode(key));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}
