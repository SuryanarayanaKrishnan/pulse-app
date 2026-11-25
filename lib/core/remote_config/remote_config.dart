import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../capture/kv_store.dart';

/// One feature flag from the backend config.
class RemoteFlag {
  const RemoteFlag({required this.enabled, this.rolloutPct = 100, this.plan});
  final bool enabled;

  /// 0..100. Decided on this phone from a random local id, so the server
  /// never learns who is asking.
  final int rolloutPct;

  /// Optional hint ('plus') for flags that sit behind a paid plan.
  final String? plan;

  factory RemoteFlag.fromJson(Map<String, Object?> j) => RemoteFlag(
    enabled: j['enabled'] == true,
    rolloutPct: (j['rollout_pct'] as num?)?.toInt().clamp(0, 100) ?? 100,
    plan: j['plan'] as String?,
  );
}

/// A parsed config document (flags and params).
class RemoteConfig {
  const RemoteConfig({
    required this.version,
    this.flags = const {},
    this.params = const {},
    this.killSwitches = const [],
    this.minSupportedBuild = 0,
  });

  final int version;
  final Map<String, RemoteFlag> flags;
  final Map<String, Object?> params;
  final List<String> killSwitches;
  final int minSupportedBuild;

  factory RemoteConfig.fromJson(Map<String, Object?> j) => RemoteConfig(
    version: (j['version'] as num).toInt(),
    flags: {
      for (final e in ((j['flags'] as Map?) ?? const {}).entries)
        e.key as String: RemoteFlag.fromJson(Map<String, Object?>.from(e.value as Map)),
    },
    params: Map<String, Object?>.from((j['params'] as Map?) ?? const {}),
    killSwitches: [for (final k in (j['kill_switches'] as List?) ?? const []) '$k'],
    minSupportedBuild: (j['min_supported_build'] as num?)?.toInt() ?? 0,
  );
}

/// Stable 0..99 bucket for [installId] and [flag] (FNV-1a), so a flag at
/// 20% reaches the same 20% of phones every time and different flags
/// pick different phones.
int rolloutBucket(String installId, String flag) {
  var h = 0x811c9dc5;
  for (final b in utf8.encode('$installId:$flag')) {
    h = ((h ^ b) * 0x01000193) & 0xffffffff;
  }
  return h % 100;
}

/// Canonical JSON identical to the backend's: sorted keys, no spaces.
String canonicalJson(Object? v) {
  Object? norm(Object? x) {
    if (x is Map) {
      final keys = x.keys.map((k) => '$k').toList()..sort();
      return {for (final k in keys) k: norm(x[k])};
    }
    if (x is List) return [for (final e in x) norm(e)];
    return x;
  }

  return jsonEncode(norm(v));
}

Future<bool> verifyConfigSignature({
  required Map<String, Object?> payload,
  required String signatureB64,
  required String publicKeyB64,
}) async {
  try {
    return await Ed25519().verify(
      utf8.encode(canonicalJson(payload)),
      signature: Signature(
        base64.decode(signatureB64),
        publicKey: SimplePublicKey(base64.decode(publicKeyB64), type: KeyPairType.ed25519),
      ),
    );
  } on Object {
    return false;
  }
}

/// Feature flags and tunable parameters from the backend, usable offline.
///
/// Order of trust: last verified download, else the bundled
/// `assets/config/remote_config.json`. A download is applied only when its
/// signature checks out (or, in dev with no key set, when [publicKeyB64] is
/// empty) and its version is newer. Nothing identifying is ever sent.
class RemoteConfigService {
  RemoteConfigService({
    required this.kv,
    this.dio,
    this.publicKeyB64 = '',
    this.bundled,
    this.path = '/v1/config',
    this.randomId,
  });

  final KvStore kv;
  final Dio? dio;
  final String publicKeyB64;
  final Future<String> Function()? bundled;
  final String path;
  final String Function()? randomId;

  static const _cacheKey = 'remote_config.cached';
  static const _idKey = 'remote_config.install_id';

  RemoteConfig _config = const RemoteConfig(version: 0);
  String _installId = '';
  RemoteConfig get config => _config;

  /// Loads cached or bundled config. Call once at startup; never throws.
  Future<void> load() async {
    _installId = await kv.read(_idKey) ?? '';
    if (_installId.isEmpty) {
      _installId = randomId?.call() ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      await kv.write(_idKey, _installId);
    }
    final bundledCfg = await _parse(await (bundled ?? _bundledAsset)());
    var best = bundledCfg;
    final cached = await kv.read(_cacheKey);
    if (cached != null) {
      final c = await _parse(cached);
      if (c != null && (best == null || c.version >= best.version)) best = c;
    }
    _config = best ?? _config;
  }

  Future<String> _bundledAsset() => rootBundle.loadString('assets/config/remote_config.json');

  Future<RemoteConfig?> _parse(String raw) async {
    try {
      return RemoteConfig.fromJson(Map<String, Object?>.from(jsonDecode(raw) as Map));
    } on Object {
      return null;
    }
  }

  /// Fetches a newer signed config. True when one was applied.
  Future<bool> refresh() async {
    final client = dio;
    if (client == null) return false;
    try {
      final res = await client.get<Object?>(path);
      final data = res.data;
      if (data is! Map) return false;
      final payload = Map<String, Object?>.from(data['payload'] as Map);
      final sig = data['signature'] as String?;
      if (publicKeyB64.isNotEmpty) {
        if (sig == null || !await verifyConfigSignature(payload: payload, signatureB64: sig, publicKeyB64: publicKeyB64)) {
          return false;
        }
      }
      final next = RemoteConfig.fromJson(payload);
      if (next.version <= _config.version) return false;
      await kv.write(_cacheKey, jsonEncode(payload));
      _config = next;
      return true;
    } on Object {
      return false;
    }
  }

  /// Whether [flag] is on for this phone. Unknown flags, kill-switched
  /// flags and disabled flags are off.
  bool isOn(String flag) {
    if (_config.killSwitches.contains(flag)) return false;
    final f = _config.flags[flag];
    if (f == null || !f.enabled) return false;
    if (f.rolloutPct >= 100) return true;
    return rolloutBucket(_installId, flag) < f.rolloutPct;
  }

  T param<T>(String key, T fallback) {
    final v = _config.params[key];
    return v is T ? v : fallback;
  }
}
