import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/learning/global_merchant_map.dart';
import 'package:pulse/core/learning/privacy_filter.dart';

final _map = GlobalMerchantMap(
  version: 1,
  entries: const {'carrefour': 'groceries', 'spinneys': 'groceries', '7 eleven': 'groceries'},
);
final _f = MerchantKeyFilter(_map);

void main() {
  group('what passes', () {
    test('known merchants', () {
      for (final k in ['carrefour', 'spinneys', '7 eleven']) {
        expect(_f.accepts(k), isTrue, reason: k);
      }
    });

    test('plain business names with a business word', () {
      for (final k in [
        'al amal pharmacy', 'green leaf cafe', 'blue sky trading llc',
        "joe's pizza", 'fresh juice center', 'palm jumeirah hotel', //
      ]) {
        expect(_f.accepts(k), isTrue, reason: k);
      }
    });
  });

  group('what never passes', () {
    final cases = <String, KeyRejection>{
      '': KeyRejection.empty,
      '   ': KeyRejection.empty,
      'Carrefour': KeyRejection.notNormalised,
      'a  b cafe': KeyRejection.notNormalised,
      ' cafe ': KeyRejection.notNormalised,
      'john.smith@gmail.com': KeyRejection.email,
      'pay me@x cafe': KeyRejection.email,
      'https://pay.example.com/cafe': KeyRejection.url,
      'www.cafe.example': KeyRejection.url,
      '+971501234567': KeyRejection.phone,
      '050 123 4567 cafe': KeyRejection.digits,
      '0501234567': KeyRejection.digits,
      '050 123 45 cafe': KeyRejection.phone,
      'cafe 1234': KeyRejection.digits,
      'ae070331234567890123456': KeyRejection.digits,
      'transfer to ahmed': KeyRejection.transferText,
      'salary march cafe': KeyRejection.transferText,
      'atm cash withdrawal': KeyRejection.transferText,
      'mohammed ali pharmacy': KeyRejection.personLike,
      'fatima supermarket': KeyRejection.personLike,
      'mr smith restaurant': KeyRejection.personLike,
      'ahmed bin rashid trading': KeyRejection.personLike,
      'sunita kumar store': KeyRejection.personLike,
      'john smith': KeyRejection.personLike,
      'quiet corner': KeyRejection.notBusiness,
      'random words here': KeyRejection.notBusiness,
      'a b c d e f cafe': KeyRejection.tooManyWords,
      'cafe/restaurant': KeyRejection.badCharacters,
      'cafe\u0000x': KeyRejection.badCharacters,
      'café محمد': KeyRejection.badCharacters,
    };
    cases.forEach((k, why) {
      test('"$k" is refused', () {
        final d = _f.check(k);
        expect(d.ok, isFalse);
        expect(d.rejection, why);
      });
    });

    test('null and over-long keys', () {
      expect(_f.check(null).rejection, KeyRejection.empty);
      expect(_f.check('${'a' * 41} cafe').rejection, KeyRejection.tooLong);
    });

    test('hard rules apply even to a "known" key that is polluted', () {
      final m = GlobalMerchantMap(version: 1, entries: const {
        'x@y.com': 'dining',
        'cafe 12345': 'dining',
        'cafe +971': 'dining',
      });
      final f = MerchantKeyFilter(m);
      for (final k in m.entries.keys) {
        expect(f.accepts(k), isFalse, reason: k);
      }
    });
  });

  group('fuzz', () {
    final rng = Random(20260124);
    const alphabet = "abcdefghijklmnopqrstuvwxyz0123456789 &'.-+@_/:,éأ\u0000\t";
    String randomString([int max = 60]) {
      final n = rng.nextInt(max);
      return String.fromCharCodes([for (var i = 0; i < n; i++) alphabet.runes.elementAt(rng.nextInt(alphabet.runes.length))]);
    }

    /// Whatever the filter accepts must satisfy every privacy invariant.
    void expectSafe(String k) {
      expect(RegExp(r'\d{4}').hasMatch(k), isFalse, reason: 'digit run in "$k"');
      expect(RegExp(r'\d').allMatches(k).length, lessThanOrEqualTo(4), reason: 'digits in "$k"');
      expect(k.contains('@'), isFalse, reason: k);
      expect(k.contains('+'), isFalse, reason: k);
      expect(k.contains('http'), isFalse, reason: k);
      expect(k.length, lessThanOrEqualTo(MerchantKeyFilter.maxLength), reason: k);
      expect(k, k.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '));
      expect(RegExp(r'[\u0000-\u001f]').hasMatch(k), isFalse);
    }

    test('random strings: nothing unsafe is ever accepted', () {
      var accepted = 0;
      for (var i = 0; i < 20000; i++) {
        final k = randomString();
        if (_f.accepts(k)) {
          accepted++;
          expectSafe(k);
        }
      }
      expect(accepted, lessThan(20000)); // the filter is not trivially open
    });

    test('random strings with a business word still cannot smuggle private text', () {
      const words = ['cafe', 'trading', 'llc', 'pharmacy', 'store'];
      for (var i = 0; i < 20000; i++) {
        final k = '${randomString(30)} ${words[rng.nextInt(words.length)]} ${randomString(30)}'
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (_f.accepts(k)) expectSafe(k);
      }
    });

    String digits(int n) => [for (var i = 0; i < n; i++) rng.nextInt(10)].join();

    test('phone numbers, emails, IBANs and card numbers never pass, however dressed', () {
      const names = ['pharmacy', 'cafe', 'trading llc', 'supermarket'];
      for (var i = 0; i < 3000; i++) {
        final biz = names[rng.nextInt(names.length)];
        final privates = [
          '+971${digits(9)}',
          '05${rng.nextInt(10)}${digits(7)}',
          '05${rng.nextInt(10)} ${digits(3)} ${digits(4)}',
          '${digits(4)} ${digits(4)} ${digits(4)} ${digits(4)}',
          'ae${digits(2)}${digits(19)}',
          'user${rng.nextInt(999)}@mail.${['com', 'ae', 'org'][rng.nextInt(3)]}',
          'ref ${digits(8)}',
        ];
        final p = privates[rng.nextInt(privates.length)];
        for (final k in ['$p $biz', '$biz $p', '$biz ${p.replaceAll(' ', '')}', p]) {
          expect(_f.accepts(k.toLowerCase()), isFalse, reason: k);
        }
      }
    });

    test('person-like names never pass, with or without a business word', () {
      const first = ['mohammed', 'ahmed', 'fatima', 'sarah', 'john', 'priya', 'rahul', 'omar', 'maryam', 'david'];
      const last = ['khan', 'smith', 'patel', 'ali', 'hassan', 'kumar', 'sharma', 'bin rashid'];
      const biz = ['', ' trading', ' pharmacy', ' llc', ' cafe', ' store'];
      for (final a in first) {
        for (final b in last) {
          for (final c in biz) {
            final k = '$a $b$c';
            expect(_f.accepts(k), isFalse, reason: k);
          }
        }
      }
    });
  });
}
