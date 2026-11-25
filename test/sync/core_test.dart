import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/backup/backup_crypto.dart';
import 'package:pulse/core/sync/change.dart';
import 'package:pulse/core/sync/hlc.dart';
import 'package:pulse/core/sync/segment_codec.dart';
import 'package:pulse/core/sync/sync_state.dart';

import 'support.dart';

void main() {
  group('Hlc', () {
    test('string form sorts like the clock and round trips', () {
      final a = Hlc(5, 0, 'aaaaaaaaaaaaaaaa');
      final b = Hlc(5, 1, 'aaaaaaaaaaaaaaaa');
      final c = Hlc(6, 0, 'aaaaaaaaaaaaaaaa');
      final d = Hlc(6, 0, 'bbbbbbbbbbbbbbbb');
      final all = [a, b, c, d];
      expect([...all]..shuffle(Random(1)), isNot(equals(all)));
      final byString = ([...all]..shuffle(Random(2)))
        ..sort((x, y) => x.toString().compareTo(y.toString()));
      expect(byString, all);
      for (final h in all) {
        expect(Hlc.parse(h.toString()), h);
      }
    });

    test('rejects malformed input', () {
      expect(() => Hlc.parse('nope'), throwsFormatException);
      expect(() => Hlc.parse('0000000000005-0000-'), throwsFormatException);
    });

    test('tick is strictly increasing even when the wall clock stalls or goes back', () {
      final clock = HlcClock('d' * 16);
      final seen = <Hlc>[];
      for (final now in [100, 100, 100, 90, 50, 101, 101]) {
        seen.add(clock.tick(now));
      }
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i] > seen[i - 1], isTrue, reason: '$i');
      }
    });

    test('observe moves the clock past a remote stamp', () {
      final clock = HlcClock('a' * 16);
      clock.tick(100);
      clock.observe(Hlc(500, 7, 'b' * 16), 100);
      final next = clock.tick(100);
      expect(next > Hlc(500, 7, 'b' * 16), isTrue);
    });

    test('a remote clock far in the future is clamped', () {
      final clock = HlcClock('a' * 16);
      clock.observe(Hlc(100 + 365 * 86400000, 0, 'b' * 16), 100);
      final next = clock.tick(100);
      expect(
        next.wall,
        lessThanOrEqualTo(100 + const Duration(days: 1).inMilliseconds + 1),
      );
    });
  });

  group('SyncState merge', () {
    Change ch(String f, Object? v, int wall, [String dev = 'a']) =>
        Change('transactions', 'r1', f, v, Hlc(wall, 0, dev.padRight(16, '0')));

    test('last writer wins per field; fields are independent', () {
      final s = SyncState('x' * 16);
      expect(s.apply(ch('note', 'old', 1)), isTrue);
      expect(s.apply(ch('amount', 5, 1)), isTrue);
      expect(s.apply(ch('note', 'new', 3)), isTrue);
      expect(s.apply(ch('note', 'stale', 2)), isFalse);
      expect(s.materialize('transactions', 'r1'), {'note': 'new', 'amount': 5});
    });

    test('equal timestamps from the same device are a no-op (idempotent)', () {
      final s = SyncState('x' * 16);
      final c = ch('note', 'v', 1);
      expect(s.apply(c), isTrue);
      expect(s.apply(c), isFalse);
    });

    test('tombstone hides the row; a later re-create brings fields back', () {
      final s = SyncState('x' * 16);
      s.apply(ch('note', 'hello', 1));
      s.apply(ch(deletedField, true, 2));
      expect(s.materialize('transactions', 'r1'), isNull);
      s.apply(ch(deletedField, false, 3));
      expect(s.materialize('transactions', 'r1'), {'note': 'hello'});
    });

    test('an old re-create does not undo a newer delete', () {
      final s = SyncState('x' * 16);
      s.apply(ch('note', 'hello', 1));
      s.apply(ch(deletedField, true, 5));
      s.apply(ch(deletedField, false, 3));
      expect(s.materialize('transactions', 'r1'), isNull);
    });

    test('merge order never matters (commutative, associative, idempotent)', () {
      final rng = Random(42);
      final changes =
          [
                for (var i = 0; i < 200; i++)
                  Change(
                    'transactions',
                    'r${rng.nextInt(4)}',
                    ['a', 'b', 'c', deletedField][rng.nextInt(4)],
                    rng.nextInt(3),
                    Hlc(
                      rng.nextInt(30),
                      rng.nextInt(3),
                      'dev${rng.nextInt(3)}'.padRight(16, '0'),
                    ),
                  ),
              ]
              .map(
                (c) => c.field == deletedField
                    ? Change(c.table, c.row, c.field, c.value == 1, c.hlc)
                    : c,
              )
              .toList();
      String render(SyncState s) => [
        for (var r = 0; r < 4; r++)
          '$r:${(s.materialize('transactions', 'r$r')?.entries.toList() ?? [])..sort((a, b) => a.key.compareTo(b.key))}',
      ].join('|');
      final reference = SyncState('x' * 16);
      changes.forEach(reference.apply);
      for (var trial = 0; trial < 20; trial++) {
        final s = SyncState('y' * 16);
        final shuffled = [...changes, ...changes.take(50)]..shuffle(rng);
        shuffled.forEach(s.apply);
        expect(render(s), render(reference));
      }
    });

    test('state survives JSON, including bytes and the unsent outbox', () {
      final s = SyncState('x' * 16, wall: 9, counter: 2);
      s.apply(ch('blob', Uint8List.fromList([1, 2, 3]), 1));
      s.captureLocal({
        'transactions': {
          'r1': {
            'blob': Uint8List.fromList([1, 2, 3]),
          },
          'r9': {'note': 'n', 'amount': 3},
        },
      }, 100);
      s.nextSegment(1);
      final back = SyncState.decode(s.encode());
      expect(back.materialize('transactions', 'r1')!['blob'], [1, 2, 3]);
      expect(back.outbox.length, s.outbox.length);
      expect(back.inflight!.seq, 1);
      expect(back.inflight!.changes.length, 1);
      expect(back.clock.wall, s.clock.wall);
    });
  });

  group('captureLocal', () {
    test(
      'new rows, edits and deletes become writes; unchanged data does not',
      () {
        final s = SyncState('x' * 16);
        LocalSnapshot snap(Map<String, Map<String, Object?>> rows) => {
          'budgets': rows,
        };
        expect(
          s.captureLocal(
            snap({
              'b1': {'name': 'Food', 'cap': 100},
            }),
            10,
          ),
          2,
        );
        expect(
          s.captureLocal(
            snap({
              'b1': {'name': 'Food', 'cap': 100},
            }),
            20,
          ),
          0,
        );
        expect(
          s.captureLocal(
            snap({
              'b1': {'name': 'Food', 'cap': 120},
            }),
            30,
          ),
          1,
        );
        expect(s.captureLocal(snap({}), 40), 1); // tombstone
        expect(s.isDeleted('budgets', 'b1'), isTrue);
        expect(s.captureLocal(snap({}), 50), 0); // not re-emitted
        expect(
          s.captureLocal(
            snap({
              'b1': {'name': 'Food', 'cap': 120},
            }),
            60,
          ),
          1,
        ); // re-created
        expect(s.isDeleted('budgets', 'b1'), isFalse);
      },
    );

    test('1 and 1.0 are the same value', () {
      final s = SyncState('x' * 16);
      s.captureLocal({
        't': {
          'r': {'v': 1},
        },
      }, 1);
      expect(
        s.captureLocal({
          't': {
            'r': {'v': 1.0},
          },
        }, 2),
        0,
      );
    });

    test('rows that could not be written yet are not mistaken for deletes', () {
      final s = SyncState('x' * 16);
      s.apply(Change('t', 'r', 'v', 1, Hlc(1, 0, 'b' * 16)));
      s.unapplied.add(const RowKey('t', 'r'));
      expect(s.captureLocal({'t': {}}, 5), 0);
    });
  });

  group('outbox packaging', () {
    test('keeps only the newest write per field and respects the size cap', () {
      final s = SyncState('x' * 16);
      for (var i = 0; i < 4; i++) {
        s.captureLocal({
          't': {
            'r': {'v': i, 'w': i},
          },
        }, 10 + i);
      }
      final seg = s.nextSegment(10)!;
      expect(seg.changes.length, 2);
      expect(seg.changes.every((c) => c.value == 3), isTrue);
      expect(s.outbox, isEmpty);
      // The same pending segment is returned until it is acknowledged.
      expect(identical(s.nextSegment(10), seg), isTrue);
      s.segmentPushed();
      expect(s.pushedSeq, 1);
      expect(s.nextSegment(10), isNull);
    });
  });

  group('SegmentCodec', () {
    final seg = Segment(
      device: 'a' * 16,
      seq: 3,
      schemaVersion: 2,
      changes: [
        Change(
          'transactions',
          'r1',
          'merchant_raw',
          'Carrefour Dubai Mall',
          Hlc(5, 1, 'a' * 16),
        ),
        Change(
          'transactions',
          'r1',
          'blob',
          Uint8List.fromList([9, 8]),
          Hlc(6, 0, 'a' * 16),
        ),
        Change('transactions', 'r1', 'x', null, Hlc(7, 0, 'a' * 16)),
      ],
    );
    final name = SegmentName.of('a' * 16, 3);

    test('round trips and the ciphertext hides the content', () async {
      final codec = await SegmentCodec.forDataKey(testKey);
      final bytes = await codec.encode(seg);
      final text = String.fromCharCodes(bytes);
      expect(text.contains('Carrefour'), isFalse);
      expect(text.contains('transactions'), isFalse);
      final back = await codec.decode(name, bytes);
      expect(back.seq, 3);
      expect(back.schemaVersion, 2);
      expect(back.changes[0].value, 'Carrefour Dubai Mall');
      expect(back.changes[1].value, [9, 8]);
      expect(back.changes[2].value, isNull);
      expect(back.changes[0].hlc, Hlc(5, 1, 'a' * 16));
    });

    test(
      'a different key, a flipped bit, truncation or another name all fail',
      () async {
        final codec = await SegmentCodec.forDataKey(testKey);
        final bytes = await codec.encode(seg);
        final other = await SegmentCodec.forDataKey(Uint8List(32));
        expect(other.decode(name, bytes), throwsA(isA<BackupIntegrityError>()));
        final flipped = Uint8List.fromList(bytes)..[20] ^= 1;
        expect(
          codec.decode(name, flipped),
          throwsA(isA<BackupIntegrityError>()),
        );
        expect(
          codec.decode(name, bytes.sublist(0, bytes.length - 3)),
          throwsA(isA<BackupIntegrityError>()),
        );
        expect(
          codec.decode(SegmentName.of('a' * 16, 4), bytes),
          throwsA(isA<BackupIntegrityError>()),
        );
        expect(
          codec.decode(SegmentName.of('b' * 16, 3), bytes),
          throwsA(isA<BackupIntegrityError>()),
        );
      },
    );

    test('uses a sub-key, not the raw backup data key', () async {
      final codec = await SegmentCodec.forDataKey(testKey);
      final bytes = await codec.encode(seg);
      // Opening with the raw data key (as backup chunks would) must fail.
      final raw = await BackupCrypto.subKey(testKey, 'chunks');
      expect(
        BackupCrypto.open(raw, bytes, aad: name.codeUnits),
        throwsA(isA<BackupIntegrityError>()),
      );
    });

    test('names parse strictly', () {
      expect(SegmentName.parse(SegmentName.of('0123456789abcdef', 12)), (
        '0123456789abcdef',
        12,
      ));
      expect(SegmentName.parse('sync/../x/0000000001.seg'), isNull);
      expect(SegmentName.parse('sync/0123456789abcdef/1.seg'), isNull);
      expect(SegmentName.parse('manifests/x'), isNull);
    });
  });
}
