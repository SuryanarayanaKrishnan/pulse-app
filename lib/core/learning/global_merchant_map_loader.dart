/// Loads the global merchant map from the app bundle, and stores a refreshed
/// copy (see `docs/LEARNING.md`).
library;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../capture/kv_store.dart';
import 'global_merchant_map.dart';

/// Loads the bundled map and any refreshed copy stored on this phone.
class GlobalMerchantMapLoader {
  GlobalMerchantMapLoader({
    this.assetPath = 'assets/merchant_map.json',
    AssetBundle? bundle,
    this.kv,
  }) : _bundle = bundle ?? rootBundle;

  final String assetPath;
  final AssetBundle _bundle;
  final KvStore? kv;

  static const refreshedKey = 'learning.map.refreshed';

  /// The best map available: the bundled one, or a stored refreshed one with
  /// a higher version. Never throws; an unreadable asset gives
  /// [GlobalMerchantMap.empty] (categorisation just loses this step).
  Future<GlobalMerchantMap> load() async {
    var map = GlobalMerchantMap.empty;
    try {
      map = GlobalMerchantMap.parse(await _bundle.loadString(assetPath));
    } on Object {
      // Fall through with the empty map.
    }
    final kv = this.kv;
    if (kv != null) {
      try {
        final stored = await kv.read(refreshedKey);
        if (stored != null) {
          map = GlobalMerchantMap.newer(map, GlobalMerchantMap.parse(stored));
        }
      } on Object {
        // A bad stored copy is ignored.
      }
    }
    return map;
  }

  /// Offers a downloaded map. Stored only if it is valid and newer than
  /// [current]. Returns whether it was accepted.
  Future<bool> offerRefreshed(String json, GlobalMerchantMap current) async {
    final kv = this.kv;
    if (kv == null) return false;
    try {
      final candidate = GlobalMerchantMap.parse(json);
      if (candidate.version <= current.version || candidate.length == 0)
        return false;
      await kv.write(refreshedKey, json);
      return true;
    } on Object {
      return false;
    }
  }
}
