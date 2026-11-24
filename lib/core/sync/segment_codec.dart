import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../backup/backup_crypto.dart';
import 'change.dart';

/// A decoded segment: one device's numbered batch of field writes.
class Segment {
  const Segment({
    required this.device,
    required this.seq,
    required this.schemaVersion,
    required this.changes,
  });
  final String device;
  final int seq;

  /// The app's database schema version on the writing device.
  final int schemaVersion;
  final List<Change> changes;
}

/// Object names. Segments are immutable per (device, seq) except for a
/// byte-identical retry; the name is the AEAD associated data, so the server
/// cannot hand one segment out under another name.
class SegmentName {
  static const prefix = 'sync/';
  static String of(String device, int seq) =>
      '$prefix$device/${seq.toString().padLeft(10, '0')}.seg';

  /// (device, seq), or null when [name] is not a segment name.
  static (String, int)? parse(String name) {
    final m = RegExp(r'^sync/([0-9a-f]{16})/(\d{10})\.seg$').firstMatch(name);
    if (m == null) return null;
    return (m.group(1)!, int.parse(m.group(2)!));
  }
}

/// Encrypts and decrypts segments with a sub-key of the backup data key
/// (HKDF, purpose `sync.segments`), so the sync log and the backup share one
/// recovery secret but never one raw key. AES-256-GCM, random nonce.
class SegmentCodec {
  SegmentCodec._(this._key);
  final SecretKey _key;

  static Future<SegmentCodec> forDataKey(List<int> dataKey) async =>
      SegmentCodec._(await BackupCrypto.subKey(dataKey, 'sync.segments'));

  Object? _enc(Object? v) => v is Uint8List ? {r'$b': base64.encode(v)} : v;
  Object? _dec(Object? v) =>
      v is Map && v[r'$b'] is String ? base64.decode(v[r'$b'] as String) : v;

  Future<Uint8List> encode(Segment s) {
    final plain = utf8.encode(
      jsonEncode({
        'v': 1,
        'd': s.device,
        's': s.seq,
        'sv': s.schemaVersion,
        'c': [
          for (final c in s.changes)
            [c.table, c.row, c.field, _enc(c.value), c.hlc.toString()],
        ],
      }),
    );
    return BackupCrypto.seal(
      _key,
      plain,
      aad: utf8.encode(SegmentName.of(s.device, s.seq)),
    );
  }

  /// Throws [BackupIntegrityError] when the bytes were altered, truncated,
  /// made with another key or stored under another name, and
  /// [FormatException] when the content is not a segment.
  Future<Segment> decode(String name, Uint8List blob) async {
    final plain = await BackupCrypto.open(
      _key,
      blob,
      aad: utf8.encode(name),
    );
    final j = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    if (j['v'] != 1) throw const FormatException('Unknown segment version');
    final seg = Segment(
      device: j['d'] as String,
      seq: j['s'] as int,
      schemaVersion: j['sv'] as int,
      changes: [
        for (final c in (j['c'] as List))
          Change.fromJson([
            (c as List)[0],
            c[1],
            c[2],
            _dec(c[3]),
            c[4],
          ]),
      ],
    );
    if (SegmentName.of(seg.device, seg.seq) != name) {
      throw const BackupIntegrityError('segment name');
    }
    return seg;
  }
}
