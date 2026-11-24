import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/sync/sync_scheduler.dart';

void main() {
  late DateTime now;
  late List<String> runs;
  late bool ok;

  SyncScheduler make() => SyncScheduler(
    run: (t) async {
      runs.add(t);
      return ok;
    },
    clock: () => now,
  );

  setUp(() {
    now = DateTime(2026, 1, 1, 12);
    runs = [];
    ok = true;
  });

  test('a burst of local writes becomes one sync after the quiet period', () {
    fakeAsync((async) {
      final s = make();
      for (var i = 0; i < 10; i++) {
        s.onLocalWrite();
        async.elapse(const Duration(seconds: 5));
      }
      expect(runs, isEmpty);
      async.elapse(const Duration(seconds: 20));
      expect(runs, ['auto']);
      s.dispose();
    });
  });

  test('resume syncs soon, but not again right after a sync', () {
    fakeAsync((async) {
      final s = make();
      s.onResume();
      async.elapse(const Duration(seconds: 3));
      expect(runs, ['resume']);
      now = now.add(const Duration(seconds: 10));
      s.onResume();
      async.elapse(const Duration(seconds: 3));
      expect(runs, ['resume']);
      now = now.add(const Duration(minutes: 5));
      s.onResume();
      async.elapse(const Duration(seconds: 3));
      expect(runs, ['resume', 'resume']);
      s.dispose();
    });
  });

  test('failures back off exponentially and a manual sync still goes', () {
    fakeAsync((async) {
      ok = false;
      final s = make();
      s.onLocalWrite();
      async.elapse(const Duration(seconds: 21));
      expect(runs.length, 1);
      expect(s.failures, 1);
      // Auto retry after 1 minute (virtual clock advanced by fakeAsync only
      // for timers, so move the injected clock too).
      now = now.add(const Duration(minutes: 1));
      async.elapse(const Duration(minutes: 1));
      expect(runs.length, 2);
      now = now.add(const Duration(minutes: 2));
      async.elapse(const Duration(minutes: 2));
      expect(runs.length, 3);
      expect(s.failures, 3);
      final manual = s.syncNow();
      async.flushMicrotasks();
      expect(runs.length, 4);
      expect(runs.last, 'manual');
      manual.then((v) => expect(v, isFalse));
      ok = true;
      s.syncNow();
      async.flushMicrotasks();
      expect(s.failures, 0);
      s.dispose();
    });
  });

  test('backoff is capped at retryMax', () {
    fakeAsync((async) {
      ok = false;
      final s = make()..failures = 40;
      s.onLocalWrite();
      async.elapse(const Duration(seconds: 21));
      expect(runs.length, 1);
      now = now.add(const Duration(minutes: 31));
      async.elapse(const Duration(minutes: 31));
      expect(runs.length, 2);
      s.dispose();
    });
  });

  test('only one run at a time; a trigger during a run schedules another', () {
    fakeAsync((async) {
      var inFlight = 0;
      var maxInFlight = 0;
      var count = 0;
      final s = SyncScheduler(
        run: (t) async {
          count++;
          inFlight++;
          maxInFlight = maxInFlight > inFlight ? maxInFlight : inFlight;
          await Future<void>.delayed(const Duration(seconds: 10));
          inFlight--;
          return true;
        },
        clock: () => now,
      );
      s.syncNow();
      s.syncNow();
      s.onLocalWrite();
      async.elapse(const Duration(seconds: 11));
      expect(count, 1);
      async.elapse(const Duration(seconds: 40));
      expect(maxInFlight, 1);
      expect(count, 2);
      s.dispose();
    });
  });

  test('disabled: automatic triggers do nothing, manual still works', () {
    fakeAsync((async) {
      final s = make()..enabled = false;
      s.onLocalWrite();
      s.onResume();
      async.elapse(const Duration(minutes: 1));
      expect(runs, isEmpty);
      s.syncNow();
      async.flushMicrotasks();
      expect(runs, ['manual']);
      s.dispose();
    });
  });
}
