import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/sync/change.dart';
import 'package:pulse/core/sync/segment_codec.dart';
import 'package:pulse/core/sync/sync_engine.dart';
import 'package:pulse/core/sync/sync_transport.dart';

import 'support.dart';

const tx = 'transactions';

void main() {
  late MemorySyncTransport server;
  late Device a;
  late Device b;

  setUp(() {
    server = MemorySyncTransport();
    a = Device('aaaa', server);
    b = Device('bbbb', server, startMs: 1000500);
  });

  group('two devices', () {
    test('new rows flow both ways', () async {
      a.edit(tx, 't1', {'id': 't1', 'merchant': 'Carrefour', 'amount': 120});
      b.edit(tx, 't2', {'id': 't2', 'merchant': 'Noon', 'amount': 80});
      await settle([a, b]);
      expect(a.row(tx, 't2'), {'id': 't2', 'merchant': 'Noon', 'amount': 80});
      expect(b.row(tx, 't1'), {'id': 't1', 'merchant': 'Carrefour', 'amount': 120});
    });

    test('an edit propagates and an idle sync moves nothing', () async {
      a.edit(tx, 't1', {'id': 't1', 'note': 'one'});
      await settle([a, b]);
      a.edit(tx, 't1', {'note': 'two'});
      await settle([a, b]);
      expect(b.row(tx, 't1')!['note'], 'two');
      final r = await a.sync();
      expect(r.idle, isTrue);
      expect(r.pushedSegments, 0);
      expect((await b.sync()).idle, isTrue);
    });

    test('concurrent edits to different fields both survive', () async {
      a.edit(tx, 't1', {'id': 't1', 'note': 'n', 'category': 'food'});
      await settle([a, b]);
      a.edit(tx, 't1', {'note': 'edited on A'});
      b.edit(tx, 't1', {'category': 'groceries'});
      await settle([a, b]);
      for (final d in [a, b]) {
        expect(d.row(tx, 't1'), {'id': 't1', 'note': 'edited on A', 'category': 'groceries'});
      }
    });

    test('concurrent edits to the same field: the later write wins on both', () async {
      a.edit(tx, 't1', {'id': 't1', 'note': 'start'});
      await settle([a, b]);
      a.edit(tx, 't1', {'note': 'A early'}, 1000);
      b.edit(tx, 't1', {'note': 'B later'}, 5000);
      await settle([a, b]);
      expect(a.row(tx, 't1')!['note'], 'B later');
      expect(b.row(tx, 't1')!['note'], 'B later');
    });

    test('the winner does not depend on who syncs first', () async {
      a.edit(tx, 't1', {'id': 't1', 'note': 'start'});
      await settle([a, b]);
      a.edit(tx, 't1', {'note': 'A later'}, 9000);
      b.edit(tx, 't1', {'note': 'B early'}, 1000);
      await settle([b, a]);
      expect(a.row(tx, 't1')!['note'], 'A later');
      expect(b.row(tx, 't1')!['note'], 'A later');
    });

    test('delete propagates as a tombstone', () async {
      a.edit(tx, 't1', {'id': 't1', 'note': 'x'});
      await settle([a, b]);
      b.delete(tx, 't1');
      await settle([a, b]);
      expect(a.row(tx, 't1'), isNull);
      expect(b.row(tx, 't1'), isNull);
    });

    test('delete beats a concurrent edit of the same row', () async {
      a.edit(tx, 't1', {'id': 't1', 'note': 'x'});
      await settle([a, b]);
      a.edit(tx, 't1', {'note': 'edit'}, 5000);
      b.delete(tx, 't1', 1000);
      await settle([a, b]);
      expect(a.row(tx, 't1'), isNull);
      expect(b.row(tx, 't1'), isNull);
    });

    test('a row deleted then re-created later comes back everywhere', () async {
      a.edit(tx, 't1', {'id': 't1', 'note': 'x'});
      await settle([a, b]);
      b.delete(tx, 't1');
      await settle([a, b]);
      a.edit(tx, 't1', {'id': 't1', 'note': 'back'});
      await settle([a, b]);
      expect(b.row(tx, 't1'), {'id': 't1', 'note': 'back'});
      expect(a.row(tx, 't1'), {'id': 't1', 'note': 'back'});
    });

    test('same row inserted on both devices converges (later write wins)', () async {
      await settle([a, b]); // both have joined the log
      a.edit('categories', 'food', {'id': 'food', 'name': 'Food'}, 100);
      b.edit('categories', 'food', {'id': 'food', 'name': 'Dining'}, 900);
      await settle([a, b]);
      expect(a.row('categories', 'food'), b.row('categories', 'food'));
      expect(a.row('categories', 'food')!['name'], 'Dining');
    });

    test('a device with a clock far behind still converges (HLC)', () async {
      final slow = Device('cccc', server, startMs: 10);
      a.edit(tx, 't1', {'id': 't1', 'note': 'start'});
      await settle([a, slow]);
      slow.edit(tx, 't1', {'note': 'slow edit, after seeing start'}, 1);
      await settle([a, slow]);
      expect(a.row(tx, 't1')!['note'], 'slow edit, after seeing start');
    });
  });

  group('three devices', () {
    test('everything converges regardless of the sync order', () async {
      final c = Device('cccc', server, startMs: 1001000);
      a.edit(tx, 'a1', {'id': 'a1', 'v': 1});
      b.edit(tx, 'b1', {'id': 'b1', 'v': 2});
      c.edit(tx, 'c1', {'id': 'c1', 'v': 3});
      await c.sync();
      await a.sync();
      await b.sync();
      await settle([c, b, a]);
      for (final d in [a, b, c]) {
        expect({for (final id in ['a1', 'b1', 'c1']) id: d.row(tx, id)!['v']}, {'a1': 1, 'b1': 2, 'c1': 3});
      }
    });
  });

  group('resumable and idempotent', () {
    test('a large batch is split into segments', () async {
      for (var i = 0; i < 12; i++) {
        a.edit(tx, 't$i', {'id': 't$i', 'v': i});
      }
      final r = await a.sync();
      expect(r.pushedChanges, 24);
      expect(r.pushedSegments, 5); // 5 per segment in the test config
      await b.sync();
      expect(b.bridge.tables[tx]!.length, 12);
    });

    test('a failed upload keeps the work and the retry resends the same segment', () async {
      a.edit(tx, 't1', {'id': 't1', 'note': 'x'});
      server.failWrites = Exception('offline');
      await expectLater(a.sync(), throwsException);
      expect(server.objects, isEmpty);
      a.edit(tx, 't1', {'note': 'edited while offline'});
      server.failWrites = null;
      await a.sync();
      await b.sync();
      expect(b.row(tx, 't1')!['note'], 'edited while offline');
    });

    test('an upload that landed but whose reply was lost is not duplicated or lost', () async {
      a.edit(tx, 't1', {'id': 't1', 'note': 'x'});
      server.failWrites = Exception('timeout');
      server.storeThenFail = true;
      await expectLater(a.sync(), throwsException);
      expect(server.objects.length, 1);
      await b.sync(); // b already read segment 1
      server.failWrites = null;
      server.storeThenFail = false;
      a.restart();
      a.edit(tx, 't1', {'note': 'after'});
      await a.sync();
      expect(server.objects.keys.where((k) => k.startsWith('sync/${a.engine.deviceId}/')).length, 2);
      await b.sync();
      expect(b.row(tx, 't1'), {'id': 't1', 'note': 'after'});
    });

    test('restarting the app between runs loses nothing', () async {
      a.edit(tx, 't1', {'id': 't1', 'note': 'x'});
      await a.sync();
      a.restart();
      a.edit(tx, 't2', {'id': 't2', 'note': 'y'});
      await a.sync();
      b.restart();
      await b.sync();
      b.restart();
      expect((await b.sync()).idle, isTrue);
      expect(b.bridge.tables[tx]!.keys, {'t1', 't2'});
      expect(a.engine.deviceId, isNot(b.engine.deviceId));
    });

    test('a failure while reading leaves cursors where the work got to', () async {
      for (var i = 0; i < 6; i++) {
        a.edit(tx, 't$i', {'id': 't$i', 'v': i});
      }
      await a.sync();
      expect(server.objects.length, 3);
      server.failReads = Exception('network dropped');
      await expectLater(b.sync(), throwsException);
      server.failReads = null;
      await b.sync();
      expect(b.bridge.tables[tx]!.length, 6);
      expect((await b.sync()).pulledSegments, 0);
    });

    test('pulling the same segments twice (state lost mid-run) changes nothing', () async {
      a.edit(tx, 't1', {'id': 't1', 'note': 'x'});
      await a.sync();
      await b.sync();
      b.edit(tx, 't1', {'note': 'b edit'});
      await b.sync();
      // b forgets its cursors: everything is read again.
      final json = b.store.json!;
      b.store.json = json.replaceFirst(RegExp(r'"cursors":\{[^}]*\}'), '"cursors":{}');
      b.restart();
      await b.sync();
      expect(b.row(tx, 't1')!['note'], 'b edit');
    });

    test('a missing segment in the middle stops the pull until it appears', () async {
      for (var i = 0; i < 12; i++) {
        a.edit(tx, 't$i', {'id': 't$i', 'v': i});
      }
      await a.sync();
      final id = a.engine.deviceId!;
      final hidden = server.objects.remove(SegmentName.of(id, 2))!;
      await b.sync();
      expect(b.bridge.tables[tx]!.length, 3); // only segment 1 (5 changes) applied
      server.objects[SegmentName.of(id, 2)] = hidden;
      await b.sync();
      expect(b.bridge.tables[tx]!.length, 12);
    });
  });

  group('safety', () {
    test('the server holds ciphertext only', () async {
      a.edit(tx, 't1', {'id': 't1', 'merchant_raw': 'SECRETSHOP LLC', 'amount_minor': 987654});
      await a.sync();
      expect(server.objects, isNotEmpty);
      for (final e in server.objects.entries) {
        final text = String.fromCharCodes(e.value);
        expect(text.contains('SECRETSHOP'), isFalse);
        expect(text.contains('987654'), isFalse);
        expect(e.key.contains('SECRET'), isFalse);
        expect(e.key, matches(RegExp(r'^sync/[0-9a-f]{16}/\d{10}\.seg$')));
      }
    });

    test('a tampered segment is refused and nothing from it is applied', () async {
      a.edit(tx, 't1', {'id': 't1', 'note': 'x'});
      await a.sync();
      final name = server.objects.keys.single;
      final bad = Uint8List.fromList(server.objects[name]!)..[30] ^= 0xff;
      server.objects[name] = bad;
      await expectLater(
        b.sync(),
        throwsA(isA<SyncException>().having((e) => e.reason, 'reason', 'integrity')),
      );
      expect(b.bridge.tables[tx], anyOf(isNull, isEmpty));
    });

    test('a segment swapped under another name is refused', () async {
      a.edit(tx, 't1', {'id': 't1', 'note': 'x'});
      a.edit(tx, 't2', {'id': 't2', 'note': 'y'});
      a.edit(tx, 't9', {'id': 't9', 'note': 'z'});
      await a.sync();
      final id = a.engine.deviceId!;
      final one = server.objects[SegmentName.of(id, 1)]!;
      server.objects[SegmentName.of(id, 2)] = one; // replay of an old one
      a.edit(tx, 't3', {'id': 't3'});
      await a.sync();
      await expectLater(
        b.sync(),
        throwsA(isA<SyncException>().having((e) => e.reason, 'reason', 'integrity')),
      );
    });

    test('another account\'s key cannot read the log', () async {
      a.edit(tx, 't1', {'id': 't1', 'note': 'x'});
      await a.sync();
      final other = Device('dddd', server, key: Uint8List(32));
      await expectLater(
        other.sync(),
        throwsA(isA<SyncException>().having((e) => e.reason, 'reason', 'integrity')),
      );
    });

    test('segments from a newer schema are not applied', () async {
      final newer = Device('eeee', server, schema: 5);
      newer.edit(tx, 't1', {'id': 't1', 'future': 'x'});
      await newer.sync();
      await expectLater(
        b.sync(),
        throwsA(isA<SyncException>().having((e) => e.reason, 'reason', 'too_new')),
      );
      expect(b.row(tx, 't1'), isNull);
    });

    test('a signed-out transport is reported as such', () async {
      final t = _SignedOut();
      final d = Device('ffff', MemorySyncTransport());
      final e = SyncEngine(bridge: d.bridge, transport: t, store: d.store, dataKey: testKey);
      await expectLater(
        e.sync(),
        throwsA(isA<SyncException>().having((x) => x.reason, 'reason', 'signed_out')),
      );
    });

    test('concurrent calls share one run', () async {
      a.edit(tx, 't1', {'id': 't1'});
      final f1 = a.engine.sync();
      final f2 = a.engine.sync();
      expect(identical(f1, f2), isTrue);
      await f1;
      expect(server.objects.length, 1);
    });

    test('rows the database refuses are retried, never turned into deletes', () async {
      a.edit(tx, 't1', {'id': 't1', 'note': 'x'});
      await a.sync();
      b.bridge.rejecting.add(const RowKey(tx, 't1'));
      await b.sync();
      expect(b.row(tx, 't1'), isNull);
      await b.sync(); // would emit a tombstone if unapplied were ignored
      b.bridge.rejecting.clear();
      await settle([b, a]);
      expect(b.row(tx, 't1'), {'id': 't1', 'note': 'x'});
      expect(a.row(tx, 't1'), {'id': 't1', 'note': 'x'});
    });
  });

  group('joining a device that already has data', () {
    test('a restored phone with an older copy does not overwrite newer edits', () async {
      a.edit(tx, 't1', {'id': 't1', 'note': 'v1', 'amount': 10});
      a.edit(tx, 't2', {'id': 't2', 'note': 'to be deleted'});
      await a.sync();
      // b is "restored from a backup" taken at this point...
      b.bridge.put(tx, 't1', {'id': 't1', 'note': 'v1', 'amount': 10});
      b.bridge.put(tx, 't2', {'id': 't2', 'note': 'to be deleted'});
      // ...then a keeps going.
      a.edit(tx, 't1', {'note': 'v2'});
      a.delete(tx, 't2');
      a.edit(tx, 't3', {'id': 't3', 'note': 'new'});
      await a.sync();
      await b.sync(); // b's first sync
      await settle([a, b]);
      expect(b.row(tx, 't1')!['note'], 'v2');
      expect(b.row(tx, 't2'), isNull);
      expect(b.row(tx, 't3')!['note'], 'new');
      expect(a.row(tx, 't1')!['note'], 'v2');
      expect(a.row(tx, 't2'), isNull);
    });

    test('on its very first sync the log wins over a stale local copy of the same field', () async {
      a.edit('categories', 'food', {'id': 'food', 'name': 'Food'}, 100);
      b.edit('categories', 'food', {'id': 'food', 'name': 'Dining'}, 900);
      await settle([a, b]);
      expect(a.row('categories', 'food'), b.row('categories', 'food'));
    });

    test('rows only the new device has are added to the others', () async {
      b.bridge.put(tx, 'only-b', {'id': 'only-b', 'note': 'mine'});
      a.edit(tx, 't1', {'id': 't1'});
      await settle([a, b]);
      expect(a.row(tx, 'only-b'), {'id': 'only-b', 'note': 'mine'});
    });

    test('a device that lost its state starts over safely under a new id', () async {
      a.edit(tx, 't1', {'id': 't1', 'note': 'x'});
      await settle([a, b]);
      final a2 = Device('a2a2', server, startMs: 2000000);
      a2.bridge.tables.addAll(await a.bridge.read()); // same data, no state
      await settle([a2, a, b]);
      for (final d in [a, b, a2]) {
        expect(d.row(tx, 't1'), {'id': 't1', 'note': 'x'});
      }
      expect((await a2.sync()).pushedChanges, 0);
    });
  });
}

class _SignedOut extends MemorySyncTransport {
  @override
  Future<void> ensureReady() async => throw const SyncUnavailable('Sign in');
}
