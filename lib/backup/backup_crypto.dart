import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show compute;

/// Thrown when ciphertext fails authentication (tampered, truncated, wrong
/// key). Callers show a calm message; the detail never includes key material.
class BackupIntegrityError implements Exception {
  const BackupIntegrityError([this.what = 'data']);
  final String what;
  @override
  String toString() => 'Backup integrity check failed ($what)';
}

/// The passphrase or recovery phrase did not unwrap the data key.
class WrongPassphrase implements Exception {
  const WrongPassphrase();
  @override
  String toString() => 'That passphrase or recovery phrase is not right.';
}

/// Argon2id cost parameters, stored next to the wrapped key so a backup made
/// today still opens when the defaults are raised later.
class KdfParams {
  const KdfParams({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
  });

  /// OWASP's second Argon2id recommendation (19 MiB, t=2) with one extra
  /// pass. Pure-Dart Argon2id on a phone, so we stay modest.
  static const production = KdfParams(
    memoryKiB: 19456,
    iterations: 3,
    parallelism: 1,
  );

  /// Tests only: fast and weak.
  static const testing = KdfParams(
    memoryKiB: 64,
    iterations: 1,
    parallelism: 1,
  );

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  /// Upper bounds protect against a hostile envelope asking for gigabytes.
  void validate({int minMemoryKiB = 8}) {
    if (memoryKiB < minMemoryKiB ||
        memoryKiB > 1024 * 1024 ||
        iterations < 1 ||
        iterations > 20 ||
        parallelism < 1 ||
        parallelism > 8) {
      throw const FormatException('Unsupported key derivation settings');
    }
  }

  Map<String, Object> toJson() => {
    'alg': 'argon2id',
    'm': memoryKiB,
    't': iterations,
    'p': parallelism,
  };

  static KdfParams fromJson(Map<String, dynamic> j) {
    if (j['alg'] != 'argon2id')
      throw const FormatException('Unknown key derivation');
    return KdfParams(
      memoryKiB: j['m'] as int,
      iterations: j['t'] as int,
      parallelism: j['p'] as int,
    );
  }
}

class _KdfJob {
  _KdfJob(this.secret, this.salt, this.params);
  final List<int> secret;
  final List<int> salt;
  final KdfParams params;
}

Future<List<int>> _argon2(_KdfJob j) async {
  final algo = Argon2id(
    memory: j.params.memoryKiB,
    iterations: j.params.iterations,
    parallelism: j.params.parallelism,
    hashLength: 32,
  );
  final key = await algo.deriveKeyFromPassword(
    password: utf8.decode(j.secret),
    nonce: j.salt,
  );
  return key.extractBytes();
}

/// Everything cryptographic lives here so it can be reviewed in one file.
///
/// * Master key: Argon2id(secret, salt), 32 bytes. It only ever wraps the
///   data key and is dropped straight after.
/// * Data key: 32 random bytes, generated once on the phone. HKDF-SHA256
///   derives three independent sub-keys from it: chunk encryption, manifest
///   encryption and the chunk-naming MAC.
/// * Objects: `0x01 || nonce(12) || ciphertext || tag(16)`, AES-256-GCM with a
///   random nonce and the object's name or id as associated data, so a server
///   cannot swap one object for another.
class BackupCrypto {
  BackupCrypto._();

  static final _aes = AesGcm.with256bits();
  static const _version = 1;
  static const nonceLength = 12;
  static const tagLength = 16;
  static final _hmac = Hmac.sha256();

  static Uint8List randomBytes(int n) =>
      Uint8List.fromList(SecretKeyData.random(length: n).bytes);

  static Future<SecretKey> deriveMasterKey(
    String secret,
    List<int> salt,
    KdfParams params,
  ) async {
    params.validate();
    final bytes = await compute(
      _argon2,
      _KdfJob(utf8.encode(secret), salt, params),
    );
    return SecretKey(bytes);
  }

  static Future<SecretKey> subKey(List<int> dataKey, String purpose) =>
      Hkdf(hmac: _hmac, outputLength: 32).deriveKey(
        secretKey: SecretKey(dataKey),
        nonce: utf8.encode('pulse.backup.v1'),
        info: utf8.encode(purpose),
      );

  static Future<Uint8List> seal(
    SecretKey key,
    List<int> plain, {
    required List<int> aad,
  }) async {
    final box = await _aes.encrypt(plain, secretKey: key, aad: aad);
    final out = BytesBuilder(copy: false)
      ..addByte(_version)
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return out.toBytes();
  }

  static Future<Uint8List> open(
    SecretKey key,
    Uint8List blob, {
    required List<int> aad,
  }) async {
    if (blob.length < 1 + nonceLength + tagLength || blob[0] != _version) {
      throw const BackupIntegrityError('format');
    }
    final nonce = blob.sublist(1, 1 + nonceLength);
    final mac = blob.sublist(blob.length - tagLength);
    final cipher = blob.sublist(1 + nonceLength, blob.length - tagLength);
    try {
      final plain = await _aes.decrypt(
        SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
        aad: aad,
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const BackupIntegrityError();
    }
  }

  /// Keyed content address: equal plaintext gives an equal id for this user
  /// (so unchanged chunks are not re-uploaded) but the server cannot test a
  /// guessed file against it.
  static Future<String> chunkId(SecretKey idKey, List<int> plain) async {
    final mac = await _hmac.calculateMac(plain, secretKey: idKey);
    return hex(mac.bytes);
  }

  static String hex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
