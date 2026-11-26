import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/card_combos.dart';
import 'package:pulse/data/card_suggestions.dart';
import 'package:pulse/data/models.dart';

Map<String, Object?> _item(
  String id, {
  String severity = 'info',
  String tier = 'free',
  num? saving,
}) => {
  'id': id,
  'title': id,
  'severity': severity,
  'tier': tier,
  'annual_saving_aed': ?saving,
};

void main() {
  test('savings first (largest first), then free before plus, info before warnings', () {
    final out = parseCombos(
      jsonEncode({
        'items': [
          _item('warn-free', severity: 'warn'),
          _item('plus-info', tier: 'plus'),
          _item('small', saving: 100),
          _item('info-free'),
          _item('big-warn-plus', severity: 'warn', tier: 'plus', saving: 900),
        ],
      }),
      now: DateTime(2026, 11, 30),
    );
    expect(out.map((c) => c.id), [
      'big-warn-plus',
      'small',
      'info-free',
      'warn-free',
      'plus-info',
    ]);
  });

  test('a warning with no figure never outranks a combo with savings', () {
    final out = parseCombos(
      jsonEncode({
        'items': [_item('warn', severity: 'warn'), _item('combo', saving: 1)],
      }),
    );
    expect(out.first.id, 'combo');
  });

  group('shipped bundle', () {
    final combos = parseCombos(
      File('assets/catalog/combos.json').readAsStringSync(),
      now: DateTime(2026, 11, 30),
    );

    test('combos with a figure come first, Tabby via SIB Cashback among them with its estimate', () {
      // The Reddit stack has the bigger figure; Tabby via SIB follows it.
      expect(combos.first.id, 'reddit-liv-df-sib-tabby-stack');
      final top = combos[1];
      expect(top.id, 'sib-cashback-tabby-wallet-only');
      expect(top.isWarning, isTrue);
      expect(top.hasSaving, isTrue);
      expect(top.savingNote, contains('Estimate'));
      // Warnings without a figure sit after everything that has one.
      final firstPlain = combos.indexWhere((c) => !c.hasSaving);
      expect(combos.skip(firstPlain).every((c) => !c.hasSaving), isTrue);
    });

    test('the figure follows from the catalog rates and the typical shopping spend', () {
      // sib-cashback: 10% online/wallet (cap AED 300 a month), 0.5% when the
      // card number is typed in (MCC 5999), per pulse-api data/cards/banks/sib.json.
      final monthly = typicalMonthlySpend[SpendCategory.shopping]!;
      const wallet = 0.10, typed = 0.005, cap = 300.0;
      final walletEarn = (monthly * wallet).clamp(0, cap);
      final annual = (walletEarn - monthly * typed) * 12;
      expect(combos[1].annualSavingAed, closeTo(annual, 0.5));
      expect(annual.round(), 798);
    });
  });
}
