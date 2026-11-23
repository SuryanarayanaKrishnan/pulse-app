import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/ingest_queue.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/data/api/ingest_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

PendingIngest item(
  String id, {
  DateTime? at,
  IngestChannel ch = IngestChannel.sms,
}) => PendingIngest(
  id: id,
  channel: ch,
  payload: {'raw_text': 'AED 10 at $id', 'external_id': id},
  createdAt: at ?? DateTime.utc(2026, 11, 20),
);

class Harness {
  Harness({KvStore? store, DateTime? now, this.maxAttempts = 10})
    : store = store ?? MemoryKvStore(),
      now = now ?? DateTime.utc(2026, 11, 20, 12) {
    queue = make(this.store);
  }
  final KvStore store;
  DateTime now;
  final int maxAttempts;
  final sentIds = <String>[];
  final script = <String, SendOutcome>{};
  SendOutcome defaultOutcome = SendOutcome.sent;
  late IngestQueue queue;

  IngestQueue make(KvStore s) => IngestQueue(
    store: s,
    clock: () => now,
    maxAttempts: maxAttempts,
    sender: (i) async {
      final o = script[i.id] ?? defaultOutcome;
      if (o == SendOutcome.sent) sentIds.add(i.id);
      return o;
    },
  );
}

void main() {
  test('enqueue dedupes by id and persists', () async {
    final h = Harness();
    expect(await h.queue.enqueue(item('a')), isTrue);
    expect(await h.queue.enqueue(item('a')), isFalse);
    expect(await h.queue.enqueue(item('b')), isTrue);
    expect(h.queue.pendingCount.value, 2);
    // A fresh queue over the same store sees the persisted items (restart).
    final reborn = h.make(h.store);
    expect((await reborn.items()).map((i) => i.id), ['a', 'b']);
  });

  test('flush uploads in order and empties the queue', () async {
    final h = Harness();
    for (final id in ['a', 'b', 'c']) {
      await h.queue.enqueue(item(id));
    }
    final r = await h.queue.flush();
    expect(h.sentIds, ['a', 'b', 'c']);
    expect(r.sent, 3);
    expect(r.remaining, 0);
    expect(h.queue.pendingCount.value, 0);
    expect(await h.store.read('ingest_queue.v1'), '[]');
  });

  test(
    'transient failure keeps the item, backs off and stops the run',
    () async {
      final h = Harness();
      h.script['a'] = SendOutcome.retry;
      await h.queue.enqueue(item('a'));
      await h.queue.enqueue(item('b'));
      var r = await h.queue.flush();
      expect(
        r.sent,
        0,
        reason: 'stops at first transient failure (likely offline)',
      );
      expect(r.remaining, 2);
      final a = (await h.queue.items()).first;
      expect(a.attempts, 1);
      expect(a.nextAttemptAt, h.now.add(const Duration(seconds: 30)));

      // Still backing off: a is skipped, b goes through.
      h.script.remove('a');
      r = await h.queue.flush();
      expect(h.sentIds, ['b']);
      expect(r.remaining, 1);

      // After the backoff window a is retried and delivered.
      h.now = h.now.add(const Duration(minutes: 1));
      r = await h.queue.flush();
      expect(h.sentIds, ['b', 'a']);
      expect(r.remaining, 0);
    },
  );

  test('force ignores backoff', () async {
    final h = Harness();
    h.script['a'] = SendOutcome.retry;
    await h.queue.enqueue(item('a'));
    await h.queue.flush();
    h.script.clear();
    expect((await h.queue.flush()).remaining, 1);
    expect((await h.queue.flush(force: true)).remaining, 0);
  });

  test('permanent failures are dropped and do not block the rest', () async {
    final h = Harness();
    h.script['bad'] = SendOutcome.permanent;
    await h.queue.enqueue(item('bad'));
    await h.queue.enqueue(item('ok'));
    final r = await h.queue.flush();
    expect(r.dropped, 1);
    expect(r.sent, 1);
    expect(r.remaining, 0);
  });

  test('401 keeps everything without burning attempts', () async {
    final h = Harness()..defaultOutcome = SendOutcome.unauthorized;
    await h.queue.enqueue(item('a'));
    await h.queue.enqueue(item('b'));
    final r = await h.queue.flush();
    expect(r.unauthorized, isTrue);
    expect(r.remaining, 2);
    expect((await h.queue.items()).every((i) => i.attempts == 0), isTrue);
  });

  test('gives up after maxAttempts and drops items past maxAge', () async {
    final h = Harness(maxAttempts: 3)..defaultOutcome = SendOutcome.retry;
    await h.queue.enqueue(item('a', at: h.now));
    var dropped = 0;
    for (var i = 0; i < 5; i++) {
      dropped += (await h.queue.flush(force: true)).dropped;
    }
    expect(dropped, 1);
    expect(h.queue.pendingCount.value, 0);

    await h.queue.enqueue(
      item('old', at: h.now.subtract(const Duration(days: 15))),
    );
    final r = await h.queue.flush();
    expect(r.dropped, 1);
    expect(h.sentIds, isEmpty);
  });

  test('caps queue size by dropping the oldest', () async {
    final q = IngestQueue(
      store: MemoryKvStore(),
      sender: (_) async => SendOutcome.retry,
      maxItems: 2,
    );
    for (final id in ['a', 'b', 'c']) {
      await q.enqueue(item(id));
    }
    expect((await q.items()).map((i) => i.id), ['b', 'c']);
  });

  test('concurrent flushes share one run', () async {
    final h = Harness();
    await h.queue.enqueue(item('a'));
    final results = await Future.wait([h.queue.flush(), h.queue.flush()]);
    expect(h.sentIds, ['a']);
    expect(identical(results[0], results[1]), isTrue);
  });

  test('corrupt storage is ignored', () async {
    final store = MemoryKvStore()..data['ingest_queue.v1'] = '{not json';
    final h = Harness(store: store);
    expect(await h.queue.items(), isEmpty);
    expect(await h.queue.enqueue(item('a')), isTrue);
  });

  test('backoff grows and is capped at an hour', () {
    expect(IngestQueue.backoffFor(1), const Duration(seconds: 30));
    expect(IngestQueue.backoffFor(2), const Duration(minutes: 1));
    expect(IngestQueue.backoffFor(3), const Duration(minutes: 2));
    expect(IngestQueue.backoffFor(20), const Duration(hours: 1));
  });

  test('SharedPrefsKvStore round-trips the queue', () async {
    SharedPreferences.setMockInitialValues({});
    final h = Harness(store: SharedPrefsKvStore());
    await h.queue.enqueue(item('x', ch: IngestChannel.notification));
    final reborn = h.make(SharedPrefsKvStore());
    final items = await reborn.items();
    expect(items.single.id, 'x');
    expect(items.single.channel, IngestChannel.notification);
    expect(items.single.payload['raw_text'], 'AED 10 at x');
  });
}
