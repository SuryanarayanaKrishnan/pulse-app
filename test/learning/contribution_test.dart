import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/learning/contribution.dart';
import 'package:pulse/core/learning/contribution_transport.dart';
import 'package:pulse/core/learning/global_merchant_map.dart';
import 'package:pulse/core/learning/learning_controller.dart';
import 'package:pulse/core/learning/privacy_filter.dart';

final _map = GlobalMerchantMap(
  version: 7,
  entries: const {
    'carrefour': 'groceries',
    'spinneys': 'groceries',
    'starbucks': 'dining',
    'careem': 'transport',
  },
);

class _Env {
  _Env({bool configured = true, double drop = 0, int seed = 1})
    : kv = MemoryKvStore(),
      transport = MemoryContributionTransport() {
    now = DateTime.utc(2026, 1, 1);
    c = LearningController(
      kv,
      map: _map,
      transport: configured ? transport : const DisabledContributionTransport(),
      clock: () => now,
      random: Random(seed),
    );
    if (drop != 0.25) {
      // Replace the batcher's noise for deterministic tests.
      c = LearningController(
        kv,
        map: _map,
        transport: configured ? transport : const DisabledContributionTransport(),
        clock: () => now,
        random: _FixedRandom(0.99),
      );
    }
  }
  final MemoryKvStore kv;
  final MemoryContributionTransport transport;
  late LearningController c;
  late DateTime now;

  Future<void> confirm(String id, String merchant, String cat) =>
      c.recordConfirmation(paymentId: id, merchant: merchant, categoryId: cat);
}

