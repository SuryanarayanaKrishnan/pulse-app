import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/analytics/event_schema.dart';
import 'package:pulse/core/vault/emergency_sheet.dart';
import 'package:pulse/core/vault/release.dart';
import 'package:pulse/core/vault/shamir.dart';
import 'package:pulse/core/vault/suggestions.dart';
import 'package:pulse/core/vault/vault_models.dart';

final t0 = DateTime.utc(2026, 11, 1);

VaultEntry entry(
  String id,
  VaultType type,
  String inst, {
  String title = '',
  String where = '',
  String? ref,
  int? value,
  String nominee = '',
}) => VaultEntry(
  id: id,
  type: type,
  institution: inst,
  title: title,
  whereToFind: where,
  sourceRef: ref,
  estimatedValueMinor: value,
  nomineeName: nominee,
  createdAt: t0,
  updatedAt: t0,
);

void main() {
  group('suggestions', () {
    final sources = [
      const VaultSource(
        ref: 'account:1',
        type: VaultType.bank,
        institution: 'Emirates NBD',
        title: 'Salary',
        valueMinor: 1200000,
      ),
      const VaultSource(
        ref: 'card:1',
        type: VaultType.card,
        institution: 'ADCB',
        title: 'Touchpoints',
      ),
      const VaultSource(
        ref: 'liability:1',
        type: VaultType.loan,
        institution: 'Car loan',
      ),
      const VaultSource(
        ref: 'recurring:netflix',
        type: VaultType.subscription,
        institution: 'Netflix',
      ),
      const VaultSource(
        ref: 'account:1',
        type: VaultType.bank,
        institution: 'Emirates NBD',
        title: 'Salary',
      ),
      const VaultSource(
        ref: 'asset:blank',
        type: VaultType.bank,
        institution: '  ',
      ),
    ];

    test(
      'everything new is suggested once, in a calm order, blanks dropped',
      () {
        final s = suggestEntries(sources, const []);
        expect(
          [for (final x in s) x.ref],
          ['account:1', 'card:1', 'liability:1', 'recurring:netflix'],
        );
      },
    );

    test(
      'things already in the vault are not suggested again, by ref or by name',
      () {
        final have = [
          entry('e1', VaultType.bank, 'Whatever', ref: 'account:1'),
          entry('e2', VaultType.card, 'adcb', title: 'TOUCHPOINTS'),
        ];
        expect(
          [for (final x in suggestEntries(sources, have)) x.ref],
          ['liability:1', 'recurring:netflix'],
        );
        expect(
          suggestEntries(sources, [
            ...have,
            entry('e3', VaultType.loan, 'Car loan'),
            entry('e4', VaultType.subscription, 'Netflix'),
          ]),
          isEmpty,
        );
      },
    );

    test('recurring merchants map to insurance, loan or subscription', () {
      expect(
        typeFromRecurringMerchant('Sukoon Insurance', isSubscription: false),
        VaultType.insurance,
      );
      expect(
        typeFromRecurringMerchant(
          'Tamweel Home Finance',
          isSubscription: false,
        ),
        VaultType.loan,
      );
      expect(
        typeFromRecurringMerchant('Netflix', isSubscription: true),
        VaultType.subscription,
      );
      expect(
        typeFromRecurringMerchant('Carrefour', isSubscription: false),
        isNull,
      );
    });
  });

  group('completeness', () {
    test('typical expectation is about 12 things', () {
      expect(typicalPerType.values.fold<int>(0, (a, b) => a + b), 12);
      final c = completeness(const []);
      expect((c.found, c.expected), (0, 12));
      expect(c.headline, 'Your family could find 0 of ~12 typical things.');
    });

    test(
      'counts each type up to what is expected; extras do not inflate it',
      () {
        final entries = [
          entry('1', VaultType.bank, 'A'),
          entry('2', VaultType.bank, 'B'),
          entry('3', VaultType.bank, 'C'),
          entry('4', VaultType.card, 'D'),
          entry('5', VaultType.insurance, 'E'),
          entry('6', VaultType.crypto, 'F'),
        ];
        final c = completeness(entries);
        // bank 2 + card 1 + insurance 1; crypto is not expected (0) so it does not count.
        expect(c.found, 4);
        expect(c.missing[VaultType.insurance], 1);
        expect(c.missing.containsKey(VaultType.bank), isFalse);
        expect(c.fraction, closeTo(4 / 12, 1e-9));
      },
    );

    test('what the app already tracks raises the expectation', () {
      final c = completeness(
        [entry('1', VaultType.bank, 'A')],
        tracked: {VaultType.bank: 4, VaultType.crypto: 1},
      );
      expect(c.expected, 12 + 2 + 1);
      expect(c.found, 1);
    });

    test('analytics vault types stay in step with VaultType', () {
      expect(AnalyticsSchema.vaultTypes, [
        for (final t in VaultType.values) t.key,
      ]);
    });
  });

  group('visibility and the emergency sheet', () {
    final entries = [
      entry(
        'b',
        VaultType.bank,
        'Mashreq',
        title: 'Savings',
        where: 'App on my phone; statements in the grey folder',
        nominee: 'Sara',
        value: 1250000,
      ),
      entry('a', VaultType.bank, 'ADCB', where: 'Branch at Deira City Centre'),
      entry(
        'i',
        VaultType.insurance,
        'Sukoon',
        title: 'Term life',
        where: 'Policy in the safe',
      ),
    ];

    test(
      'a person with a subset sees only that subset, ordered by type then name',
      () {
        final n = Nominee(
          id: 'n1',
          name: 'Sara',
          entryIds: {'i', 'a'},
          createdAt: t0,
        );
        expect([for (final e in visibleTo(n, entries)) e.id], ['a', 'i']);
        expect(
          [for (final e in visibleTo(null, entries)) e.id],
          ['a', 'b', 'i'],
        );
        expect(Nominee(id: 'n2', name: 'All', createdAt: t0).seesAll, isTrue);
        expect(Nominee.parseEntryIds(n.entryIdsStored), {'a', 'i'});
        expect(Nominee.parseEntryIds('*'), isNull);
      },
    );

    test('the sheet reads calmly, shows values, and names the caveats', () {
      final n = Nominee(
        id: 'n1',
        name: 'Sara',
        entryIds: {'b', 'i'},
        createdAt: t0,
      );
      final s = emergencySheet(
        ownerName: 'Omar',
        entries: entries,
        forNominee: n,
        now: t0,
      );
      expect(s, contains('# If something happens to Omar'));
      expect(s, contains('for Sara'));
      expect(s, contains('## Bank account'));
      expect(s, contains('**Mashreq, Savings**'));
      expect(s, contains('Nominee named on it: Sara'));
      expect(s, contains('AED 12,500'));
      expect(s, contains('Policy in the safe'));
      expect(s, isNot(contains('ADCB')), reason: 'not visible to Sara');
      expect(s, contains('not a will'));
      expect(s, contains('UAE succession law'));
    });

    test('an empty vault still gives a sensible sheet', () {
      expect(
        emergencySheet(ownerName: '', entries: const [], now: t0),
        contains('Nothing has been added yet.'),
      );
    });
  });

  group('check-in', () {
    test('ok, soon and overdue around the interval', () {
      final last = DateTime.utc(2026, 1, 1);
      CheckInStatus at(int day) => checkInStatus(
        lastCheckIn: last,
        intervalDays: 90,
        now: last.add(Duration(days: day)),
      );
      expect(at(0).phase, CheckInPhase.ok);
      expect(at(0).daysLeft, 90);
      expect(at(75).phase, CheckInPhase.ok);
      expect(at(76).phase, CheckInPhase.soon);
      expect(at(89).daysLeft, 1);
      expect(at(90).phase, CheckInPhase.overdue);
      expect(at(120).phase, CheckInPhase.overdue);
      expect(at(120).daysLeft, -30);
      expect(at(0).releaseAt, last.add(const Duration(days: 90)));
    });
  });

  group('sealed export', () {
    final entries = [
      entry(
        'b',
        VaultType.bank,
        'Mashreq',
        title: 'Savings',
        where: 'App on my phone',
        value: 1250000,
      ),
      entry(
        'i',
        VaultType.insurance,
        'Sukoon',
        title: 'Term life',
        where: 'Policy in the safe',
      ),
      entry(
        'p',
        VaultType.property,
        'Marina flat',
        where: 'Deed in the bank locker',
      ),
    ];
    final nominee = Nominee(
      id: 'nom1',
      name: 'Sara',
      relationship: 'Wife',
      entryIds: {'b', 'i'},
      createdAt: t0,
    );

    test(
      'round trip with every pair of shares; contains only what Sara may see',
      () async {
        final kit = await VaultSeal.createKit(
          ownerName: 'Omar',
          nominee: nominee,
          entries: entries,
          now: t0,
          random: Random(1),
        );
        final shares = [kit.ownerShare, kit.nomineeShare, kit.escrowShare];
        for (final pair in [
          [shares[0], shares[1]],
          [shares[1], shares[2]],
          [shares[0], shares[2]],
          [shares[2], shares[0]],
        ]) {
          final opened = await VaultSeal.open(kit.sealedFile, pair);
          expect(opened.ownerName, 'Omar');
          expect(opened.nomineeName, 'Sara');
          expect({for (final e in opened.entries) e.id}, {'b', 'i'});
          expect(
            opened.entries.firstWhere((e) => e.id == 'b').estimatedValueMinor,
            1250000,
          );
          expect(opened.sheet, contains('Mashreq'));
          expect(opened.sheet, isNot(contains('Marina')));
        }
      },
    );

    test(
      'the file is ciphertext: no names, places or values appear in it',
      () async {
        final kit = await VaultSeal.createKit(
          ownerName: 'Omar',
          nominee: nominee,
          entries: entries,
          now: t0,
          random: Random(2),
        );
        for (final word in [
          'Omar',
          'Sara',
          'Mashreq',
          'Sukoon',
          'safe',
          'institution',
          '12500',
        ]) {
          expect(kit.sealedFile, isNot(contains(word)), reason: word);
        }
        expect(jsonDecode(kit.sealedFile)['app'], 'pulse-vault');
      },
    );

    test('one share alone cannot open it, nor the same share twice, nor a wrong or foreign one', () async {
      final kit = await VaultSeal.createKit(
        ownerName: 'Omar',
        nominee: nominee,
        entries: entries,
        now: t0,
        random: Random(3),
      );
      for (final one in [kit.ownerShare, kit.nomineeShare, kit.escrowShare]) {
        expect(
          VaultSeal.open(kit.sealedFile, [one]),
          throwsA(isA<VaultOpenException>()),
        );
        expect(
          VaultSeal.open(kit.sealedFile, [one, one]),
          throwsA(isA<VaultOpenException>()),
        );
      }
      expect(
        VaultSeal.open(kit.sealedFile, const []),
        throwsA(isA<VaultOpenException>()),
      );

      // A share from another kit (a different secret) fails authentication.
      final other = await VaultSeal.createKit(
        ownerName: 'Omar',
        nominee: nominee,
        entries: entries,
        now: t0,
        random: Random(4),
      );
      expect(
        VaultSeal.open(kit.sealedFile, [kit.nomineeShare, other.escrowShare]),
        throwsA(isA<VaultOpenException>()),
      );
      expect(
        VaultSeal.open(kit.sealedFile, [other.ownerShare, other.nomineeShare]),
        throwsA(isA<VaultOpenException>()),
      );

      // A valid-looking share with a flipped byte (CRC recomputed) fails authentication, not parsing.
      final s = ShamirShare.parse(kit.nomineeShare);
      final bad = ShamirShare(
        threshold: 2,
        x: s.x,
        y: [for (final b in s.y) b ^ 0x10],
      ).encode();
      expect(
        VaultSeal.open(kit.sealedFile, [kit.ownerShare, bad]),
        throwsA(isA<VaultOpenException>()),
      );
      // A mistyped share is caught with a friendly message.
      final typo = kit.nomineeShare.replaceFirst('PVS1', 'PVS2');
      await expectLater(
        VaultSeal.open(kit.sealedFile, [kit.ownerShare, typo]),
        throwsA(
          isA<VaultOpenException>().having(
            (e) => e.message,
            'message',
            contains('not a Pulse key share'),
          ),
        ),
      );
    });

    test(
      'tampering with the file, or pointing it at another nominee, fails',
      () async {
        final kit = await VaultSeal.createKit(
          ownerName: 'Omar',
          nominee: nominee,
          entries: entries,
          now: t0,
          random: Random(5),
        );
        final good = [kit.ownerShare, kit.nomineeShare];
        final j = jsonDecode(kit.sealedFile) as Map<String, dynamic>;

        final ct = base64Decode(j['ct'] as String);
        ct[ct.length ~/ 2] ^= 1;
        expect(
          VaultSeal.open(jsonEncode({...j, 'ct': base64Encode(ct)}), good),
          throwsA(isA<VaultOpenException>()),
        );
        expect(
          VaultSeal.open(jsonEncode({...j, 'for': 'someone-else'}), good),
          throwsA(isA<VaultOpenException>()),
          reason: 'bound to the nominee id',
        );
        expect(
          VaultSeal.open(
            jsonEncode({...j, 'salt': base64Encode(List.filled(16, 9))}),
            good,
          ),
          throwsA(isA<VaultOpenException>()),
        );
        expect(
          VaultSeal.open('not json', good),
          throwsA(isA<VaultOpenException>()),
        );
        expect(
          VaultSeal.open('{"app":"other"}', good),
          throwsA(isA<VaultOpenException>()),
        );
      },
    );

    test(
      'two seals of the same data differ (fresh secret, salt and nonce)',
      () async {
        final a = await VaultSeal.createKit(
          ownerName: 'Omar',
          nominee: nominee,
          entries: entries,
          now: t0,
          random: Random(6),
        );
        final b = await VaultSeal.createKit(
          ownerName: 'Omar',
          nominee: nominee,
          entries: entries,
          now: t0,
          random: Random(7),
        );
        expect(a.sealedFile, isNot(b.sealedFile));
        expect(a.nomineeShare, isNot(b.nomineeShare));
        expect(a.claimCode, isNot(b.claimCode));
        expect(
          RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$')
              .hasMatch(a.claimCode),
          isTrue,
        );
        expect(
          hashClaimCode(a.claimCode.toLowerCase().replaceAll('-', ' ')),
          a.claimCodeHash,
        );
      },
    );
  });
}
