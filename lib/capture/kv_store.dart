import 'package:shared_preferences/shared_preferences.dart';

/// Minimal async string store so the queue and flags can be tested without
/// platform plugins.
abstract class KvStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class MemoryKvStore implements KvStore {
  final data = <String, String>{};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> remove(String key) async => data.remove(key);
}

/// Backed by `shared_preferences` (survives app restarts and updates).
class SharedPrefsKvStore implements KvStore {
  SharedPrefsKvStore({this.prefix = 'pulse.'});
  final String prefix;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<String?> read(String key) async =>
      (await _prefs).getString('$prefix$key');
  @override
  Future<void> write(String key, String value) async {
    await (await _prefs).setString('$prefix$key', value);
  }

  @override
  Future<void> remove(String key) async {
    await (await _prefs).remove('$prefix$key');
  }
}
