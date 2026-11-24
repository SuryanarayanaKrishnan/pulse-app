import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';

import 'database.dart';
import 'db_key.dart';

/// The linked SQLite has no encryption support, so opening would silently
/// write the money data in plain text. We refuse instead.
class EncryptionUnavailable implements Exception {
  const EncryptionUnavailable();
  @override
  String toString() => 'The SQLite build in this app does not support encryption.';
}

/// True when the loaded SQLite is SQLite3 Multiple Ciphers (or SQLCipher).
bool sqliteSupportsEncryption(CommonDatabase db) {
  for (final pragma in const ['PRAGMA cipher', 'PRAGMA cipher_version']) {
    try {
      if (db.select(pragma).isNotEmpty) return true;
    } on SqliteException {
      continue;
    }
  }
  return false;
}

/// Keys [db] and proves the key works; runs inside the database isolate.
void applyEncryptionKey(
  CommonDatabase db,
  String key, {
  required bool allowPlaintext,
  @visibleForTesting bool? encryptionSupported,
}) {
  final supported = encryptionSupported ?? sqliteSupportsEncryption(db);
  if (!allowPlaintext && !supported) {
    throw const EncryptionUnavailable();
  }
  if (supported) {
    db.execute("PRAGMA key = '$key'");
  }
  // A wrong key or a plaintext file fails here, not on some later query.
  db.select('SELECT count(*) FROM sqlite_master');
}

/// Opens (creating on first run) the encrypted on-device database.
///
/// The passphrase comes from [keys] (the platform keystore by default) and is
/// generated on first run. [allowPlaintext] exists for tests and for builds
/// without the encryption hook; production code must leave it false.
Future<PulseDatabase> openEncryptedDatabase({
  DatabaseKeyStore? keys,
  String fileName = 'pulse.db',
  Directory? directory,
  bool background = true,
  bool allowPlaintext = false,
}) async {
  final key = await (keys ?? SecureStorageKeyStore()).loadOrCreate();
  final dir = directory ?? await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  final file = File(p.join(dir.path, fileName));
  void setup(CommonDatabase db) => applyEncryptionKey(db, key, allowPlaintext: allowPlaintext);
  final executor = background
      ? NativeDatabase.createInBackground(file, setup: setup)
      : NativeDatabase(file, setup: setup);
  return PulseDatabase(executor);
}
