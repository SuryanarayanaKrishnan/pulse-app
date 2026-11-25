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
  });

  final KvStore kv;
  final RemoteConfigService config;
  final Dio? dio;
  final Future<String?> Function(String name)? bundled;
  final String basePath;

  final _packs = <String, Map<String, Object?>>{};

  /// Loads the bundled copy and any cached download for [names].
  Future<void> load(Iterable<String> names) async {
    for (final n in names) {
      Map<String, Object?>? best = _decode(await _bundled(n));
      final cached = _decode(await kv.read('pack.$n'));
      if (cached != null && (best == null || _v(cached) >= _v(best))) best = cached;
      if (best != null) _packs[n] = best;
    }
  }

  Future<String?> _bundled(String n) async {
    try {
      return await (bundled ?? (name) => rootBundle.loadString('assets/packs/$name.json'))(n);
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
      final manifest = await config.verifyEnvelope(Map<String, Object?>.from(res.data! as Map));
      final listed = Map<String, Object?>.from((manifest?['packs'] as Map?) ?? const {});
      for (final e in listed.entries) {
        final remoteVersion = (e.value as Map)['version'];
        final have = _packs[e.key];
        if (remoteVersion is! int || (have != null && remoteVersion <= _v(have))) continue;
        try {
          final r = await client.get<Object?>('$basePath/${e.key}');
          if (r.data is! Map) continue;
          final body = await config.verifyEnvelope(Map<String, Object?>.from(r.data! as Map));
          if (body == null || body['version'] is! int) continue;
          await kv.write('pack.${e.key}', jsonEncode(body));
          _packs[e.key] = body;
          changed.add(e.key);
        } on Object {
          continue;
        }
      }
    } on Object {
      return changed;
    }
    return changed;
  }
}
