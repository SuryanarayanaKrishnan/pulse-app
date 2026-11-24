import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/features/tour/tour_flow.dart';
import 'package:pulse/features/tour/tour_progress.dart';

class RecordingAnalytics extends NoopAnalytics {
  final events = <String>[];
  @override
  void track(AnalyticsEvent e) => events.add(
    e.properties.isEmpty ? e.name : '${e.name}:${e.properties['step']}',
  );
}

class ThrowingKv implements KvStore {
  @override
  Future<String?> read(String key) async => throw StateError('no storage');
  @override
  Future<void> write(String key, String value) async =>
      throw StateError('no storage');
  @override
  Future<void> remove(String key) async => throw StateError('no storage');
}

ProviderContainer _container(KvStore kv) {
  final c = ProviderContainer(
    overrides: [tourKvProvider.overrideWithValue(kv)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('TourFlow', () {
    test('advances through four moments then completes', () {
      final a = RecordingAnalytics();
      final f = TourFlow(a)..start();
      expect(f.step, TourStep.safeToSpend);
      expect(f.advance(), isFalse);
      expect(f.advance(), isFalse);
      expect(f.advance(), isFalse);
      expect(f.isLast, isTrue);
      expect(f.advance(), isTrue);
      expect(f.status, TourStatus.completed);
      expect(a.events, [
        'tour_started',
        'tour_step_viewed:safe_to_spend',
        'tour_step_viewed:right_card',
        'tour_step_viewed:auto_capture',
        'tour_step_viewed:net_worth',
        'tour_completed',
      ]);
    });

    test('skip reports the moment it was left on, once', () {
      final a = RecordingAnalytics();
      final f = TourFlow(a)..start();
      f.advance();
      f.skip();
      f.skip();
      f.complete();
      expect(f.status, TourStatus.skipped);
      expect(a.events.where((e) => e.startsWith('tour_skipped')), [
        'tour_skipped:right_card',
      ]);
      expect(a.events.contains('tour_completed'), isFalse);
    });

    test('swiping back and forth reports each moment once', () {
      final a = RecordingAnalytics();
      final f = TourFlow(a)..start();
      f.goTo(1);
      f.goTo(0);
      f.goTo(1);
      f.goTo(9);
      expect(a.events.where((e) => e.startsWith('tour_step_viewed')).length, 2);
    });

    test('start is idempotent and a finished tour ignores input', () {
      final a = RecordingAnalytics();
      final f = TourFlow(a)
        ..start()
        ..start()
        ..skip();
      f.goTo(2);
      expect(f.index, 0);
      expect(a.events.where((e) => e == 'tour_started').length, 1);
    });
  });

  group('TourProgress persistence', () {
    test(
      'first launch shows the tour; marking it seen survives a restart',
      () async {
        final kv = MemoryKvStore();
        var c = _container(kv);
        await c.read(tourProgressProvider.notifier).ready;
        expect(c.read(tourProgressProvider).shouldShowTour, isTrue);

        await c.read(tourProgressProvider.notifier).markTourSeen();
        expect(c.read(tourProgressProvider).shouldShowTour, isFalse);

        c = _container(kv); // "restart"
        await c.read(tourProgressProvider.notifier).ready;
        expect(c.read(tourProgressProvider).tourSeen, isTrue);
        expect(c.read(tourProgressProvider).shouldShowTour, isFalse);
      },
    );

    test(
      'each tab tip is remembered independently and reset clears them',
      () async {
        final kv = MemoryKvStore();
        var c = _container(kv);
        final n = c.read(tourProgressProvider.notifier);
        await n.ready;
        await n.markTipSeen(TipTab.home);
        await n.markTipSeen(TipTab.cards);
        expect(c.read(tourProgressProvider).tipSeen(TipTab.home), isTrue);
        expect(c.read(tourProgressProvider).tipSeen(TipTab.budget), isFalse);

        c = _container(kv);
        await c.read(tourProgressProvider.notifier).ready;
        final s = c.read(tourProgressProvider);
        expect(s.tips, {TipTab.home, TipTab.cards});

        await c.read(tourProgressProvider.notifier).resetTips();
        expect(c.read(tourProgressProvider).tips, isEmpty);
        c = _container(kv);
        await c.read(tourProgressProvider.notifier).ready;
        expect(c.read(tourProgressProvider).tips, isEmpty);
        // Reset tips never replays the tour.
        expect(kv.data.keys.where((k) => k.startsWith('tips.')), isEmpty);
      },
    );

    test('unreadable storage stays quiet: no tour, no tips', () async {
      final c = _container(ThrowingKv());
      await c.read(tourProgressProvider.notifier).ready;
      final s = c.read(tourProgressProvider);
      expect(s.loaded, isTrue);
      expect(s.shouldShowTour, isFalse);
      for (final t in TipTab.values) {
        expect(s.tipSeen(t), isTrue);
      }
    });
  });
}
