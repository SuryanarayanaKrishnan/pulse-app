import 'dart:typed_data';

import 'package:pulse/core/sync/sync_bridge.dart';
import 'package:pulse/core/sync/sync_engine.dart';
import 'package:pulse/core/sync/sync_state.dart';
import 'package:pulse/core/sync/sync_transport.dart';

final testKey = Uint8List.fromList(List.generate(32, (i) => i + 1));

/// A simulated phone: its own tables, state store and clock, sharing the
/// "server" with the others.
class Device {
  Device(
    this.name,
    this.transport, {
    int startMs = 1000000,
    List<int>? key,
    int schema = 1,
    String? id,
  }) : bridge = MemoryBridge(schemaVersion: schema),
       store = MemorySyncStateStore(),
       nowMs = startMs {
    _key = key ?? testKey;
    _id = id ?? name.padRight(16, '0');
    engine = _build();
  }

  final String name;
  final MemorySyncTransport transport;
  final MemoryBridge bridge;
  final MemorySyncStateStore store;
  late final List<int> _key;
  late final String _id;
  late SyncEngine engine;
  int nowMs;

  SyncEngine _build() => SyncEngine(
    bridge: bridge,
    transport: transport,
    store: store,
    dataKey: _key,
    nowMs: () => nowMs,
    newDeviceId: () => _id,
    maxPerSegment: 5,
  );

  /// Simulates an app restart: engine rebuilt, state reloaded from the store.
  void restart() => engine = _build();

  Future<SyncReport> sync([int advanceMs = 1000]) {
    nowMs += advanceMs;
    return engine.sync();
  }

  void edit(
    String table,
    String id,
    Map<String, Object?> values, [
    int advanceMs = 1000,
  ]) {
    nowMs += advanceMs;
    bridge.put(table, id, values);
  }

  void delete(String table, String id, [int advanceMs = 1000]) {
    nowMs += advanceMs;
    bridge.remove(table, id);
  }

  Map<String, Object?>? row(String t, String id) => bridge.row(t, id);
}

/// Syncs the devices in order until nothing moves.
Future<void> settle(List<Device> ds, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    var idle = true;
    for (final d in ds) {
      final r = await d.sync();
      if (!r.idle) idle = false;
    }
    if (idle) return;
  }
}
