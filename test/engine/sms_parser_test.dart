import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/institutions.dart';
import 'package:pulse/core/engine/sms_parser.dart';
import 'package:pulse/core/engine/types.dart';
import 'package:pulse/core/engine/dates.dart';

import 'fixtures.dart';

void main() {
  final registry = defaultParserRegistry;

  group('Python parity (golden fixtures)', () {
    final cases = loadFixtureList('sms_parser.json');
    test('fixture set is substantial', () => expect(cases.length, greaterThan(40)));
    for (final c in cases) {
      final text = c['text']! as String;
      test('${c['sender']}: ${text.length > 60 ? text.substring(0, 60) : text}', () {
        final r = registry.parse(
          text,
          institution: c['institution'] as String?,
          sender: c['sender'] as String?,
          receivedAt: DateTime.parse(c['received_at']! as String),
        );
        final exp = c['expected'] as Map<String, Object?>?;
        if (exp == null) {
          expect(r, isNull);
          return;
        }
        expect(r, isNotNull);
        expect(r!.institution, exp['institution']);
        expect(r.amountMinor, exp['amount_minor']);
        expect(r.currency, exp['currency']);
        expect(r.direction.name, exp['direction']);
        expect(r.merchantRaw, exp['merchant_raw']);
        expect(r.last4, exp['last4']);
        expect(
          r.postedAt?.toUtc(),
          exp['posted_at'] == null ? isNull : DateTime.parse(exp['posted_at']! as String),
        );
        final resolved = registry.resolve(
          c['institution'] as String?,
          c['sender'] as String?,
          text,
        );
        expect(resolved?.institution, c['resolved']);
      });
    }
  });

  group('registry', () {
    test('every institution has a parser and resolves by sender', () {
      expect(allBankParsers.map((p) => p.institution).toSet(), institutions.keys.toSet());
      expect(allBankParsers.length, 12);
      for (final inst in institutions.all) {
        for (final sender in inst.smsSenders) {
          expect(registry.resolve(null, sender, 'x')!.institution, inst.key, reason: sender);
        }
      }
      expect(registry.institutionKeys, [...institutions.keys, 'tabby']..sort());
    });

    test('institution hint accepts free-text names', () {
      expect(registry.resolve('Emirates NBD', null, 'x')!.institution, 'enbd');
      expect(registry.resolve('Abu Dhabi Islamic Bank', null, 'x')!.institution, 'adib');
      expect(registry.resolve('unknown bank', null, 'x')!.institution, 'generic');
    });

    test('OTPs and non-transactions are ignored for every bank', () {
      for (final p in allBankParsers) {
        expect(
          p.parse('Your OTP is 123456. Do not share. Purchase of AED 45.00 card ending 1234'),
          isNull,
        );
        expect(p.parse('Dear customer, visit our branch for new offers.'), isNull);
      }
      expect(registry.parse('ENBD alert: your OTP 889911 for AED 50 purchase', sender: 'ENBD'), isNull);
    });

    test('isOtpMessage flags password-style texts only', () {
      expect(isOtpMessage('Your OTP is 123456'), isTrue);
      expect(isOtpMessage('Use verification code 4455'), isTrue);
      expect(isOtpMessage('Never share your CVV with anyone'), isTrue);
      expect(isOtpMessage('Purchase of AED 45.00 at CARREFOUR'), isFalse);
    });

    test('a custom parser is picked by hint, sender and falls back to generic', () {
      final reg = ParserRegistry(fallback: GenericParser())..register(_Fake());
      expect(reg.resolve('fakebank', null, 'x')!.institution, 'FakeBank');
      expect(reg.resolve(null, 'FAKEBANK', 'x')!.institution, 'FakeBank');
      expect(reg.resolve(null, 'OTHER', 'x')!.institution, 'generic');
      expect(reg.institutionKeys, ['fakebank']);
    });

    test('bank parser falls back to heuristics but keeps the institution', () {
      final r = registry.parse(
        'Salary credited Dhs. 15000 to your account ending 9876',
        sender: 'MASHREQ',
      );
      expect(r!.direction, Direction.credit);
      expect(r.amountMinor, 1500000);
      expect(r.institution, 'mashreq');
    });
  });

  group('structured amounts and dates', () {
    test('parseMinorUnits rounds half to even like Decimal', () {
      expect(parseMinorUnits('12.345'), 1234);
      expect(parseMinorUnits('12.355'), 1236);
      expect(parseMinorUnits('1,234.50'), 123450);
      expect(parseMinorUnits('45'), 4500);
      expect(parseMinorUnits('abc'), isNull);
    });

    test('parseDate handles UAE day-first formats', () {
      expect(parseDate('12/03/2026'), const CalDate(2026, 3, 12));
      expect(parseDate('12-03-26'), const CalDate(2026, 3, 12));
      expect(parseDate('12 Mar 2026'), const CalDate(2026, 3, 12));
      expect(parseDate('12-Mar-26'), const CalDate(2026, 3, 12));
      expect(parseDate('12MAR26'), const CalDate(2026, 3, 12));
      expect(parseDate('12 March, 2026'), const CalDate(2026, 3, 12));
      expect(parseDate('2026-03-12'), const CalDate(2026, 3, 12));
      expect(parseDate('31/02/2026'), isNull);
      expect(parseDate('nonsense'), isNull);
    });

    test('Dubai date crosses midnight UTC', () {
      expect(toDubaiDate(DateTime.utc(2026, 3, 11, 21, 30)), const CalDate(2026, 3, 12));
    });
  });
}

class _Fake implements MessageParser {
  @override
  String get institution => 'FakeBank';
  @override
  bool matches(String? sender, String text) => sender == 'FAKEBANK';
  @override
  ParsedTransaction? parse(String text, {DateTime? receivedAt}) =>
      const ParsedTransaction(amountMinor: 1, currency: 'AED', direction: Direction.debit);
}
