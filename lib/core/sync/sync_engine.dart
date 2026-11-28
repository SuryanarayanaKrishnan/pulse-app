import 'dart:async';

import '../../backup/backup_crypto.dart';
import 'change.dart';
import 'segment_codec.dart';
import 'sync_bridge.dart';
import 'sync_state.dart';
import 'sync_transport.dart';

/// A sync run stopped for a reason the caller can name without leaking
/// content. [reason]: signed_out | too_new | integrity.
class SyncException implements Exception {
  const SyncException(this.reason, [this.message = '']);
  final String reason;
  final String message;
  @override
  String toString() =>
      'Sync stopped ($reason)${message.isEmpty ? '' : ': $message'}';
}

class SyncReport {
  int pushedChanges = 0;
  int pushedSegments = 0;
  int pulledSegments = 0;
  int appliedChanges = 0;
  int rowsWritten = 0;
  int localChanges = 0;

  bool get idle =>
      pushedChanges == 0 && pulledSegments == 0 && localChanges == 0;
}

/// Capture local edits, pull and merge other devices' segments, push ours.
///
/// Safe to run at any time, repeatedly, and to interrupt anywhere:
/// * merging is idempotent, so a segment read twice changes nothing;
/// * a segment is numbered and persisted before upload, so a retry resends
///   exactly the same bytes' content under the same name;
/// * read cursors only advance after the segment was merged and saved.
class SyncEngine {
  SyncEngine({
    required this.bridge,
    required this.transport,
    required this.store,
    required List<int> dataKey,
    int Function()? nowMs,
    String Function()? newDeviceId,
    this.maxPerSegment = 500,
    this.flushEvery = 25,
    this.namespace = 'sync',
    this.keyPurpose = 'sync.segments',
  }) : _dataKey = dataKey, // ignore: prefer_initializing_formals
       _now = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch),
       _newDeviceId = newDeviceId ?? _randomDeviceId;

  final SyncBridge bridge;
  final SyncTransport transport;
  final SyncStateStore store;
  final List<int> _dataKey;
  final int Function() _now;
  final String Function() _newDeviceId;
  final int maxPerSegment;
  final int flushEvery;

  /// Object-name namespace and HKDF purpose of this log. The defaults are a
  /// user's own device sync; a household log passes its own (see
  /// `core/household`).
  final String namespace;
  final String keyPurpose;

  SyncState? _state;
  SegmentCodec? _codec;
  Future<SyncReport>? _running;

  static String _randomDeviceId() =>
      BackupCrypto.hex(BackupCrypto.randomBytes(8));

  /// This device's id (after the first run).
  String? get deviceId => _state?.deviceId;

  /// Runs one sync; a call made while one is running joins it.
  Future<SyncReport> sync() =>
      _running ??= _run().whenComplete(() => _running = null);

  Future<SyncReport> _run() async {
    try {
      await transport.ensureReady();
    } on SyncUnavailable catch (e) {
      throw SyncException('signed_out', e.message);
    }
    final state = _state ??= (await store.load()) ?? SyncState(_newDeviceId());
    final codec = _codec ??= await SegmentCodec.forDataKey(
      _dataKey,
      purpose: keyPurpose,
      ns: namespace,
    );
    final report = SyncReport();

    if (state.bootstrapped) await _capture(state, report);
    await _writeRows(state, {...state.unapplied}, report);
    await _pull(state, codec, report);
    if (!state.bootstrapped) {
      await _capture(state, report);
      state.bootstrapped = true;
      await store.save(state);
    }
    await _push(state, codec, report);
    return report;
  }

  Future<void> _capture(SyncState state, SyncReport report) async {
    final n = state.captureLocal(await bridge.read(), _now());
    report.localChanges += n;
    if (n > 0) await store.save(state);
  }

  Future<void> _writeRows(
    SyncState state,
    Set<RowKey> keys,
    SyncReport report,
  ) async {
    if (keys.isEmpty) return;
    final writes = [
      for (final k in keys)
        RowWrite(k.table, k.id, state.materialize(k.table, k.id)),
    ];
    final failed = await bridge.write(writes);
    report.rowsWritten += writes.length - failed.length;
    state.unapplied
      ..removeAll(keys)
      ..addAll(failed);
  }

  Future<void> _pull(
    SyncState state,
    SegmentCodec codec,
    SyncReport report,
  ) async {
    final byDevice = <String, List<int>>{};
    for (final name in await transport.list(SegmentName.prefixOf(namespace))) {
      final p = SegmentName.parse(name, ns: namespace);
      if (p == null || p.$1 == state.deviceId) continue;
      byDevice.putIfAbsent(p.$1, () => []).add(p.$2);
    }
    final dirty = <RowKey>{};
    var unflushed = 0;

    Future<void> flush() async {
      await _writeRows(state, dirty.toSet(), report);
      dirty.clear();
      unflushed = 0;
      await store.save(state);
    }

    try {
      for (final dev in (byDevice.keys.toList()..sort())) {
        final seqs = byDevice[dev]!..sort();
        var expected = (state.cursors[dev] ?? 0) + 1;
        for (final seq in seqs) {
          if (seq < expected) continue;
          if (seq != expected) break; // a gap: wait for the missing one
          final name = SegmentName.of(dev, seq, ns: namespace);
          final blob = await transport.read(name);
          if (blob == null) break;
          final Segment seg;
          try {
            seg = await codec.decode(name, blob);
          } on BackupIntegrityError {
            throw SyncException(
              'integrity',
              'A stored change failed its check.',
            );
          } on FormatException {
            throw SyncException('integrity', 'A stored change is malformed.');
          }
          if (seg.schemaVersion > bridge.schemaVersion) {
            throw const SyncException(
              'too_new',
              'Another device runs a newer version of Pulse.',
            );
          }
          for (final c in seg.changes) {
            state.clock.observe(c.hlc, _now());
            if (state.apply(c)) {
              dirty.add(c.key);
              report.appliedChanges++;
            }
          }
          state.cursors[dev] = seq;
          expected++;
          report.pulledSegments++;
          if (++unflushed >= flushEvery) await flush();
        }
      }
    } finally {
      if (unflushed > 0 || dirty.isNotEmpty) await flush();
    }
  }

  Future<void> _push(
    SyncState state,
    SegmentCodec codec,
    SyncReport report,
  ) async {
    while (true) {
      final fresh = state.inflight == null;
      final seg = state.nextSegment(maxPerSegment);
      if (seg == null) return;
      if (fresh) await store.save(state); // numbered before it leaves
      final bytes = await codec.encode(
        Segment(
          device: state.deviceId,
          seq: seg.seq,
          schemaVersion: bridge.schemaVersion,
          changes: seg.changes,
        ),
      );
      await transport.write(
        SegmentName.of(state.deviceId, seg.seq, ns: namespace),
        bytes,
      );
      state.segmentPushed();
      report.pushedSegments++;
      report.pushedChanges += seg.changes.length;
      await store.save(state);
    }
  }
}