/// A Random whose nextDouble is fixed (0 never drops; 0.99 almost always).
class _FixedRandom implements Random {
  _FixedRandom(this.v);
  final double v;
  @override
  double nextDouble() => v;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

void main() {
  group('opt-in is off by default and records nothing', () {
    test('off: confirmations are ignored and nothing is stored', () async {
      final e = _Env();
      await e.c.load();
      expect(e.c.optIn, isFalse);
      expect(await e.c.recordConfirmation(paymentId: 'a', merchant: 'Carrefour', categoryId: 'groceries'), isFalse);
      expect(e.c.queue.isEmpty, isTrue);
      expect(e.kv.data, isEmpty);
      expect(e.c.preview().items, isEmpty);
    });

    test('is independent of the analytics consent key', () async {
      final e = _Env();
      await e.c.setOptIn(true);
      expect(e.kv.data.keys.where((k) => k.startsWith('analytics.')), isEmpty);
    });
  });

  group('recording', () {
    test('keeps only (key, category) pairs from confirmed, filtered merchants', () async {
      final e = _Env();
      await e.c.setOptIn(true);
      await e.confirm('1', 'CARREFOUR MOE DUBAI', 'groceries');
      expect(e.c.queue.all(), [const PairCount('carrefour', 'groceries', 1)]);
    });

    test('private strings and people-like categories are never stored', () async {
      final e = _Env();
      await e.c.setOptIn(true);
      await e.confirm('1', 'Mohammed Ali', 'dining');
      await e.confirm('2', '0501234567', 'dining');
      await e.confirm('3', 'john@mail.com', 'shopping');
      await e.confirm('4', 'Transfer to Sara 12345', 'family');
      await e.confirm('5', 'Carrefour', 'salary');
      await e.confirm('6', 'Carrefour', 'custom');
      await e.confirm('7', 'Carrefour', 'rent');
      expect(e.c.queue.isEmpty, isTrue);
      expect(e.kv.data[ContributionQueue.storageKey], isNull);
    });

    test('the same payment counts once, and moves when recategorised again', () async {
      final e = _Env();
      await e.c.setOptIn(true);
      await e.confirm('1', 'Carrefour', 'groceries');
      await e.confirm('1', 'Carrefour', 'groceries');
      expect(e.c.queue.all().single.count, 1);
      await e.confirm('1', 'Carrefour', 'shopping');
      expect(e.c.queue.all(), [const PairCount('carrefour', 'shopping', 1)]);
    });

    test('survives a restart', () async {
      final e = _Env();
      await e.c.setOptIn(true);
      await e.confirm('1', 'Spinneys', 'groceries');
      final again = LearningController(e.kv, map: _map);
      await again.load();
      expect(again.optIn, isTrue);
      expect(again.queue.all(), [const PairCount('spinneys', 'groceries', 1)]);
    });

    test('the stored queue holds no amounts, dates or accounts, only keys and payment ids', () async {
      final e = _Env();
      await e.c.setOptIn(true);
      await e.confirm('tx-1', 'Spinneys', 'groceries');
      final stored = jsonDecode(e.kv.data[ContributionQueue.storageKey]!) as Map;
      expect(stored.keys, ['spinneys']);
    });

    test('is bounded', () async {
      final e = _Env();
      await e.c.setOptIn(true);
      for (var i = 0; i < 400; i++) {
        await e.c.queue.confirm('p$i', 'shop number ${i % 10} store${String.fromCharCode(97 + i % 26)}${String.fromCharCode(97 + (i ~/ 26) % 26)}', 'dining');
      }
      expect(e.c.queue.all().length, lessThanOrEqualTo(ContributionQueue.maxKeys));
    });
  });

  group('batcher: threshold, noise, caps', () {
    final filter = MerchantKeyFilter(_map);

    test('only pairs confirmed at least twice, counts capped', () {
      final b = ContributionBatcher(filter: filter, dropProbability: 0, random: Random(1));
      final batch = b.build(const [
        PairCount('carrefour', 'groceries', 1),
        PairCount('spinneys', 'groceries', 2),
        PairCount('starbucks', 'dining', 50),
      ], mapVersion: 7);
      expect({for (final p in batch.pairs) p.key: p.count}, {'spinneys': 2, 'starbucks': 3});
    });

    test('re-checks the filter at send time', () {
      final b = ContributionBatcher(filter: filter, dropProbability: 0);
      final batch = b.build(const [
        PairCount('mohammed ali', 'dining', 5),
        PairCount('cafe 12345', 'dining', 5),
        PairCount('carrefour', 'salary', 5),
        PairCount('carrefour', 'groceries', 5),
      ], mapVersion: 1);
      expect(batch.pairs.map((p) => p.key), ['carrefour']);
      expect(batch.pairs.single.category, 'groceries');
    });

    test('randomised inclusion drops about the configured share', () {
      final b = ContributionBatcher(filter: filter, dropProbability: 0.25, random: Random(42));
      var kept = 0;
      const n = 4000;
      for (var i = 0; i < n; i++) {
        kept += b.build(const [PairCount('carrefour', 'groceries', 2)], mapVersion: 1).pairs.length;
      }
      expect(kept / n, closeTo(0.75, 0.04));
    });

    test('two installs with identical confirmations send different batches', () {
      final pairs = [for (final k in ['carrefour', 'spinneys', 'starbucks', 'careem']) PairCount(k, 'dining', 2)];
      final seen = <String>{};
      for (var s = 0; s < 30; s++) {
        final b = ContributionBatcher(filter: filter, random: Random(s));
        seen.add(b.build(pairs, mapVersion: 1).pairs.map((p) => p.key).join(','));
      }
      expect(seen.length, greaterThan(3));
    });

    test('the payload has exactly format, map_version and pairs of k, c, n', () {
      final batch = ContributionBatch(mapVersion: 7, pairs: const [PairCount('carrefour', 'groceries', 2)]);
      final json = batch.toJson();
      expect(json.keys.toSet(), {'format', 'map_version', 'pairs'});
      expect((json['pairs'] as List).single, {'k': 'carrefour', 'c': 'groceries', 'n': 2});
      expect(jsonEncode(json), isNot(contains('id')));
    });
  });

  group('weekly upload', () {
    Future<_Env> ready({bool configured = true}) async {
      final e = _Env(configured: configured, drop: 0);
      await e.c.setOptIn(true);
      await e.confirm('1', 'Carrefour', 'groceries');
      await e.confirm('2', 'Carrefour', 'groceries');
      await e.confirm('3', 'Spinneys', 'groceries'); // only once
      return e;
    }

    test('nothing is sent before a week has passed', () async {
      final e = await ready();
      e.now = e.now.add(const Duration(days: 6));
      await e.c.flushIfDue();
      expect(e.transport.received, isEmpty);
    });

    test('after a week, one batch with the eligible pair, then the queue forgets it', () async {
      final e = await ready();
      e.now = e.now.add(const Duration(days: 7));
      await e.c.flushIfDue();
      expect(e.transport.received.length, 1);
      final sent = e.transport.received.single;
      expect(sent['map_version'], 7);
      expect((sent['pairs'] as List).single, {'k': 'carrefour', 'c': 'groceries', 'n': 2});
      expect(e.c.queue.all(), [const PairCount('spinneys', 'groceries', 1)]);
      // Not again the same week.
      await e.c.flushIfDue();
      expect(e.transport.received.length, 1);
    });

    test('a failed upload keeps the queue and is retried', () async {
      final e = await ready();
      e.transport.accept = false;
      e.now = e.now.add(const Duration(days: 8));
      await e.c.flushIfDue();
      expect(e.transport.received, isEmpty);
      expect(e.c.queue.eligible().length, 1);
      e.transport.accept = true;
      await e.c.flushIfDue();
      expect(e.transport.received.length, 1);
    });

    test('with no endpoint configured nothing is sent and nothing is lost', () async {
      final e = await ready(configured: false);
      e.now = e.now.add(const Duration(days: 30));
      await e.c.flushIfDue();
      expect(e.transport.received, isEmpty);
      expect(e.c.queue.eligible().length, 1);
      expect(e.c.uploadsConfigured, isFalse);
    });

    test('opted out: never sends', () async {
      final e = await ready();
      await e.c.setOptIn(false);
      e.now = e.now.add(const Duration(days: 30));
      await e.c.flushIfDue();
      expect(e.transport.received, isEmpty);
    });
  });

  group('opt-out clears queued data', () {
    test('queue, clock and stored copy are gone, and a restart stays off', () async {
      final e = _Env();
      await e.c.setOptIn(true);
      await e.confirm('1', 'Carrefour', 'groceries');
      await e.confirm('2', 'Carrefour', 'groceries');
      expect(e.kv.data[ContributionQueue.storageKey], isNotNull);
      await e.c.setOptIn(false);
      expect(e.c.optIn, isFalse);
      expect(e.c.queue.isEmpty, isTrue);
      expect(e.kv.data.containsKey(ContributionQueue.storageKey), isFalse);
      expect(e.kv.data.containsKey(LearningController.lastBatchKey), isFalse);
      expect(e.c.preview().items, isEmpty);
      final again = LearningController(e.kv, map: _map);
      await again.load();
      expect(again.optIn, isFalse);
      expect(again.queue.isEmpty, isTrue);
    });

    test('leftover queue data without consent is wiped on load', () async {
      final kv = MemoryKvStore()
        ..data[ContributionQueue.storageKey] = jsonEncode({'carrefour': {'groceries': ['a', 'b']}});
      final c = LearningController(kv, map: _map);
      await c.load();
      expect(c.queue.isEmpty, isTrue);
      expect(kv.data.containsKey(ContributionQueue.storageKey), isFalse);
    });

    test('tampered stored queue entries that fail the filter are dropped on load', () async {
      final kv = MemoryKvStore()
        ..data[LearningController.optInKey] = 'on'
        ..data[ContributionQueue.storageKey] = jsonEncode({
          'mohammed ali': {'dining': ['a', 'b']},
          'carrefour': {'groceries': ['a', 'b'], 'salary': ['c', 'd']},
        });
      final c = LearningController(kv, map: _map);
      await c.load();
      expect(c.queue.all(), [const PairCount('carrefour', 'groceries', 2)]);
    });

    test('clearQueue keeps the opt-in', () async {
      final e = _Env();
      await e.c.setOptIn(true);
      await e.confirm('1', 'Carrefour', 'groceries');
      await e.c.clearQueue();
      expect(e.c.optIn, isTrue);
      expect(e.c.queue.isEmpty, isTrue);
    });
  });

  group('preview', () {
    test('shows eligible pairs, counts the rest, and matches what the batcher would send', () async {
      final e = _Env(drop: 0);
      await e.c.setOptIn(true);
      for (final id in ['1', '2', '3']) {
        await e.confirm(id, 'Carrefour', 'groceries');
      }
      await e.confirm('4', 'Spinneys', 'groceries');
      final p = e.c.preview();
      expect(p.items, [const PairCount('carrefour', 'groceries', 3)]);
      expect(p.waiting, 1);
      expect(p.dropPercent, 25);
      expect(p.nextSend, DateTime.utc(2026, 1, 8));
      final example = jsonDecode(p.exampleJson(7)) as Map;
      expect((example['pairs'] as List).single, {'k': 'carrefour', 'c': 'groceries', 'n': 3});
    });

    test('has no next send date while no endpoint is configured', () async {
      final e = _Env(configured: false);
      await e.c.setOptIn(true);
      expect(e.c.preview().nextSend, isNull);
    });
  });

  group('transport', () {
    test('disabled transport sends nothing and says so', () async {
      const t = DisabledContributionTransport();
      expect(t.enabled, isFalse);
      expect(await t.send(const ContributionBatch(mapVersion: 1, pairs: [])), isFalse);
    });

    test('memory transport records the exact JSON', () async {
      final t = MemoryContributionTransport();
      await t.send(const ContributionBatch(mapVersion: 3, pairs: [PairCount('a', 'dining', 2)]));
      expect(t.received.single, {
        'format': 1,
        'map_version': 3,
        'pairs': [
          {'k': 'a', 'c': 'dining', 'n': 2},
        ],
      });
    });
  });
}
