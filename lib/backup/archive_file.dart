import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'backup_provider.dart';

/// `.pulsebak`: the whole backup (key envelope, manifests, chunks) in one
/// file, for export and import. Layout: magic, then repeated
/// `u16 nameLength | name | u64 dataLength | data`. It is a plain container;
/// all content is already ciphertext.
const archiveMagic = 'PULSEBAK1\n';
const archiveExtension = 'pulsebak';

/// Streams objects straight to a file as the backup engine writes them, so a
/// large photo library never has to fit in memory.
class ArchiveWriterProvider implements BackupProvider {
  ArchiveWriterProvider(this.path);
  final String path;
  late final RandomAccessFile _file = File(path).openSync(mode: FileMode.write)..writeStringSync(archiveMagic);
  final _written = <String, int>{};

  @override
  String get id => 'file';
  @override
  String get label => 'Backup file';

  @override
  Future<void> ensureReady() async {}

  @override
  Future<List<BackupObject>> list(String prefix) async => [
    for (final e in _written.entries)
      if (e.key.startsWith(prefix)) BackupObject(e.key, e.value),
  ];

  @override
  Future<Uint8List?> read(String name) async => throw UnsupportedError('write-only');

  @override
  Future<void> write(String name, Uint8List bytes) async {
    if (_written.containsKey(name)) return;
    final n = utf8.encode(name);
    final head = ByteData(2)..setUint16(0, n.length);
    final len = ByteData(8)..setUint64(0, bytes.length);
    _file
      ..writeFromSync(head.buffer.asUint8List())
      ..writeFromSync(n)
      ..writeFromSync(len.buffer.asUint8List())
      ..writeFromSync(bytes);
    _written[name] = bytes.length;
  }

  @override
  Future<void> delete(Iterable<String> names) async {}

  Future<void> close() async {
    await _file.flush();
    await _file.close();
  }
}

class ArchiveFormatError implements Exception {
  const ArchiveFormatError([this.message = 'This is not a Pulse backup file.']);
  final String message;
  @override
  String toString() => message;
}

/// Read-only view of an archive. Indexes entry offsets once, reads bodies on
/// demand.
class ArchiveReaderProvider implements BackupProvider {
  ArchiveReaderProvider._(this.path, this._index);
  final String path;
  final Map<String, (int, int)> _index;

  static Future<ArchiveReaderProvider> open(String path) async {
    final f = await File(path).open();
    try {
      final total = await f.length();
      final magic = utf8.encode(archiveMagic);
      if (total < magic.length) throw const ArchiveFormatError();
      final head = await f.read(magic.length);
      for (var i = 0; i < magic.length; i++) {
        if (head[i] != magic[i]) throw const ArchiveFormatError();
      }
      final index = <String, (int, int)>{};
      var pos = magic.length;
      while (pos < total) {
        if (pos + 2 > total) throw const ArchiveFormatError('This backup file is cut short.');
        await f.setPosition(pos);
        final nameLen = ByteData.sublistView(await f.read(2)).getUint16(0);
        if (pos + 2 + nameLen + 8 > total) throw const ArchiveFormatError('This backup file is cut short.');
        final name = utf8.decode(await f.read(nameLen));
        final len = ByteData.sublistView(await f.read(8)).getUint64(0);
        final start = pos + 2 + nameLen + 8;
        if (start + len > total) throw const ArchiveFormatError('This backup file is cut short.');
        index[name] = (start, len);
        pos = start + len;
      }
      return ArchiveReaderProvider._(path, index);
    } finally {
      await f.close();
    }
  }

  @override
  String get id => 'file';
  @override
  String get label => 'Backup file';
  @override
  Future<void> ensureReady() async {}

  @override
  Future<List<BackupObject>> list(String prefix) async => [
    for (final e in _index.entries)
      if (e.key.startsWith(prefix)) BackupObject(e.key, e.value.$2),
  ];

  @override
  Future<Uint8List?> read(String name) async {
    final e = _index[name];
    if (e == null) return null;
    final f = await File(path).open();
    try {
      await f.setPosition(e.$1);
      return await f.read(e.$2);
    } finally {
      await f.close();
    }
  }

  @override
  Future<void> write(String name, Uint8List bytes) async => throw UnsupportedError('read-only');
  @override
  Future<void> delete(Iterable<String> names) async => throw UnsupportedError('read-only');
}
