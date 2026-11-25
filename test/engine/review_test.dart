import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/review.dart';

ReviewCandidate c(
  String id,
  double amount,
  double conf, {
  int day = 1,
  bool reviewed = false,
}) => ReviewCandidate(
  id: id,
  amount: amount,
  confidence: conf,
  date: DateTime.utc(2026, 3, day),
  reviewed: reviewed,
);

void main() {
  group('orderReviewQueue', () {
    test('drops reviewed ones', () {
      expect(
        orderReviewQueue([c('a', 10, 0.9), c('b', 20, 0.9, reviewed: true)]),
        ['a'],
      );
    });

    test('biggest first when all are confident', () {
      expect(
        orderReviewQueue([c('s', 10, 0.8), c('l', 900, 0.8), c('m', 50, 0.8)]),
        ['l', 'm', 's'],
      );
    });

    test('unsure ones come first, even when small', () {
      expect(
        orderReviewQueue([
          c('big', 900, 0.9),
          c('tiny-unsure', 5, 0.2),
          c('mid', 50, 0.7),
        ]),
        ['tiny-unsure', 'big', 'mid'],
      );
    });

    test('among equals: least confident, then newest, then id', () {
      expect(orderReviewQueue([c('a', 40, 0.8), c('b', 40, 0.6)]), ['b', 'a']);
      expect(
        orderReviewQueue([
          c('old', 40, 0.7, day: 1),
          c('new', 40, 0.7, day: 9),
        ]),
        ['new', 'old'],
      );
      expect(orderReviewQueue([c('y', 40, 0.7), c('x', 40, 0.7)]), ['x', 'y']);
    });

    test('is deterministic whatever the input order', () {
      final items = [
        for (var i = 0; i < 20; i++)
          c(
            't$i',
            (i * 37 % 11) * 10.0,
            i % 3 == 0 ? 0.3 : 0.8,
            day: 1 + i % 5,
          ),
      ];
      final a = orderReviewQueue(items);
      final b = orderReviewQueue(items.reversed);
      expect(b, a);
    });

    test(
      'empty in, empty out',
      () => expect(orderReviewQueue(const []), isEmpty),
    );
  });

  group('categoryConfidence', () {
    test('no category or Other is unsure, a rule is surest', () {
      expect(categoryConfidence(hasCategory: false), lessThan(unsureBelow));
      expect(
        categoryConfidence(hasCategory: true, isOther: true),
        lessThan(unsureBelow),
      );
      expect(
        categoryConfidence(hasCategory: true, ruleApplied: true),
        greaterThan(categoryConfidence(hasCategory: true)),
      );
      expect(
        categoryConfidence(hasCategory: true),
        greaterThanOrEqualTo(unsureBelow),
      );
    });
  });

  group('reviewStreak', () {
    const today = CalDate(2026, 3, 12);
    Set<CalDate> days(List<int> d) => {for (final x in d) CalDate(2026, 3, x)};

    test('no days, no streak', () => expect(reviewStreak({}, today), 0));
    test(
      'counts consecutive days ending today',
      () => expect(reviewStreak(days([10, 11, 12]), today), 3),
    );
    test(
      'today not cleared yet: yesterday keeps it alive',
      () => expect(reviewStreak(days([10, 11]), today), 2),
    );
    test(
      'a gap starts again',
      () => expect(reviewStreak(days([8, 9, 11, 12]), today), 2),
    );
    test(
      'last cleared two days ago: a fresh start, not a penalty',
      () => expect(reviewStreak(days([9, 10]), today), 0),
    );
    test('crosses month ends', () {
      expect(
        reviewStreak({
          const CalDate(2026, 2, 28),
          const CalDate(2026, 3, 1),
          const CalDate(2026, 3, 2),
        }, const CalDate(2026, 3, 2)),
        3,
      );
    });
  });

  group('storage', () {
    test('round trips and ignores junk', () {
      final d = {const CalDate(2026, 3, 1), const CalDate(2026, 3, 2)};
      expect(decodeZeroDays(encodeZeroDays(d)), d);
      expect(decodeZeroDays(null), isEmpty);
      expect(decodeZeroDays('nope,2026-03-01,,2026-13'), {
        const CalDate(2026, 3, 1),
      });
    });

    test('withInboxZero adds today and forgets the very old', () {
      const today = CalDate(2026, 3, 12);
      final out = withInboxZero({
        const CalDate(2024, 1, 1),
        const CalDate(2026, 3, 11),
      }, today);
      expect(out, {const CalDate(2026, 3, 11), today});
    });

    test('streakLabel is plain and says nothing for zero', () {
      expect(streakLabel(0), isNull);
      expect(streakLabel(1), '1 day at inbox zero');
      expect(streakLabel(5), '5 days at inbox zero');
    });
  });
}
