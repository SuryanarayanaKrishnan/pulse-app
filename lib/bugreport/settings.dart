import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/env/env.dart';

/// "Shake to report a bug" in Settings > Beta tools. On by default in beta
/// builds, off otherwise; the choice is remembered.
class ShakeEnabledController extends Notifier<bool> {
  static const _key = 'bugreport.shake';

  @override
  bool build() {
    _load();
    return Env.betaBuild;
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getBool(_key);
      if (v != null && ref.mounted) state = v;
    } catch (_) {
      // No storage: keep the default.
    }
  }

  Future<void> set(bool on) async {
    state = on;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_key, on);
    } catch (_) {}
  }
}

final shakeEnabledProvider = NotifierProvider<ShakeEnabledController, bool>(
  ShakeEnabledController.new,
);
