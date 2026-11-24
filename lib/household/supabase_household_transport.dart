import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/sync/sync_transport.dart';

/// The household log in a Supabase Storage bucket shared by its members:
/// `<household id>/household/<household id>/<device>/<seq>.seg` in the
/// bucket `pulse-households`. Only ciphertext is stored (the key never
/// leaves the members' phones).
///
/// Unlike the personal sync prefix, members are different Supabase users, so
/// the per-user policy of `docs/BACKUP.md` does not fit. The policy in
/// `docs/HOUSEHOLD.md` makes the 128-bit random household id the capability:
/// any signed-in user who knows it may read and write under it.
///
/// Compiled but NOT exercised against a real Supabase project.
class SupabaseHouseholdTransport implements SyncTransport {
  SupabaseHouseholdTransport(this._client, {required this.householdId, this.bucket = 'pulse-households'});
  final SupabaseClient _client;
  final String householdId;
  final String bucket;

  StorageFileApi get _store => _client.storage.from(bucket);

  String get _root => householdId;

  @override
  Future<void> ensureReady() async {
    if (_client.auth.currentUser == null) {
      throw const SyncUnavailable('Sign in to share with your household.');
    }
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
    // Layout: household/<id>/<device>/<file> under the household's folder.
    final expected = 'household/$householdId/';
    if (prefix != expected) throw ArgumentError('Only $expected is listed');
    final names = <String>[];
    for (final d in await _page('$_root/household/$householdId')) {
      if (d.id != null) continue;
      for (final f in await _page('$_root/household/$householdId/${d.name}')) {
        if (f.id != null) names.add('$expected${d.name}/${f.name}');
      }
    }
    return names;
  }

  @override
  Future<Uint8List?> read(String name) async {
    try {
      return await _store.download('$_root/$name');
    } on StorageException catch (e) {
      if (e.statusCode == '404' ||
          e.statusCode == '400' && (e.message.contains('not found') || e.message.contains('Object'))) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> write(String name, Uint8List bytes) async {
    await _store.uploadBinary(
      '$_root/$name',
      bytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'application/octet-stream'),
    );
  }
}
