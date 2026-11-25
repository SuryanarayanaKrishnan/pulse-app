import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/engine/review.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/review/review_screen.dart';
import 'package:pulse/features/review/review_state.dart';

class Rec implements Analytics {
  final events = <AnalyticsEvent>[];
  @override
  void track(AnalyticsEvent e) => events.add(e);
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

late MockPulseRepository repo;
late Rec rec;
late MemoryKvStore kv;
late List<MethodCall> haptics;

Future<List<Transaction>> queue() async {
  final all = await repo.transactions();
  final byId = {for (final t in all) t.id: t};
  return [
    for (final id in orderReviewQueue([
      for (final t in all)
        ReviewCandidate(id: t.id, amount: t.amount, confidence: t.confidence, date: t.date, reviewed: t.reviewed),
    ]))
      byId[id]!,
  ];
}

Future<void> pump(
  WidgetTester t, {
  bool reduceMotion = false,
  bool allReviewed = false,
  bool dark = false,
  DateTime? now,
}) async {
  PulseTheme.useGoogleFonts = false;
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  repo = MockPulseRepository(latency: Duration.zero);
  if (allReviewed) await repo.setReviewed([for (final x in await repo.transactions()) x.id], true);
  rec = Rec();
  kv = MemoryKvStore();
  haptics = [];
  t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
    haptics.add(c);
    return null;
  });
  addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        analyticsProvider.overrideWithValue(rec),
        kvStoreProvider.overrideWithValue(kv),
        if (now != null) reviewClockProvider.overrideWithValue(() => now),
      ],
      child: MaterialApp(
        theme: dark ? PulseTheme.dark : PulseTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const ReviewScreen(),
      ),
    ),
  );
  await t.pumpAndSettle();
}

final _card = find.byKey(const ValueKey('review-card'));

