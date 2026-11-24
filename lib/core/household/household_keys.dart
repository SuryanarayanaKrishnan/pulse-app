import 'dart:typed_data';

/// Where this phone keeps the household key. Like the backup data key it
/// lives in the platform keystore, never in the database and never in the
/// user's own sync log.
abstract class HouseholdKeyStore {
  Future<Uint8List?> load();
  Future<void> save(Uint8List key);
  Future<void> clear();
}

class MemoryHouseholdKeyStore implements HouseholdKeyStore {
  Uint8List? key;
  @override
  Future<Uint8List?> load() async => key;
  @override
  Future<void> save(Uint8List k) async => key = Uint8List.fromList(k);
  @override
  Future<void> clear() async => key = null;
}
