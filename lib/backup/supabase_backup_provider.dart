import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'backup_provider.dart';

/// Supabase Storage (free tier) in a private bucket. Every object lives under
/// `<user id>/`, and the RLS policies in `docs/BACKUP.md` only allow a user
/// to touch that prefix. Objects are ciphertext; the server never sees a key.
///
/// The free tier allows files up to 50 MB and 1 GB of storage in total; our
/// chunks are at most 2 MiB, so only the 1 GB total matters.
class SupabaseBackupProvider implements BackupProvider {
  SupabaseBackupProvider(this._client, {this.bucket = 'pulse-backups'});
  final SupabaseClient _client;
  final String bucket;

  @override
  String get id => 'supabase';
  @override
  String get label => 'Pulse cloud (encrypted)';

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const BackupProviderUnavailable('Sign in to use cloud backup.');
    return id;
  }

  StorageFileApi get _store => _client.storage.from(bucket);
  String _path(String name) => '$_uid/$name';

  @override
  Future<void> ensureReady() async {
    _uid;
  }

  @override
  Future<List<BackupObject>> list(String prefix) async {
    // Storage lists one folder at a time: split `chunks/ab12` into the folder
    // `chunks` and a filename prefix.
    final slash = prefix.lastIndexOf('/');
    final folder = slash < 0 ? '' : prefix.substring(0, slash);
    final filePrefix = slash < 0 ? prefix : prefix.substring(slash + 1);
    final dirs = <String>[folder];
    final out = <BackupObject>[];
    // Root-level listings also return folders; descend into those that match.
    if (slash < 0) {
      for (final d in const ['manifests', 'chunks']) {
        if (d.startsWith(filePrefix)) dirs.add(d);
      }
    }
    for (final dir in dirs) {
      var offset = 0;
      while (true) {
        final page = await _store.list(
          path: dir.isEmpty ? _uid : '$_uid/$dir',
          searchOptions: SearchOptions(limit: 100, offset: offset),
        );
        for (final f in page) {
          if (f.id == null) continue; // a folder placeholder
          final name = dir.isEmpty ? f.name : '$dir/${f.name}';
          if (!name.startsWith(prefix)) continue;
          final size = (f.metadata?['size'] as num?)?.toInt() ?? 0;
          out.add(BackupObject(name, size, DateTime.tryParse(f.updatedAt ?? f.createdAt ?? '')));
        }
        if (page.length < 100) break;
        offset += page.length;
      }
    }
    return out;
  }

  @override
  Future<Uint8List?> read(String name) async {
    try {
      return await _store.download(_path(name));
    } on StorageException catch (e) {
      if (e.statusCode == '404' || e.statusCode == '400' && (e.message.contains('not found') || e.message.contains('Object'))) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> write(String name, Uint8List bytes) async {
    await _store.uploadBinary(
      _path(name),
      bytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'application/octet-stream'),
    );
  }

  @override
  Future<void> delete(Iterable<String> names) async {
    final list = [for (final n in names) _path(n)];
    for (var i = 0; i < list.length; i += 100) {
      await _store.remove(list.sublist(i, i + 100 > list.length ? list.length : i + 100));
    }
  }
}
