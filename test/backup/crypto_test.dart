import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/backup/backup_crypto.dart';
import 'package:pulse/backup/key_envelope.dart';
import 'package:pulse/backup/recovery_phrase.dart';

void main() {
  group('object encryption', () {
    test('round trips and is not deterministic', () async {
      final key = await BackupCrypto.subKey(
        BackupCrypto.randomBytes(32),
        'chunk',
      );
      final plain = utf8.encode('salary AED 25,000');
      final a = await BackupCrypto.seal(key, plain, aad: [1]);
      final b = await BackupCrypto.seal(key, plain, aad: [1]);
      expect(a, isNot(equals(b)), reason: 'fresh nonce each time');
      expect(
        utf8.decode(await BackupCrypto.open(key, a, aad: [1])),
        'salary AED 25,000',
      );
      expect(utf8.decode(a, allowMalformed: true), isNot(contains('salary')));
    });

    test(
      'any flipped bit, truncation or wrong associated data is rejected',
      () async {
        final key = await BackupCrypto.subKey(
          BackupCrypto.randomBytes(32),
          'chunk',
        );
        final blob = await BackupCrypto.seal(
          key,
          utf8.encode('secret'),
          aad: [9],
        );
        for (final i in [0, 1, 5, blob.length ~/ 2, blob.length - 1]) {
          final bad = Uint8List.fromList(blob)..[i] ^= 1;
          await expectLater(
            BackupCrypto.open(key, bad, aad: [9]),
            throwsA(isA<BackupIntegrityError>()),
            reason: 'byte $i',
          );
        }
        await expectLater(
          BackupCrypto.open(key, blob.sublist(0, blob.length - 3), aad: [9]),
          throwsA(isA<BackupIntegrityError>()),
        );
        await expectLater(
          BackupCrypto.open(key, blob, aad: [8]),
          throwsA(isA<BackupIntegrityError>()),
        );
        final other = await BackupCrypto.subKey(
          BackupCrypto.randomBytes(32),
          'chunk',
        );
        await expectLater(
          BackupCrypto.open(other, blob, aad: [9]),
          throwsA(isA<BackupIntegrityError>()),
        );
      },
    );

    test('sub-keys are independent per purpose', () async {
      final dk = BackupCrypto.randomBytes(32);
      final a = await (await BackupCrypto.subKey(dk, 'chunk')).extractBytes();
      final b = await (await BackupCrypto.subKey(
        dk,
        'manifest',
      )).extractBytes();
      expect(a, isNot(equals(b)));
    });
  });

  group('key envelope', () {
    test('passphrase unwraps the data key; a wrong one is rejected', () async {
      final (env, dataKey) = await KeyEnvelope.create(
        'correct horse battery',
        secretKind: 'passphrase',
        kdf: KdfParams.testing,
      );
      expect(await env.unwrap('correct horse battery'), dataKey);
      await expectLater(
        env.unwrap('correct horse batter'),
        throwsA(isA<WrongPassphrase>()),
      );
      await expectLater(env.unwrap(''), throwsA(isA<WrongPassphrase>()));
    });

    test(
      'survives encode/decode and rejects tampered parameters or wrapped key',
      () async {
        final (env, dataKey) = await KeyEnvelope.create(
          'a long passphrase',
          secretKind: 'passphrase',
          kdf: KdfParams.testing,
        );
        final back = KeyEnvelope.decode(env.encode());
        expect(await back.unwrap('a long passphrase'), dataKey);

        final json =
            jsonDecode(utf8.decode(env.encode())) as Map<String, dynamic>;
        // Lowering the KDF cost must not silently still open: parameters are in the AAD.
        (json['kdf'] as Map)['t'] = 2;
        final weaker = KeyEnvelope.decode(
          Uint8List.fromList(utf8.encode(jsonEncode(json))),
        );
        await expectLater(
          weaker.unwrap('a long passphrase'),
          throwsA(isA<WrongPassphrase>()),
        );

        final wrapped = base64
            .decode(
              (jsonDecode(utf8.decode(env.encode())) as Map)['wrapped']
                  as String,
            )
            .toList();
        wrapped[20] ^= 1;
        final j2 =
            jsonDecode(utf8.decode(env.encode())) as Map<String, dynamic>;
        j2['wrapped'] = base64.encode(wrapped);
        final tampered = KeyEnvelope.decode(
          Uint8List.fromList(utf8.encode(jsonEncode(j2))),
        );
        await expectLater(
          tampered.unwrap('a long passphrase'),
          throwsA(isA<WrongPassphrase>()),
        );
      },
    );

    test(
      'rewrap keeps the data key, changes the salt, and retires the old secret',
      () async {
        final (env, dataKey) = await KeyEnvelope.create(
          'old passphrase 1',
          secretKind: 'passphrase',
          kdf: KdfParams.testing,
        );
        final next = await env.rewrap(
          dataKey,
          'new passphrase 2',
          secretKind: 'passphrase',
        );
        expect(next.salt, isNot(equals(env.salt)));
        expect(await next.unwrap('new passphrase 2'), dataKey);
        await expectLater(
          next.unwrap('old passphrase 1'),
          throwsA(isA<WrongPassphrase>()),
        );
      },
    );

    test('hostile KDF settings are refused before any work is done', () {
      expect(
        () => const KdfParams(
          memoryKiB: 4 * 1024 * 1024,
          iterations: 3,
          parallelism: 1,
        ).validate(),
        throwsFormatException,
      );
      expect(
        () => const KdfParams(
          memoryKiB: 1024,
          iterations: 0,
          parallelism: 1,
        ).validate(),
        throwsFormatException,
      );
    });
  });

  group('recovery phrase', () {
    test('generates 12 valid words, unique each time', () {
      final a = RecoveryPhrase.generate();
      final b = RecoveryPhrase.generate();
      expect(a, hasLength(12));
      expect(a.join(' '), isNot(b.join(' ')));
      expect(RecoveryPhrase.isValid(a.join(' ')), isTrue);
    });

    test('typos are caught and case or spacing does not matter', () {
      final words = RecoveryPhrase.generate();
      final phrase = words.join(' ');
      expect(
        RecoveryPhrase.secretFrom(
          '  ${phrase.toUpperCase().replaceAll(' ', '   ')} ',
        ),
        phrase,
      );
      final wrong = [...words]
        ..[0] = words[0] == 'abandon' ? 'ability' : 'abandon';
      expect(
        RecoveryPhrase.isValid(wrong.join(' ')) && wrong.join(' ') == phrase,
        isFalse,
      );
      expect(
        RecoveryPhrase.isValid('not a real recovery phrase at all'),
        isFalse,
      );
    });

    test('passphrase strength gate', () {
      expect(passphraseStrength('short'), PassphraseStrength.tooShort);
      expect(passphraseStrength('abcdefghijk'), PassphraseStrength.fair);
      expect(
        passphraseStrength('four small words here'),
        PassphraseStrength.good,
      );
    });
  });
}
