import 'dart:typed_data';

/// Where encrypted segments live. It only ever sees opaque bytes under
/// names like `sync/<device>/<seq>.seg`.
abstract class SyncTransport {
  /// Throws [SyncUnavailable] when the transport cannot be used now (signed
  /// out, not configured).
  Future<void> ensureReady();

  /// Names (relative, as passed to [write]) of every object under [prefix].
  Future<List<String>> list(String prefix);

  /// Null when the object does not exist.
  Future<Uint8List?> read(String name);

  /// Creates or replaces. Replacing is only ever done with the same content
  /// (a retry), never to change history.
  Future<void> write(String name, Uint8List bytes);
}

class SyncUnavailable implements Exception {
  const SyncUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

/// In-memory transport for tests and demos. Shared by several devices to
/// simulate one server.
class MemorySyncTransport implements SyncTransport {
  final objects = <String, Uint8List>{};
  Object? failWrites;
  Object? failReads;
  int writes = 0;
  int reads = 0;

  /// Fail the Nth next write after it has been stored (a lost response).
  bool storeThenFail = false;

  @override
  Future<void> ensureReady() async {}

  @override
  Future<List<String>> list(String prefix) async => [
    for (final k in objects.keys)
      if (k.startsWith(prefix)) k,
  ];

  @override
  Future<Uint8List?> read(String name) async {
    if (failReads != null) throw failReads!;
    reads++;
    return objects[name];
  }

  @override
  Future<void> write(String name, Uint8List bytes) async {
    if (failWrites != null) {
      if (storeThenFail) objects[name] = Uint8List.fromList(bytes);
      throw failWrites!;
    }
    writes++;
    objects[name] = Uint8List.fromList(bytes);
  }
}
