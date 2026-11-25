import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'attachments.dart';
import 'db_key.dart';
import 'ids.dart';

/// Files for the family vault (photos and PDFs of papers), encrypted on the
/// phone with AES-256-GCM. The key is derived (HKDF-SHA256) from the database
/// key in the platform keystore, so nothing readable is ever on disk, and a
/// backup restore, which brings the database key back with it, can read the
/// files it restores.
///
/// File layout: `PAT1` magic, 12-byte nonce, ciphertext, 16-byte tag.
class EncryptedAttachmentStorage implements AttachmentStorage {
  EncryptedAttachmentStorage({
    required this.keys,
    Future<Directory> Function()? root,
    this.maxBytes = 25 * 1024 * 1024,
  }) : _root = root ?? _defaultRoot;

  final DatabaseKeyStore keys;
  final Future<Directory> Function() _root;

  /// Largest file accepted (the whole file is encrypted in memory).
  final int maxBytes;

  static const _magic = [0x50, 0x41, 0x54, 0x31];
  static final _aes = AesGcm.with256bits();

  static Future<Directory> _defaultRoot() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'attachments'));
  }

  Future<SecretKey> _key() async {
    final dbKey = await keys.loadOrCreate();
    return Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: SecretKey(utf8.encode(dbKey)),
      info: utf8.encode('pulse.attachments.v1'),
      nonce: const <int>[],
    );
  }

  static bool isEncrypted(List<int> b) =>
      b.length > _magic.length + 28 &&
      _magic.indexed.every((e) => b[e.$1] == e.$2);

  @override
  Future<String> import(String sourcePath) async {
    final src = File(sourcePath);
    if (await src.length() > maxBytes) {
      throw const FileTooLarge();
    }
    final plain = await src.readAsBytes();
    final box = await _aes.encrypt(plain, secretKey: await _key());
    final out = BytesBuilder(copy: false)
      ..add(_magic)
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    final dir = await _root();
    await dir.create(recursive: true);
    final ext = p.extension(sourcePath).toLowerCase();
    final dest = p.join(dir.path, '${newId()}${ext.isEmpty ? '' : ext}.enc');
    await File(dest).writeAsBytes(out.toBytes(), flush: true);
    return dest;
  }

  @override
  Future<Uint8List?> read(String path) async {
    if (path.startsWith('demo:')) return null;
    final f = File(path);
    if (!await f.exists()) return null;
    final b = await f.readAsBytes();
    // Photos saved before encryption was added are still readable.
    if (!isEncrypted(b)) return b;
    final nonce = b.sublist(4, 16);
    final mac = Mac(b.sublist(b.length - 16));
    final cipher = b.sublist(16, b.length - 16);
    final plain = await _aes.decrypt(
      SecretBox(cipher, nonce: nonce, mac: mac),
      secretKey: await _key(),
    );
    return Uint8List.fromList(plain);
  }

  @override
  Future<void> delete(Iterable<String> paths) =>
      PrivateAttachmentStorage(root: _root).delete(paths);
}

class FileTooLarge implements Exception {
  const FileTooLarge();
  @override
  String toString() => 'That file is over 25 MB. Try a smaller photo or PDF.';
}
