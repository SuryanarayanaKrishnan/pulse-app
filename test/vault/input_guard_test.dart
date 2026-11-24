import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/vault/input_guard.dart';

bool blocks(String s, [GuardKind? kind]) {
  final b = InputGuard.blocking(s);
  return kind == null ? b.isNotEmpty : b.any((i) => i.kind == kind);
}

void main() {
  group('card numbers', () {
    test(
      'full numbers that pass Luhn are blocked, with or without separators',
      () {
        for (final s in [
          '4111111111111111',
          '4111 1111 1111 1111',
          'Visa 4111-1111-1111-1111 in wallet',
          '5555555555554444',
          '378282246310005', // Amex, 15
          'card: 6011 1111 1111 1117.',
        ]) {
          expect(blocks(s, GuardKind.card), isTrue, reason: s);
        }
      },
    );
    test('four groups of four are blocked even if the checksum fails', () {
      expect(blocks('1234 5678 9012 3456', GuardKind.card), isTrue);
    });
    test('last four digits, phone numbers and amounts are fine', () {
      for (final s in [
        'Visa ending 4242',
        'card ends 1111',
        'call 04 123 4567',
        'AED 1234567 approx',
        'Policy no ends 99812',
        '+971 50 123 4567',
      ]) {
        expect(blocks(s), isFalse, reason: s);
      }
    });
  });

  group('IBAN', () {
    test('valid and UAE-shaped IBANs are blocked, spaced or not', () {
      for (final s in [
        'AE070331234567890123456',
        'AE07 0331 2345 6789 0123 456',
        'IBAN: GB82WEST12345698765432',
        'de89 3704 0044 0532 0130 00',
        'AE000000000000000000000', // wrong checksum but UAE-shaped
      ]) {
        expect(blocks(s, GuardKind.iban), isTrue, reason: s);
      }
    });
    test('a partial IBAN or plain words are fine', () {
      for (final s in [
        'IBAN ends 3456',
        'AE07 ... 3456',
        'Savings account, salary lands here',
        'ref AB12 only',
      ]) {
        expect(blocks(s), isFalse, reason: s);
      }
    });
  });

  group('passwords, PINs and phrases', () {
    test('obvious passwords are blocked', () {
      for (final s in [
        'password: hunter2',
        'Password is Tr0ub4dor',
        'my passcode = 7781',
        'pwd - Summer2024!',
        'login password Abcdef1',
        'PIN 4821',
        'pin is 1234',
        'CVV: 123',
        'otp 884213',
        'ATM PIN: 5521',
      ]) {
        expect(blocks(s), isTrue, reason: s);
      }
    });
    test('saying where a secret is kept is fine', () {
      for (final s in [
        'Password is in the safe',
        'passwords are in 1Password',
        'password manager is Bitwarden, wife knows the master',
        'PIN known only to my husband',
        'passcode written in the blue notebook',
        'Ask the branch to reset the password',
        'Emirates NBD app, face unlock',
        'pinned note on the fridge',
        'Pinnacle Insurance, spinal cover',
      ]) {
        expect(blocks(s), isFalse, reason: s);
      }
    });
    test('a 12-word recovery phrase is blocked, a description of where it is is not', () {
      expect(
        blocks(
          'recovery phrase: abandon ability able about above absent absorb abstract absurd abuse access accident',
          GuardKind.seedPhrase,
        ),
        isTrue,
      );
      expect(
        blocks('Recovery phrase is on a steel plate in the safe at home'),
        isFalse,
      );
    });
  });

  test('an Emirates ID number warns but does not block', () {
    final issues = InputGuard.check('ID 784-1990-1234567-1');
    expect(issues.single.kind, GuardKind.emiratesId);
    expect(issues.single.blocking, isFalse);
    expect(InputGuard.firstProblem(['fine', 'ID 784-1990-1234567-1']), isNull);
  });

  test('firstProblem reports the first blocking message across fields', () {
    final m = InputGuard.firstProblem([
      'Dubai Islamic',
      'pin 1234',
      'AE070331234567890123456',
    ]);
    expect(m, contains('PIN'));
    expect(InputGuard.firstProblem(['', 'Safe at home']), isNull);
  });

  test('luhn', () {
    expect(InputGuard.luhn('4111111111111111'), isTrue);
    expect(InputGuard.luhn('4111111111111112'), isFalse);
  });
}
