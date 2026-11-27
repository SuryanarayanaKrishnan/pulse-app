import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/combo_savings.dart';
import 'package:pulse/data/card_combos.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final catalog = _json('assets/catalog/cards.json');

  test('the stack estimate is worked out from the catalog, step by step', () {
    final e = estimateRedditStack(catalog);
    // The app's typical month: 1500+900+600+700+400+250+300+500.
    expect(e.monthlySpendAed, 5150);
    // Liv alone: 1.5% tier on AED 4,650, 0.1% on AED 500 of bills.
    expect(e.livAloneMonthlyAed, closeTo(70.25, 1e-9));
    // Chain: non-bill spend (AED 4,650) is capped at what AED 300 pays 10% on.
    expect(e.chainMonthlyAed, closeTo(3000, 1e-9));
    // SIB 10% on AED 3,000 is AED 300, the monthly cap.
    expect(e.sibMonthlyAed, closeTo(300, 1e-9));
    // Tabby's 1% repayment fee on AED 3,000.
    expect(e.tabbyFeeMonthlyAed, closeTo(30, 1e-9));
    // Liv keeps AED 500 of bills (0.1%) and AED 1,650 at its 0.75% tier.
    expect(e.livMonthlyAed, closeTo(12.875, 1e-9));
    // Only SIB's AED 199 annual fee, read from annual_fee_minor.
    expect(e.annualFeesAed, closeTo(199, 1e-9));
    expect(e.grossYearlyAed, closeTo(2551.5, 1e-9));
    expect(e.netYearlyAed, closeTo(2352.5, 1e-9));
    expect(e.netYearlyAed.round(), 2353);
  });

  test('caps bite: heavy spend never earns past the catalog caps', () {
    final e = estimateRedditStack(
      catalog,
      typicalMinor: const {
        'groceries': 5000000,
        'dining': 5000000,
        'shopping': 5000000,
        'travel': 0,
        'entertainment': 0,
        'transport': 0,
        'health': 0,
        'utilities': 0,
      },
    );
    expect(e.chainMonthlyAed, 3000); // AED 300 cap / 10%
    expect(e.sibMonthlyAed, 300);
  });

  test('combos.json carries the same figure, labelled an estimate, with its cards', () {
    final combos = _json('assets/catalog/combos.json');
    final item = (combos['items'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((i) => i['id'] == 'reddit-liv-df-sib-tabby-stack');
    final e = estimateRedditStack(catalog);
    expect(item['annual_saving_aed'], e.netYearlyAed.round());
    expect(item['saving_note'], startsWith('Estimate, not a promise'));
    expect(item['saving_note'], contains('about AED 2,353 a year'));
    final ids = {for (final c in (catalog['cards'] as List)) (c as Map)['id']};
    for (final id in (item['card_ids'] as List)) {
      expect(ids, contains(id), reason: '$id is in the catalog');
    }
    expect(
      item['card_ids'],
      containsAll([
        'liv-cashback',
        'dubai-first-cashback',
        'sib-cashback',
        'tabby-card',
      ]),
    );
    expect((item['sources'] as List), isNotEmpty);
  });

  test('it parses, and ranks first by saving', () {
    final parsed = parseCombos(
      File('assets/catalog/combos.json').readAsStringSync(),
      now: DateTime(2026, 11, 26),
    );
    expect(parsed.first.id, 'reddit-liv-df-sib-tabby-stack');
    expect(parsed.first.hasSaving, isTrue);
    expect(parsed.first.isPlus, isFalse);
  });
}
