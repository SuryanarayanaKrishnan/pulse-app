import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/sync/sync_transport.dart';

/// Segments in the same private Supabase Storage bucket as the backup
/// (`pulse-backups`), under `<user id>/sync/<device>/<seq>.seg`. The bucket's
/// per-user policies in `docs/BACKUP.md` already cover this prefix. The
/// server only ever holds ciphertext.
///
/// Compiled but not exercised against a real Supabase project.
class SupabaseSyncTransport implements SyncTransport {
  SupabaseSyncTransport(this._client, {this.bucket = 'pulse-backups'});
  final SupabaseClient _client;
  final String bucket;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const SyncUnavailable('Sign in to sync your devices.');
    return id;
  }

  StorageFileApi get _store => _client.storage.from(bucket);

  @override
  Future<void> ensureReady() async {
    _uid;
  }

  Future<List<FileObject>> _page(String path) async {
    final out = <FileObject>[];
    var offset = 0;
    while (true) {
      final page = await _store.list(
        path: path,
        searchOptions: SearchOptions(limit: 100, offset: offset),
      );
      out.addAll(page);
      if (page.length < 100) return out;
      offset += page.length;
    }
  }

  @override
  Future<List<String>> list(String prefix) async {
    // Layout is fixed: sync/<device>/<file>. Walk the two levels.
    if (prefix != 'sync/') throw ArgumentError('Only the sync/ prefix is listed');
    final names = <String>[];
    for (final d in await _page('$_uid/sync')) {
      if (d.id != null) continue; // a file at the device level: not ours
      for (final f in await _page('$_uid/sync/${d.name}')) {
        if (f.id != null) names.add('sync/${d.name}/${f.name}');
      }
    }
    return names;
  }

  @override
  Future<Uint8List?> read(String name) async {
    try {
      return await _store.download('$_uid/$name');
    } on StorageException catch (e) {
      if (e.statusCode == '404' ||
          e.statusCode == '400' &&
              (e.message.contains('not found') || e.message.contains('Object'))) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> write(String name, Uint8List bytes) async {
    await _store.uploadBinary(
      '$_uid/$name',
      bytes,
      fileOptions: const FileOptions(
        upsert: true,
        contentType: 'application/octet-stream',
      ),
    );
  }
}
