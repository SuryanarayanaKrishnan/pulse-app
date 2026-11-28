import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/household/household_invite.dart';
import 'package:pulse/core/household/household_models.dart';
import 'package:pulse/core/household/household_scope.dart';

void main() {
  group('invite code', () {
    final key = Uint8List.fromList(List.generate(32, (i) => i * 7 % 256));
    final inv = HouseholdInvite(
      householdId: '0123456789abcdef0123456789abcdef',
      key: key,
    );

    test('round trips and is readable in groups', () {
      final code = inv.encode();
      expect(code, startsWith('PULSE-HH1-'));
      final back = HouseholdInvite.decode(code);
      expect(back.householdId, inv.householdId);
      expect(back.key, key);
    });

    test('tolerates spacing, case and missing dashes', () {
      final code = inv.encode();
      final messy = '  ${code.toLowerCase().replaceAll('-', ' ')}  ';
      expect(HouseholdInvite.decode(messy).householdId, inv.householdId);
    });

    test('a typo, truncation or another code is rejected', () {
      final code = inv.encode();
      final i = code.length - 6;
      final typo =
          code.substring(0, i) +
          (code[i] == 'A' ? 'B' : 'A') +
          code.substring(i + 1);
      expect(() => HouseholdInvite.decode(typo), throwsFormatException);
      expect(
        () => HouseholdInvite.decode(code.substring(0, code.length - 8)),
        throwsFormatException,
      );
      expect(() => HouseholdInvite.decode('hello'), throwsFormatException);
      expect(() => HouseholdInvite.decode(''), throwsFormatException);
    });

    test('the code carries the key but nothing else personal', () {
      // 1 + 16 + 32 + 4 bytes: no name, no email, no amounts.
      expect(inv.encode().replaceAll('-', '').length, greaterThan(80));
    });
  });

  group('export gate', () {
    HRow row(
      String table, {
      String owner = 'me',
      bool priv = false,
      Map<String, Object?>? v,
    }) => HRow(
      table: table,
      id: 'x',
      owner: owner,
      isPrivate: priv,
      values: v ?? {'name': 'n', 'amount_minor': 1},
    );

    test('private never exports, whoever owns it', () {
      for (final owner in ['me', Owner.shared, 'bbbb']) {
        for (final t in HTable.personal) {
          expect(
            exportRow(
              row(t, owner: owner, priv: true),
              myMemberId: 'aaaa',
              shareMine: true,
            ),
            isNull,
            reason: '$t/$owner',
          );
        }
      }
    });

    test('private jewellery and fund lines never export, shared ones do', () {
      HRow l(String id, {String owner = 'me', bool priv = false}) => HRow(
        table: HTable.lines,
        id: id,
        owner: owner,
        isPrivate: priv,
        values: {
          'name': 'n',
          'liability': false,
          'value_minor': 1,
          'currency': 'AED',
          'notes': 'x',
        },
      );
      final snap = exportSnapshot(
        [
          l('jewel:p', priv: true),
          l('fund:p', priv: true),
          l('jewel:s', owner: Owner.shared),
          l('fund:m'),
        ],
        myMemberId: 'aaaa',
        shareMine: true,
      );
      expect(snap[HTable.lines]!.keys.toSet(), {'jewel:s', 'fund:m'});
      expect(snap[HTable.lines]!['jewel:s']!.containsKey('notes'), isFalse);
      final off = exportSnapshot(
        [l('jewel:p', priv: true), l('fund:m')],
        myMemberId: 'aaaa',
        shareMine: false,
      );
      expect(off, isEmpty);
    });

    test('mine exports only while sharing mine is on; shared and partner items always', () {
      expect(
        exportRow(row('transactions'), myMemberId: 'aaaa', shareMine: false),
        isNull,
      );
      expect(
        exportRow(row('transactions'), myMemberId: 'aaaa', shareMine: true),
        isNotNull,
      );
      expect(
        exportRow(
          row('transactions', owner: Owner.shared),
          myMemberId: 'aaaa',
          shareMine: false,
        ),
        isNotNull,
      );
      expect(
        exportRow(
          row('transactions', owner: 'bbbb'),
          myMemberId: 'aaaa',
          shareMine: false,
        ),
        isNotNull,
      );
    });

    test('owner becomes absolute and unlisted columns are dropped', () {
      final out = exportRow(
        row(
          'transactions',
          v: {
            'amount_minor': 5,
            'notes': 'secret note',
            'tags': '["x"]',
            'merchant_raw': 'RAW',
            'account_id': 'acc',
            'owner': 'me',
          },
        ),
        myMemberId: 'aaaa',
        shareMine: true,
      )!;
      expect(out, {'amount_minor': 5, 'owner': 'aaaa'});
    });

    test('shared tables and unknown tables are not personal exports', () {
      expect(
        exportRow(row('bills'), myMemberId: 'aaaa', shareMine: true),
        isNull,
      );
      expect(
        exportRow(row('raw_ingests'), myMemberId: 'aaaa', shareMine: true),
        isNull,
      );
    });

    test('import trims unknown columns from the log', () {
      expect(importRow('transactions', {'amount_minor': 1, 'evil': 'x'}), {
        'amount_minor': 1,
      });
      expect(importRow('nope', {'a': 1}), isEmpty);
    });
  });
}
