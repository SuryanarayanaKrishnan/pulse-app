import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/dedupe.dart';
import 'package:pulse/core/engine/fuzzy.dart';
import 'package:pulse/core/engine/types.dart';

import 'fixtures.dart';

DateTime at(int d, [int h = 9]) => DateTime.utc(2026, 3, d, h);
StoredTxn stored(String id, {int day = 12, int hour = 9, int amount = 4500, String merchant = 'Carrefour', List<String> sources = const ['sms'], TxnSource source = TxnSource.sms, String account = 'a', bool claimed = false}) => StoredTxn(
  id: id, accountId: account, amountMinor: amount, currency: 'AED', direction: Direction.debit,
  postedAt: at(day, hour), source: source, sources: sources, merchantNormalized: merchant, merchantRaw: merchant, claimedByMessage: claimed,
);

void main() {
  group('Python parity', () {
    final fx = loadFixture('dedupe.json')! as Map;
    test('merchant similarity scores', () {
      for (final s in fx['scores'] as List) {
        final m = Map<String, Object?>.from(s as Map);
        expect(merchantScore(m['a'] as String?, m['b'] as String?), m['score'], reason: '${m['a']} ~ ${m['b']}');
      }
    });
    for (final c in fx['matches'] as List) {
      final m = Map<String, Object?>.from(c as Map);
      test('statement matching: ${m['name']}', () {
        final lines = [
          for (final l in m['lines']! as List)
            () {
              final x = Map<String, Object?>.from(l as Map);
              return StatementLine(
                postedOn: CalDate.parse(x['posted_on']! as String),
                description: x['description']! as String,
                amountMinor: x['amount_minor']! as int,
                currency: x['currency']! as String,
                direction: Direction.tryParse(x['direction'] as String?)!,
                foreignAmountMinor: x['foreign_amount_minor'] as int?,
                foreignCurrency: x['foreign_currency'] as String?,
              );
            }(),
        ];
        final txns = [
          for (final t in m['txns']! as List)
            () {
              final x = Map<String, Object?>.from(t as Map);
              return TxnLike(
                postedAt: DateTime.parse(x['posted_at']! as String),
                amountMinor: x['amount_minor']! as int,
                currency: x['currency']! as String,
                direction: Direction.tryParse(x['direction'] as String?)!,
                merchantRaw: x['merchant_raw'] as String?,
                merchantNormalized: x['merchant_normalized'] as String?,
              );
            }(),
        ];
        final got = matchLines(lines, txns);
        final exp = m['matches']! as List;
        expect(got.length, exp.length);
        for (var i = 0; i < got.length; i++) {
          final e = exp[i] as Map;
          expect((got[i].lineIndex, got[i].txnIndex, got[i].score), (e['line'], e['txn'], e['score']));
        }
      });
    }
  });

  group('fuzzy scores', () {
    test('ratio, partial and token set behave like rapidfuzz', () {
      expect(ratio('abc', 'abc'), 100);
      expect(ratio('', ''), 100);
      expect(partialRatio('carrefour', 'maf carrefour hypermarket'), 100);
      expect(tokenSetRatio('pizza palace', 'palace pizza dubai'), 100);
      expect(tokenSetRatio('', 'x'), 0);
      expect(partialRatio('', 'x'), 0);
    });
  });

  group('capture dedupe', () {
    test('same purchase from another channel within an hour merges', () {
      final dup = findCaptureDuplicate(
        [stored('1', hour: 9)],
        accountId: 'a', channel: TxnSource.appleShortcut, amountMinor: 4500, currency: 'AED',
        direction: Direction.debit, merchant: 'CARREFOUR MOE', postedAt: at(12, 9).add(const Duration(minutes: 20)),
      );
      expect(dup?.id, '1');
    });
    test('same channel twice stays two purchases', () {
      expect(
        findCaptureDuplicate([stored('1')],
            accountId: 'a', channel: TxnSource.sms, amountMinor: 4500, currency: 'AED',
            direction: Direction.debit, merchant: 'Carrefour', postedAt: at(12, 9)),
        isNull,
      );
    });
    test('different merchant, amount, account or time does not merge', () {
      StoredTxn? f({String merchant = 'CARREFOUR', int amount = 4500, String account = 'a', int hour = 9}) =>
          findCaptureDuplicate([stored('1')],
              accountId: account, channel: TxnSource.appleShortcut, amountMinor: amount, currency: 'AED',
              direction: Direction.debit, merchant: merchant, postedAt: at(12, hour));
      expect(f(), isNotNull);
      expect(f(merchant: 'STARBUCKS COFFEE'), isNull);
      expect(f(amount: 4501), isNull);
      expect(f(account: 'b'), isNull);
      expect(f(hour: 11), isNull);
    });
    test('a tap without a merchant still merges (merchant unknown)', () {
      expect(
        findCaptureDuplicate([stored('1')],
            accountId: 'a', channel: TxnSource.appleShortcut, amountMinor: 4500, currency: 'AED',
            direction: Direction.debit, merchant: null, postedAt: at(12, 9))?.id,
        '1',
      );
    });
  });

  group('statement dedupe (+-3 days)', () {
    StoredTxn st(String id, {int day = 12, bool claimed = false}) => stored(id, day: day, source: TxnSource.statement, sources: const ['statement'], claimed: claimed);
    StoredTxn? find(List<StoredTxn> s, {String? merchant = 'CARREFOUR MOE', DateTime? when}) =>
        findStatementTransaction(s, accountId: 'a', amountMinor: 4500, currency: 'AED', direction: Direction.debit, merchant: merchant, postedAt: when ?? at(14));
    test('links a late SMS to the statement row within three days', () {
      expect(find([st('s')])?.id, 's');
      expect(find([st('s', day: 8)]), isNull); // 6 days apart
      expect(find([st('s', day: 17)])?.id, 's'); // 3 days apart
      expect(find([st('s', day: 18)]), isNull);
    });
    test('skips rows another message already claimed and picks the best merchant', () {
      expect(find([st('s', claimed: true)]), isNull);
      final other = StoredTxn(id: 'o', accountId: 'a', amountMinor: 4500, currency: 'AED', direction: Direction.debit,
          postedAt: at(12), source: TxnSource.statement, merchantNormalized: 'Starbucks');
      expect(find([other, st('s')])?.id, 's');
    });
  });

  group('external hash', () {
    test('client id wins, content hash separates different times', () {
      final a = computeExternalHash(TxnSource.sms, externalId: 'x1', rawText: 'hello');
      final b = computeExternalHash(TxnSource.sms, externalId: 'x1', rawText: 'other');
      expect(a, b);
      final c = computeExternalHash(TxnSource.sms, rawText: 'Hello  World', sender: 'ENBD', receivedAt: at(1));
      final d = computeExternalHash(TxnSource.sms, rawText: 'hello world', sender: 'ENBD', receivedAt: at(1));
      final e = computeExternalHash(TxnSource.sms, rawText: 'hello world', sender: 'ENBD', receivedAt: at(2));
      expect(c, d);
      expect(d, isNot(e));
      expect(computeExternalHash(TxnSource.notification, externalId: 'x1'), isNot(a));
    });
  });
}
