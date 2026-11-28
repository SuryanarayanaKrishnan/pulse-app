import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/dbr.dart';

void main() {
  test('official cap is 50 percent', () => expect(dbrMaxPct, 50.0));

  test('total limit, shares and DBR', () {
    final r = computeDbr(
      cards: const [
        DbrCard(name: 'A', limitMinor: 3000000), // AED 30,000
        DbrCard(name: 'B', limitMinor: 1000000), // AED 10,000
      ],
      salaryMinor: 2000000, // AED 20,000
    );
    expect(r.totalLimitMinor, 4000000);
    expect(r.cards.first.name, 'A');
    expect(r.cards.first.sharePct, 75);
    expect(r.cardObligationMinor, 200000); // 5% of 40,000
    expect(r.dbrPct, 10.0);
    expect(r.headroomMinor, 800000); // 10,000 cap - 2,000
    expect(r.extraCardLimitMinor, 16000000); // 8,000 / 5%
    expect(r.level, DbrLevel.healthy);
  });

  test('loans count and can put you over', () {
    final r = computeDbr(
      cards: const [DbrCard(name: 'A', limitMinor: 2000000)],
      salaryMinor: 1000000,
      loanEmisMinor: 450000,
    );
    expect(r.dbrPct, 55.0);
    expect(r.level, DbrLevel.over);
    expect(r.headroomMinor, -50000);
    expect(r.extraCardLimitMinor, 0);
  });

  test('tight band', () {
    final r = computeDbr(
      cards: const [],
      salaryMinor: 1000000,
      loanEmisMinor: 420000,
    );
    expect(r.level, DbrLevel.tight);
  });

  test('no salary: totals only, level unknown', () {
    final r = computeDbr(
      cards: const [
        DbrCard(name: 'A', limitMinor: 500000),
        DbrCard(name: 'Z', limitMinor: 0),
      ],
    );
    expect(r.totalLimitMinor, 500000);
    expect(r.cards.length, 1);
    expect(r.dbrPct, isNull);
    expect(r.level, DbrLevel.unknown);
    expect(newCardBreaksCap(r, 1000000), isNull);
  });

  test('new card check', () {
    final r = computeDbr(
      cards: const [DbrCard(name: 'A', limitMinor: 1000000)],
      salaryMinor: 1000000,
    );
    // headroom 5,000 - 500 = 4,500; a 100,000 card adds 5,000.
    expect(newCardBreaksCap(r, 10000000), isTrue);
    expect(newCardBreaksCap(r, 5000000), isFalse);
  });
}
