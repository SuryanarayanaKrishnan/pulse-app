import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/phone.dart';
import 'package:pulse/features/splits/contacts.dart';

void main() {
  test('UAE numbers normalise to E.164', () {
    for (final raw in [
      '050 123 4567',
      '+971 50 123 4567',
      '00971501234567',
      '971501234567',
      '501234567',
      '(050) 123-4567',
    ]) {
      expect(toE164(raw), '+971501234567', reason: raw);
    }
    expect(toE164('+44 7700 900123'), '+447700900123');
    expect(toE164(''), isNull);
    expect(toE164('12345'), isNull);
    expect(toE164('+0123456789'), isNull);
  });

  test('hash is SHA-256 hex of the E.164 string', () {
    expect(phoneHash('+971501234567'), hashPhone('050 123 4567'));
    expect(phoneHash('+971501234567'), hasLength(64));
    expect(
      phoneHash(''),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(hashPhone('nope'), isNull);
  });

  test('formatting', () {
    expect(formatPhone('+971501234567'), '+971 50 123 4567');
    expect(formatPhone('+447700900123'), '+447700900123');
  });

  test('contacts are normalised, de-duplicated and sorted', () {
    final list = toDeviceContacts([
      ('zed', ['0501234567', '+971501234567']),
      ('Amy', ['bad']),
      ('', ['0509999999']),
      ('bob', ['+44 7700 900123']),
    ]);
    expect([for (final c in list) c.name], ['bob', 'zed']);
    expect(list.last.phones, ['+971501234567']);
  });
}