void main() {
  testWidgets('shows the first payment: biggest or least sure, with card and count', (t) async {
    await pump(t);
    final q = await queue();
    expect(q.length, greaterThan(3));
    expect(find.text('${q.length} left'), findsOneWidget);
    expect(find.descendant(of: _card, matching: find.text(q.first.merchant)), findsOneWidget);
    expect(find.descendant(of: _card, matching: find.text(q.first.category.label)), findsOneWidget);
    expect(find.descendant(of: _card, matching: find.text(q.first.accountLabel)), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget); // present but hidden until used
  });

  testWidgets('swipe right marks it reviewed and shows the next card', (t) async {
    await pump(t);
    final q = await queue();
    await t.drag(_card, const Offset(320, 0));
    await t.pumpAndSettle();
    expect((await repo.transactions()).firstWhere((x) => x.id == q.first.id).reviewed, isTrue);
    expect(find.text('${q.length - 1} left'), findsOneWidget);
    expect(find.descendant(of: _card, matching: find.text(q[1].merchant)), findsOneWidget);
    expect(rec.events.map((e) => e.name), ['review_swiped']);
    expect(rec.events.single.properties, {'direction': 'right'});
    expect(haptics.any((c) => c.method == 'HapticFeedback.vibrate'), isTrue);
  });

  testWidgets('a short drag springs back and changes nothing', (t) async {
    await pump(t);
    final q = await queue();
    await t.drag(_card, const Offset(40, 0));
    await t.pumpAndSettle();
    expect(find.text('${q.length} left'), findsOneWidget);
    expect(rec.events, isEmpty);
  });

  testWidgets('the Looks right button does the same as swiping', (t) async {
    await pump(t);
    final q = await queue();
    await t.tap(find.text('Looks right'));
    await t.pumpAndSettle();
    expect(find.text('${q.length - 1} left'), findsOneWidget);
    expect(rec.events.single.properties, {'direction': 'right'});
  });

  testWidgets('undo brings the last card back and unmarks it', (t) async {
    await pump(t);
    final q = await queue();
    await t.drag(_card, const Offset(320, 0));
    await t.pumpAndSettle();
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(find.text('${q.length} left'), findsOneWidget);
    expect(find.descendant(of: _card, matching: find.text(q.first.merchant)), findsOneWidget);
    expect((await repo.transactions()).firstWhere((x) => x.id == q.first.id).reviewed, isFalse);
  });

  testWidgets('swipe left opens the category picker, then the scope sheet, and fixes it', (t) async {
    await pump(t);
    final q = await queue();
    final first = q.first;
    await t.drag(_card, const Offset(-320, 0));
    await t.pumpAndSettle();
    expect(find.text('Fix category'), findsOneWidget);
    final target = first.category == SpendCategory.shopping ? SpendCategory.travel : SpendCategory.shopping;
    await t.tap(find.text(target.label).last);
    await t.pumpAndSettle();
    expect(find.text('Just this one'), findsOneWidget);
    await t.tap(find.text('Apply'));
    await t.pumpAndSettle();

    final after = (await repo.transactions()).firstWhere((x) => x.id == first.id);
    expect(after.category, target);
    expect(after.reviewed, isTrue);
    expect(find.text('${q.length - 1} left'), findsOneWidget);
    final swipes = rec.events.where((e) => e.name == 'review_swiped');
    expect(swipes.single.properties, {'direction': 'left'});
    expect(rec.events.map((e) => e.name), contains('transaction_recategorized'));
  });

  testWidgets('dismissing the picker leaves the card where it was', (t) async {
    await pump(t);
    final q = await queue();
    await t.drag(_card, const Offset(-320, 0));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(200, 15)); // the barrier
    await t.pumpAndSettle();
    expect(find.text('Fix category'), findsNothing);
    expect(find.text('${q.length} left'), findsOneWidget);
    expect(rec.events, isEmpty);
    expect((await repo.transactions()).firstWhere((x) => x.id == q.first.id).reviewed, isFalse);
  });

  testWidgets('tapping the card shows its details', (t) async {
    await pump(t);
    await t.tap(_card);
    await t.pumpAndSettle();
    expect(find.text('Captured via'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('clearing the stack ends in a quiet inbox zero and records the day', (t) async {
    await pump(t, now: DateTime(2026, 3, 12, 10));
    final n = (await queue()).length;
    for (var i = 0; i < n; i++) {
      await t.tap(find.text('Looks right'));
      await t.pumpAndSettle();
    }
    expect(find.text('Inbox zero'), findsOneWidget);
    expect(find.text('Looks right'), findsNothing);
    expect(find.textContaining('1 day at inbox zero'), findsOneWidget);
    expect(rec.events.where((e) => e.name == 'review_inbox_zero'), hasLength(1));
    expect(kv.data['review.zero_days'], '2026-03-12');
    // Nothing guilt-shaped on the screen.
    expect(find.textContaining('lost'), findsNothing);
    expect(find.textContaining('broke'), findsNothing);
  });

  testWidgets('undo after inbox zero brings the last card back', (t) async {
    await pump(t);
    final n = (await queue()).length;
    for (var i = 0; i < n; i++) {
      await t.tap(find.text('Looks right'));
      await t.pumpAndSettle();
    }
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(find.text('1 left'), findsOneWidget);
  });

  testWidgets('an empty inbox is a calm empty state, not an event', (t) async {
    await pump(t, allReviewed: true);
    expect(find.text('Inbox zero'), findsOneWidget);
    expect(find.textContaining('Everything has been looked at.'), findsOneWidget);
    expect(rec.events, isEmpty);
    expect(find.text('Undo'), findsOneWidget);
    await t.tap(find.text('Done'));
    await t.pumpAndSettle();
  });

  testWidgets('streak from earlier days is shown, and only as a quiet line', (t) async {
    await pump(t, allReviewed: true, now: DateTime(2026, 3, 12, 10));
    // Two earlier days already recorded.
    kv.data['review.zero_days'] = '2026-03-10,2026-03-11';
    // A fresh container reads them.
    await t.pumpWidget(const SizedBox());
    await pumpWithKv(t, kv);
    expect(find.textContaining('3 days at inbox zero'), findsOneWidget);
  });

  testWidgets('reduced motion: the card moves without animating, and still works', (t) async {
    await pump(t, reduceMotion: true);
    final q = await queue();
    await t.drag(_card, const Offset(320, 0));
    await t.pump(); // one frame, no settling
    expect(find.text('${q.length - 1} left'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('works in dark mode', (t) async {
    await pump(t, dark: true);
    expect(find.text('Looks right'), findsOneWidget);
    await t.tap(find.text('Looks right'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}

Future<void> pumpWithKv(WidgetTester t, MemoryKvStore store) async {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  final r = MockPulseRepository(latency: Duration.zero);
  await r.setReviewed([for (final x in await r.transactions()) x.id], true);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(r),
        analyticsProvider.overrideWithValue(Rec()),
        kvStoreProvider.overrideWithValue(store),
        reviewClockProvider.overrideWithValue(() => DateTime(2026, 3, 12, 10)),
      ],
      child: MaterialApp(theme: PulseTheme.light, home: const ReviewScreen()),
    ),
  );
  await t.pumpAndSettle();
}
