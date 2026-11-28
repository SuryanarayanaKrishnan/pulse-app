import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/bugreport/redactor.dart';

final _digit = RegExp(r'\p{Nd}', unicode: true);

/// Digits that are allowed to survive: `.dart:line:col` and a leading `#n`.
String _withoutKept(String s) => s
    .replaceAll(RegExp(r'\.dart:\d+(?::\d+)?'), '.dart')
    .replaceAll(RegExp(r'^#\d+', multiLine: true), '#');

void main() {
  group('known shapes', () {
    final cases = <String, String>{
      'paid AED 1,234.50 at Spinneys': 'amount',
      'total 99.99 AED': 'amount',
      r'charged $12.40': 'amount',
      'sara.m@example.ae failed': 'email',
      'call +971 50 123 4567 now': 'phone',
      'call 0501234567 now': 'phone',
      'to AE070331234567890123456': 'iban',
      'GB29 NWBK 6016 1331 9268 19': 'iban',
      'account: 1234567890': 'redacted',
      'merchant: Carrefour City, ok': 'redacted',
      '{"merchant": "Talabat", "n": 3}': 'text',
      "FormatException: bad value 'Dad birthday gift'": 'text',
      'see https://x.test/p?token=abc': 'link',
      'amount=450 note=Rent for Sara': 'redacted',
      'balance: AED 25,000': 'redacted',
    };
    cases.forEach((input, marker) {
      test(input, () {
        final out = Redactor.redact(input);
        expect(out, contains(marker));
        expect(out, isNot(matches(_digit)), reason: out);
        for (final secret in [
          'Carrefour',
          'Talabat',
          'example.ae',
          'Rent for Sara',
          'Dad birthday',
          'abc',
        ]) {
          expect(out, isNot(contains(secret)), reason: out);
        }
      });
    });

    test('keeps stack frame positions, drops other digits', () {
      const frame = '#3      _MyState.build (package:pulse/a/b.dart:120:17)';
      final out = Redactor.redact(frame);
      expect(out, contains('b.dart:120:17'));
      expect(out, startsWith('#3 '));
    });

    test('arabic-indic digits go too', () {
      expect(Redactor.redact('رصيد ١٢٣٤٥'), isNot(matches(_digit)));
    });

    test('literal terms are removed', () {
      final out = Redactor.redactWith('opened Mashreq Neo card for Fatima', [
        'mashreq neo',
        'Fatima',
      ]);
      expect(out, isNot(contains('Fatima')));
      expect(out.toLowerCase(), isNot(contains('mashreq')));
    });

    test('plain log text passes through', () {
      expect(Redactor.redact('route /home'), 'route /home');
      expect(Redactor.redact('bug_report_opened'), 'bug_report_opened');
    });
  });

  group('fuzz', () {
    const words = [
      'Spinneys',
      'Sara',
      'Al Mansoori',
      'AED',
      'USD',
      r'$',
      'merchant',
      'note',
      'amount:',
      'iban=',
      'AE07',
      'GB82',
      'WEST',
      'x@y.ae',
      'a.b+c@mail.example.com',
      '+971',
      '050',
      '1,234.50',
      '99',
      '١٢٣',
      'Dhs',
      '12/05',
      '"quoted"',
      "'single'",
      'https://a.b/c?d=1',
      '#4',
      'file.dart:12:3',
      '\n',
      '  ',
      'Rent',
      'Netflix',
    ];

    String randomLine(Random r) {
      final b = StringBuffer();
      for (var i = 0, n = r.nextInt(12) + 1; i < n; i++) {
        switch (r.nextInt(4)) {
          case 0:
            b.write(words[r.nextInt(words.length)]);
          case 1:
            b.write(
              List.generate(r.nextInt(14) + 1, (_) => r.nextInt(10)).join(),
            );
          case 2:
            b.write(
              String.fromCharCodes(
                List.generate(r.nextInt(8) + 1, (_) => 32 + r.nextInt(95)),
              ),
            );
          default:
            b.write(' ');
        }
        if (r.nextBool()) b.write(' ');
      }
      return b.toString();
    }

    test('no digits, emails or phone-length runs survive; idempotent', () {
      final r = Random(42);
      for (var i = 0; i < 3000; i++) {
        final input = randomLine(r);
        final out = Redactor.redact(input);
        expect(
          _withoutKept(out),
          isNot(matches(_digit)),
          reason: 'in: $input\nout: $out',
        );
        expect(
          out,
          isNot(matches(RegExp(r'[\w.+\-]+@[\w\-]+\.\w+'))),
          reason: 'in: $input\nout: $out',
        );
        expect(Redactor.redact(out), out, reason: 'idempotent for: $input');
      }
    });

    test('field values and known names never survive', () {
      final r = Random(7);
      const fields = [
        'merchant',
        'name',
        'note',
        'amount',
        'iban',
        'contact',
        'balance',
      ];
      for (var i = 0; i < 500; i++) {
        final secret =
            'Zq${r.nextInt(900000)}Xy${String.fromCharCode(97 + r.nextInt(26))}';
        final f = fields[r.nextInt(fields.length)];
        final input = switch (r.nextInt(3)) {
          0 => 'evt $f: $secret, done',
          1 => 'evt $f=$secret, done',
          _ => 'evt {"$f":"$secret"} done',
        };
        final out = Redactor.redact(input);
        expect(out, isNot(contains(secret)), reason: out);
        expect(out, isNot(contains('Zq')), reason: out);
      }
    });
  });
}
