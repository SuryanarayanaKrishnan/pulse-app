import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/card_combos.dart';

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

    test('combos with a figure come first; the worked chain leads', () {
      expect(combos.first.id, 'reddit-tabby-sib-chain');
      expect(combos.first.annualSavingAed, 3041);
      // Anything without a figure (warnings, tips) follows everything that has one.
      final firstPlain = combos.indexWhere((c) => !c.hasSaving);
      expect(combos.skip(firstPlain).every((c) => !c.hasSaving), isTrue);
    });

    test(
      'no combo carries a hand-typed figure: every figure has its working',
      () {
        for (final c in combos.where((c) => c.hasSaving)) {
          expect(c.breakdown, isNotEmpty, reason: c.id);
        }
      },
    );
  });
}
