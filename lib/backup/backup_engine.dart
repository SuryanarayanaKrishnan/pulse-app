import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import '../data/local/database.dart';
import '../data/local/ids.dart';
import 'backup_crypto.dart';
import 'backup_format.dart';
import 'backup_provider.dart';
import 'db_snapshot.dart';
import 'key_envelope.dart';

const keyObject = 'key.json';
const manifestPrefix = 'manifests/';
const chunkPrefix = 'chunks/';

/// Rewrites a dump made by an older schema into the shape the current schema
/// expects. Keyed by the schema version it upgrades FROM (n -> n+1). Empty
/// today: v1 -> v2 only added tables, which restore by simply being absent.
typedef RowUpgrader = void Function(Map<String, TableDump> tables);

class BackupStats {
  const BackupStats({
    required this.manifestName,
    required this.createdAt,
    required this.chunksUploaded,
    required this.chunksReused,
    required this.bytesUploaded,
    required this.rows,
    required this.attachments,
    required this.skippedAttachments,
  });
  final String manifestName;
  final DateTime createdAt;
  final int chunksUploaded;
  final int chunksReused;
  final int bytesUploaded;
  final int rows;
  final int attachments;
  final int skippedAttachments;
}

class RestoreStats {
  const RestoreStats({required this.rows, required this.attachments, required this.createdAt});
  final int rows;
  final int attachments;
  final DateTime createdAt;
}

