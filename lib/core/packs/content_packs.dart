import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../capture/kv_store.dart';
import '../remote_config/remote_config.dart';

/// Server-delivered content (tips, walkthrough text, parser rules) that
/// updates without an app build.
///
/// Each pack is a JSON object with an integer `version`. The newest of the
/// bundled copy (`assets/packs/<name>.json`) and the last verified download
/// wins, so the app works offline and a bad download never replaces
/// anything. Downloads must carry a valid signature (see
/// [RemoteConfigService.verifyEnvelope]). Reference content only: nothing
/// about the user is sent.
class ContentPackService {
  ContentPackService({
    required this.kv,
    required this.config,
    this.dio,
    this.bundled,
    this.basePath = '/v1/packs',
    this.buildNumber = 0,
  });

  final KvStore kv;
  final RemoteConfigService config;
  final Dio? dio;
  final Future<String?> Function(String name)? bundled;
  final String basePath;

  /// This app's build number, compared with a pack's `min_build`.
  final int buildNumber;

  final _packs = <String, Map<String, Object?>>{};

  /// Loads the bundled copy and any cached download for [names].
  Future<void> load(Iterable<String> names) async {
    for (final n in names) {
      Map<String, Object?>? best = _decode(await _bundled(n));
      final cached = _decode(await kv.read('pack.$n'));
      if (cached != null && (best == null || _v(cached) >= _v(best)))
        best = cached;
      if (best != null) _packs[n] = best;
    }
  }

  Future<String?> _bundled(String n) async {
    try {
      return await (bundled ??
          (name) => rootBundle.loadString('assets/packs/$name.json'))(n);
    } on Object {
      return null; // no bundled copy for this pack
    }
  }

  Map<String, Object?>? _decode(String? raw) {
    if (raw == null) return null;
    try {
      final m = Map<String, Object?>.from(jsonDecode(raw) as Map);
      return m['version'] is int ? m : null;
    } on Object {
      return null;
    }
  }

  int _v(Map<String, Object?> m) => m['version'] as int;

  /// The pack as last loaded, or null when there is none.
  Map<String, Object?>? pack(String name) => _packs[name];

  /// Downloads packs whose server version is newer. Returns the names that
  /// changed. Never throws.
  Future<List<String>> refresh() async {
    final client = dio;
    if (client == null) return const [];
    final changed = <String>[];
    try {
      final res = await client.get<Object?>(basePath);
      if (res.data is! Map) return const [];
      final manifest = await config.verifyEnvelope(
        Map<String, Object?>.from(res.data! as Map),
      );
      final listed = Map<String, Object?>.from(
        (manifest?['packs'] as Map?) ?? const {},
      );
      for (final e in listed.entries) {
        final c = Map<String, Object?>.from(e.value as Map);
        final name = e.key;
        final remoteVersion = c['version'];
        final maxVersion = c['max_version'];
        final have = _packs[name];

        // Kill switch (from the pack or the config) or a rollback ceiling:
        // forget the downloaded copy and go back to the bundled one.
        final killed = c['killed'] == true || config.isKilled('pack:$name');
        final tooNew = maxVersion is int && have != null && _v(have) > maxVersion;
        if (killed || tooNew) {
          if (await _dropDownloaded(name)) changed.add(name);
          continue;
        }

        if (remoteVersion is! int) continue;
        if (maxVersion is int && remoteVersion > maxVersion) continue;
        if (have != null && remoteVersion <= _v(have)) continue;
        if (((c['min_build'] as num?)?.toInt() ?? 0) > buildNumber) continue;
        final pct = (c['rollout_pct'] as num?)?.toInt() ?? 100;
        if (!config.inRollout('pack:$name', pct)) continue;
        try {
          final r = await client.get<Object?>('$basePath/$name');
          if (r.data is! Map) continue;
          final body = await config.verifyEnvelope(
            Map<String, Object?>.from(r.data! as Map),
          );
          if (body == null || body['version'] is! int) continue;
          await kv.write('pack.$name', jsonEncode(body));
          _packs[name] = body;
          changed.add(name);
        } on Object {
          continue;
        }
      }
    } on Object {
      return changed;
    }
    return changed;
  }

  /// Removes the downloaded copy of [name] and reloads the bundled one.
  /// True when the pack in use changed.
  Future<bool> _dropDownloaded(String name) async {
    if (await kv.read('pack.$name') == null) return false;
    await kv.remove('pack.$name');
    final before = _packs[name];
    final bundledCopy = _decode(await _bundled(name));
    if (bundledCopy == null) {
      _packs.remove(name);
    } else {
      _packs[name] = bundledCopy;
    }
    return before != _packs[name];
  }
}
