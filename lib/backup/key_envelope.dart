import 'dart:convert';
import 'dart:typed_data';

import 'backup_crypto.dart';

/// `key.json` in the backup store: Argon2id parameters, the salt and the data
/// key wrapped (AES-256-GCM) by the master key. It reveals nothing without the
/// passphrase or recovery phrase, and is bound to its own parameters.
class KeyEnvelope {
  KeyEnvelope({
    required this.kdf,
    required this.salt,
    required this.wrappedKey,
    required this.secretKind,
    required this.createdAt,
  });

  static const formatVersion = 1;

  final KdfParams kdf;
  final Uint8List salt;
  final Uint8List wrappedKey;

  /// `phrase` or `passphrase`: a UI hint only, not a secret.
  final String secretKind;
  final DateTime createdAt;

  List<int> get _aad => utf8.encode(
    'pulse.backup.key.v$formatVersion|${kdf.memoryKiB}|${kdf.iterations}|${kdf.parallelism}|${base64.encode(salt)}',
  );

  /// Makes a new data key wrapped by [secret].
  static Future<(KeyEnvelope, Uint8List)> create(
    String secret, {
    required String secretKind,
    KdfParams kdf = KdfParams.production,
    DateTime? now,
  }) async {
    final dataKey = BackupCrypto.randomBytes(32);
    final env = await _wrap(secret, dataKey, kdf, secretKind, now ?? DateTime.now().toUtc());
    return (env, dataKey);
  }

  static Future<KeyEnvelope> _wrap(
    String secret,
    Uint8List dataKey,
    KdfParams kdf,
    String secretKind,
    DateTime now,
  ) async {
    final salt = BackupCrypto.randomBytes(16);
    final master = await BackupCrypto.deriveMasterKey(secret, salt, kdf);
    final draft = KeyEnvelope(kdf: kdf, salt: salt, wrappedKey: Uint8List(0), secretKind: secretKind, createdAt: now);
    final wrapped = await BackupCrypto.seal(master, dataKey, aad: draft._aad);
    return KeyEnvelope(kdf: kdf, salt: salt, wrappedKey: wrapped, secretKind: secretKind, createdAt: now);
  }

  /// The data key, or [WrongPassphrase]. A wrong secret and a tampered
  /// envelope are indistinguishable by design.
  Future<Uint8List> unwrap(String secret) async {
    final master = await BackupCrypto.deriveMasterKey(secret, salt, kdf);
    try {
      return await BackupCrypto.open(master, wrappedKey, aad: _aad);
    } on BackupIntegrityError {
      throw const WrongPassphrase();
    }
  }

  /// Re-wraps the same data key under a new secret and a fresh salt. Existing
  /// backup objects stay valid because the data key does not change.
  Future<KeyEnvelope> rewrap(Uint8List dataKey, String newSecret, {required String secretKind, KdfParams? newKdf}) =>
      _wrap(newSecret, dataKey, newKdf ?? kdf, secretKind, DateTime.now().toUtc());

  Uint8List encode() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'v': formatVersion,
        'kdf': kdf.toJson(),
        'salt': base64.encode(salt),
        'wrapped': base64.encode(wrappedKey),
        'kind': secretKind,
        'created': createdAt.toIso8601String(),
      }),
    ),
  );

  static KeyEnvelope decode(Uint8List bytes) {
    try {
      final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (j['v'] != formatVersion) throw const FormatException('Unsupported backup key version');
      return KeyEnvelope(
        kdf: KdfParams.fromJson((j['kdf'] as Map).cast<String, dynamic>()),
        salt: base64.decode(j['salt'] as String),
        wrappedKey: base64.decode(j['wrapped'] as String),
        secretKind: (j['kind'] as String?) ?? 'passphrase',
        createdAt: DateTime.parse(j['created'] as String),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('The backup key file is damaged');
    }
  }
}