/// Creates, lists and restores encrypted snapshots on a [BackupProvider].
///
/// Layout in the store:
/// ```
/// key.json                     wrapped data key + Argon2id parameters
/// manifests/<time>-<id>.bin    encrypted manifest per snapshot
/// chunks/<hmac id>             encrypted, content-addressed pieces
/// ```
/// A snapshot exists only once its manifest is written, and the manifest is
/// written last, so an interrupted upload leaves unreferenced chunks but
/// never a half snapshot.
class BackupEngine {
  BackupEngine({
    required this.provider,
    required this.dataKey,
    this.chunkSize = 2 * 1024 * 1024,
    this.rowsPerChunk = 400,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final BackupProvider provider;
  final Uint8List dataKey;
  final int chunkSize;
  final int rowsPerChunk;
  final DateTime Function() _clock;

  SecretKey? _chunkKey, _manifestKey, _idKey;

  Future<void> _init() async {
    _chunkKey ??= await BackupCrypto.subKey(dataKey, 'chunk');
    _manifestKey ??= await BackupCrypto.subKey(dataKey, 'manifest');
    _idKey ??= await BackupCrypto.subKey(dataKey, 'id');
  }

  /// A snapshot id from the key envelope in [provider], or null.
  static Future<KeyEnvelope?> readEnvelope(BackupProvider provider) async {
    final bytes = await provider.read(keyObject);
    return bytes == null ? null : KeyEnvelope.decode(bytes);
  }

  // ---- backup -------------------------------------------------------------

  Future<BackupStats> backup({
    required PulseDatabase db,
    int keep = 5,
    bool prune = true,
    void Function(double progress)? onProgress,
  }) async {
    await _init();
    await provider.ensureReady();
    final existing = {for (final o in await provider.list(chunkPrefix)) o.name};
    var uploaded = 0, reused = 0, bytes = 0;

    Future<String> put(Uint8List plain) async {
      final id = await BackupCrypto.chunkId(_idKey!, plain);
      final name = '$chunkPrefix$id';
      if (existing.contains(name)) {
        reused++;
      } else {
        final sealed = await BackupCrypto.seal(_chunkKey!, plain, aad: utf8.encode(id));
        await provider.write(name, sealed);
        existing.add(name);
        uploaded++;
        bytes += sealed.length;
      }
      return id;
    }

    final dumps = await dumpTables(db);
    final tables = <TableEntry>[];
    for (final d in dumps) {
      final ids = <String>[];
      for (var i = 0; i < d.rows.length; i += rowsPerChunk) {
        final end = i + rowsPerChunk > d.rows.length ? d.rows.length : i + rowsPerChunk;
        ids.add(await put(Uint8List.fromList(encodeChunk(d.name, d.columns, d.rows.sublist(i, end)))));
      }
      tables.add(TableEntry(name: d.name, rows: d.rows.length, chunks: ids));
    }
    onProgress?.call(0.2);

    final paths = _attachmentPaths(dumps);
    final attachments = <AttachmentEntry>[];
    var skipped = 0;
    var done = 0;
    for (final path in paths) {
      final f = File(path);
      if (!await f.exists()) {
        skipped++;
        continue;
      }
      final ids = <String>[];
      var size = 0;
      final raf = await f.open();
      try {
        while (true) {
          final part = await raf.read(chunkSize);
          if (part.isEmpty) break;
          size += part.length;
          ids.add(await put(part));
        }
      } finally {
        await raf.close();
      }
      final fileId = await BackupCrypto.chunkId(_idKey!, utf8.encode(ids.join(',')));
      attachments.add(AttachmentEntry(origPath: path, name: p.basename(path), size: size, fileId: fileId, chunks: ids));
      onProgress?.call(0.2 + 0.7 * (++done / paths.length));
    }

    final now = _clock().toUtc();
    final id = newId();
    final draft = BackupManifest(
      format: backupFormatVersion,
      appSchemaVersion: db.schemaVersion,
      createdAt: now,
      id: id,
      tables: tables,
      attachments: attachments,
      skippedAttachments: skipped,
      treeHash: '',
    );
    final manifest = BackupManifest(
      format: draft.format,
      appSchemaVersion: draft.appSchemaVersion,
      createdAt: now,
      id: id,
      tables: tables,
      attachments: attachments,
      skippedAttachments: skipped,
      treeHash: await _treeHash(draft.allChunks),
    );
    final name = '$manifestPrefix${now.millisecondsSinceEpoch.toString().padLeft(15, '0')}-${id.substring(0, 8)}.bin';
    final sealed = await BackupCrypto.seal(_manifestKey!, manifest.encode(), aad: utf8.encode(name));
    await provider.write(name, sealed);
    bytes += sealed.length;
    onProgress?.call(0.95);

    if (prune) await pruneOld(keep: keep);
    onProgress?.call(1);
    return BackupStats(
      manifestName: name,
      createdAt: now,
      chunksUploaded: uploaded,
      chunksReused: reused,
      bytesUploaded: bytes,
      rows: manifest.rowCount,
      attachments: attachments.length,
      skippedAttachments: skipped,
    );
  }

  Future<String> _treeHash(Set<String> chunkIds) {
    final sorted = chunkIds.toList()..sort();
    return BackupCrypto.chunkId(_idKey!, utf8.encode(sorted.join(',')));
  }

  /// File paths the ledger refers to (jewellery photos, document scans).
  static List<String> _attachmentPaths(List<TableDump> dumps) {
    const sources = {'jewellery_items': 'photo_paths', 'document_attachments': 'file_paths'};
    final out = <String>{};
    for (final d in dumps) {
      final col = sources[d.name];
      if (col == null) continue;
      final i = d.indexOfColumn(col);
      if (i < 0) continue;
      for (final row in d.rows) {
        final v = row[i];
        if (v is! String) continue;
        try {
          for (final path in (jsonDecode(v) as List).whereType<String>()) {
            if (!path.startsWith('demo:')) out.add(path);
          }
        } catch (_) {}
      }
    }
    return out.toList()..sort();
  }

  // ---- versions, retention ------------------------------------------------

  /// Readable snapshots, newest first. Manifests that fail authentication
  /// are left out (and counted by [corruptManifests] on the last call).
  int corruptManifests = 0;

  Future<List<BackupVersion>> versions() async {
    await _init();
    corruptManifests = 0;
    final names = [for (final o in await provider.list(manifestPrefix)) o.name]..sort();
    final out = <BackupVersion>[];
    for (final n in names.reversed) {
      try {
        out.add(BackupVersion(objectName: n, manifest: await readManifest(n)));
      } on BackupIntegrityError {
        corruptManifests++;
      } on FormatException {
        corruptManifests++;
      }
    }
    return out;
  }

  Future<BackupManifest> readManifest(String name) async {
    await _init();
    final blob = await provider.read(name);
    if (blob == null) throw const NoBackupFound();
    final plain = await BackupCrypto.open(_manifestKey!, blob, aad: utf8.encode(name));
    final m = BackupManifest.decode(plain);
    if (m.treeHash != await _treeHash(m.allChunks)) throw const BackupIntegrityError('manifest');
    return m;
  }

  /// Keeps the newest [keep] snapshots and deletes chunks nothing refers to
  /// any more. Chunks younger than [grace], or whose age the provider cannot report, are never deleted, so a backup
  /// running on another device is not undermined.
  Future<int> pruneOld({required int keep, Duration grace = const Duration(hours: 2)}) async {
    final all = [for (final o in await provider.list(manifestPrefix)) o.name]..sort();
    final drop = all.length > keep ? all.sublist(0, all.length - keep) : <String>[];
    if (drop.isNotEmpty) await provider.delete(drop);
    final live = <String>{};
    for (final n in all.skip(drop.length)) {
      try {
        live.addAll((await readManifest(n)).allChunks);
      } catch (_) {
        // Cannot read a kept manifest: delete nothing, to be safe.
        return drop.length;
      }
    }
    final cutoff = _clock().subtract(grace);
    final stale = [
      for (final o in await provider.list(chunkPrefix))
        if (!live.contains(o.name.substring(chunkPrefix.length)) && (o.modified != null && o.modified!.isBefore(cutoff)))
          o.name,
    ];
    if (stale.isNotEmpty) await provider.delete(stale);
    return drop.length;
  }

  /// Removes everything this backup owns from the destination.
  static Future<void> deleteEverything(BackupProvider provider) async {
    final names = [for (final o in await provider.list('')) o.name];
    if (names.isNotEmpty) await provider.delete(names);
  }

  // ---- restore ------------------------------------------------------------

  /// Reads a snapshot into [target] (a database that has just been created,
  /// never the live one) and copies its files into [attachmentsDir].
  ///
  /// Nothing is written until every piece has been found, decrypted and
  /// verified; files written along the way are removed again if a later step
  /// fails.
  Future<RestoreStats> restoreInto({
    required PulseDatabase target,
    required String manifestName,
    required Directory attachmentsDir,
    Map<int, RowUpgrader> upgraders = const {},
    void Function(double progress)? onProgress,
  }) async {
    await _init();
    final m = await readManifest(manifestName);
    if (m.format > backupFormatVersion || m.appSchemaVersion > target.schemaVersion) throw const BackupTooNew();

    final have = {for (final o in await provider.list(chunkPrefix)) o.name};
    final missing = m.allChunks.where((c) => !have.contains('$chunkPrefix$c')).length;
    if (missing > 0) throw BackupIncomplete(missing);

    Future<Uint8List> fetch(String id) async {
      final blob = await provider.read('$chunkPrefix$id');
      if (blob == null) throw const BackupIncomplete(1);
      final plain = await BackupCrypto.open(_chunkKey!, blob, aad: utf8.encode(id));
      if (await BackupCrypto.chunkId(_idKey!, plain) != id) throw const BackupIntegrityError('chunk');
      return plain;
    }

    // 1. Tables, in memory (they are small next to photos).
    final dumps = <String, TableDump>{};
    for (final t in m.tables) {
      TableDump? merged;
      for (final id in t.chunks) {
        final d = decodeChunk(await fetch(id));
        if (merged == null) {
          merged = d;
        } else {
          merged.rows.addAll(d.rows);
        }
      }
      dumps[t.name] = merged ?? TableDump(t.name, const [], []);
    }
    onProgress?.call(0.3);
    for (var v = m.appSchemaVersion; v < target.schemaVersion; v++) {
      upgraders[v]?.call(dumps);
    }

    // 2. Files.
    await attachmentsDir.create(recursive: true);
    final written = <File>[];
    final remap = <String, String>{};
    try {
      var done = 0;
      for (final a in m.attachments) {
        final ext = p.extension(a.name);
        final dest = File(p.join(attachmentsDir.path, '${newId()}${ext.isEmpty ? '.jpg' : ext}'));
        written.add(dest);
        final sink = dest.openWrite();
        try {
          for (final id in a.chunks) {
            sink.add(await fetch(id));
          }
        } finally {
          await sink.close();
        }
        if (await dest.length() != a.size) throw const BackupIntegrityError('file size');
        remap[a.origPath] = dest.path;
        onProgress?.call(0.3 + 0.6 * (++done / m.attachments.length));
      }

      _remapPaths(dumps['jewellery_items'], 'photo_paths', remap);
      _remapPaths(dumps['document_attachments'], 'file_paths', remap);

      // 3. Database.
      await importTables(target, dumps.values);
    } catch (_) {
      for (final f in written) {
        try {
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
      rethrow;
    }
    onProgress?.call(1);
    return RestoreStats(rows: m.rowCount, attachments: m.attachments.length, createdAt: m.createdAt);
  }

  static void _remapPaths(TableDump? d, String column, Map<String, String> remap) {
    if (d == null) return;
    final i = d.indexOfColumn(column);
    if (i < 0) return;
    for (final row in d.rows) {
      final v = row[i];
      if (v is! String) continue;
      try {
        final list = (jsonDecode(v) as List).whereType<String>().map((x) => remap[x] ?? x).toList();
        row[i] = jsonEncode(list);
      } catch (_) {}
    }
  }
}
