import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/api/api_exception.dart';
import 'package:pulse/data/api/dto.dart';
import 'package:pulse/data/models.dart';
import 'package:dio/dio.dart';

Map<String, Object?> tx({
  String direction = 'debit',
  String? categoryId,
  String source = 'sms',
  String? normalized = 'Carrefour',
  int amount = 12345,
}) => {
  'id': 't1',
  'user_id': 'u',
  'account_id': 'a1',
  'statement_id': null,
  'category_id': categoryId,
  'amount_minor': amount,
  'currency': 'AED',
  'direction': direction,
  'merchant_raw': 'CARREFOUR MOE DUBAI',
  'merchant_normalized': normalized,
  'notes': null,
  'posted_at': '2026-11-20T10:30:00Z',
  'source': source,
  'created_at': '2026-11-20T10:31:00Z',
  'updated_at': '2026-11-20T10:31:00Z',
};

void main() {
  group('money', () {
    test('fils to AED and back', () {
      expect(fromMinor(12345), 123.45);
      expect(toMinor(123.45), 12345);
      expect(toMinor(0.1 + 0.2), 30);
    });
  });

  group('transaction mapping', () {
    final accounts = {
      'a1': AccountDto.fromJson({
        'id': 'a1',
        'type': 'credit_card',
        'name': 'Skywards',
        'institution': 'Emirates NBD',
        'last4': '4821',
      }),
    };
    final cats = {
      'c1': CategoryDto.fromJson({
        'id': 'c1',
        'name': 'Groceries',
        'kind': 'expense',
      }),
      'c2': CategoryDto.fromJson({
        'id': 'c2',
        'name': 'Salary',
        'kind': 'income',
      }),
    };

    test('debit with category and account label', () {
      final t = TransactionDto.fromJson(tx(categoryId: 'c1'))
          .toDomain(accounts: accounts, categories: cats);
      expect(t.amount, 123.45);
      expect(t.isIncome, isFalse);
      expect(t.signed, -123.45);
      expect(t.merchant, 'Carrefour');
      expect(t.category, SpendCategory.groceries);
      expect(t.source, TxSource.sms);
      expect(t.accountLabel, 'Emirates NBD ••4821');
      expect(t.cardId, 'a1');
      expect(
        t.date.isAtSameMomentAs(DateTime.utc(2026, 11, 20, 10, 30)),
        isTrue,
      );
    });

    test('credit maps to income; uncategorised debit maps to other', () {
      final credit = TransactionDto.fromJson(
        tx(direction: 'credit', categoryId: 'c2'),
      ).toDomain(accounts: accounts, categories: cats);
      expect(credit.isIncome, isTrue);
      expect(credit.category, SpendCategory.income);
      final none = TransactionDto.fromJson(tx()).toDomain();
      expect(none.category, SpendCategory.other);
      expect(none.accountLabel, 'Account');
    });

    test('merchant falls back to raw then placeholder', () {
      expect(
        TransactionDto.fromJson(tx(normalized: null)).toDomain().merchant,
        'CARREFOUR MOE DUBAI',
      );
      final j = tx(normalized: null)..['merchant_raw'] = null;
      expect(
        TransactionDto.fromJson(j).toDomain().merchant,
        'Unknown merchant',
      );
    });

    test('source mapping', () {
      TxSource of(String s) =>
          TransactionDto.fromJson(tx(source: s)).toDomain().source;
      expect(of('statement'), TxSource.statement);
      expect(of('notification'), TxSource.walletNotification);
      expect(of('apple_shortcut'), TxSource.applePayShortcut);
      expect(of('manual'), TxSource.manual);
    });
  });

  test('category name mapping', () {
    expect(spendCategoryFor('Dining'), SpendCategory.dining);
    expect(spendCategoryFor('Bills & Utilities'), SpendCategory.bills);
    expect(spendCategoryFor('Rent'), SpendCategory.rent);
    expect(
      spendCategoryFor('Transfers', kind: 'transfer'),
      SpendCategory.other,
    );
    expect(spendCategoryFor('Anything', kind: 'income'), SpendCategory.income);
  });

  test('page dto', () {
    final p = PageDto.fromJson({
      'items': [tx()],
      'next_cursor': 'abc',
    }, TransactionDto.fromJson);
    expect(p.items.single.id, 't1');
    expect(p.nextCursor, 'abc');
    expect(
      PageDto.fromJson({
        'items': [],
        'next_cursor': null,
      }, TransactionDto.fromJson).nextCursor,
      isNull,
    );
  });

  test('assets, liabilities and net worth', () {
    final a = AssetDto.fromJson({
      'id': '1',
      'kind': 'fd',
      'name': 'FD',
      'manual_value_minor': 5000000,
    }).toDomain();
    expect(a.kind, AssetKind.fixedDeposit);
    expect(a.value, 50000);
    expect(
      AssetDto.fromJson({
        'id': '2',
        'kind': 'vehicle',
        'name': 'Car',
        'cost_basis_minor': 100,
      }).toDomain().kind,
      AssetKind.other,
    );
    final l = LiabilityDto.fromJson({
      'id': '3',
      'kind': 'auto_loan',
      'name': 'Loan',
      'outstanding_minor': 250000,
    }).toDomain();
    expect(l.isLiability, isTrue);
    expect(l.value, 2500);
    final nw = NetWorthDto.fromJson({
      'base_currency': 'AED',
      'total_assets_minor': 100,
      'total_liabilities_minor': 40,
      'net_worth_minor': 60,
      'assets_by_kind': {},
      'liabilities_by_kind': {},
      'unconverted_currencies': ['USD'],
    });
    expect(nw.unconverted, ['USD']);
    expect(nw.toDomain().total, 0.6);
  });

  test('split group maps the signed-in user to "me"', () {
    final g = SplitGroupDto.fromJson({
      'id': 'g',
      'name': 'Trip',
      'currency': 'AED',
      'members': [
        {'id': 'm1', 'user_id': 'u1', 'display_name': 'Sara'},
        {'id': 'm2', 'user_id': null, 'display_name': 'Omar'},
      ],
    });
    final e = SplitExpenseDto.fromJson({
      'id': 'e',
      'description': 'Dinner',
      'amount_minor': 10000,
      'paid_by_member_id': 'm1',
      'spent_at': '2026-11-01T18:00:00Z',
      'shares': [
        {'member_id': 'm1', 'share_minor': 5000},
        {'member_id': 'm2', 'share_minor': 5000},
      ],
    });
    final d = splitGroupToDomain(g, [e], myUserId: 'u1');
    expect(d.members.map((m) => m.id), ['me', 'm2']);
    expect(d.expenses.single.paidBy, 'me');
    expect(d.expenses.single.amount, 100);
    expect(d.expenses.single.shares, {'me': 50.0, 'm2': 50.0});
    expect(d.total, 100);
  });

  group('ingest request', () {
    test('serialises and truncates to server limits', () {
      final json = IngestRequestDto(
        rawText: 'x' * 6000,
        sender: 'ADCBAlert',
        receivedAt: DateTime.utc(2026, 11, 20, 8),
        externalId: 'sms:abc',
        title: 't' * 400,
        appName: 'com.example',
        fields: const IngestFieldsDto(
          amountMinor: 4550,
          merchant: 'Cafe',
          last4: '12a4',
        ),
      ).toJson();
      expect((json['raw_text']! as String).length, 5000);
      expect((json['title']! as String).length, 300);
      expect(json['received_at'], '2026-11-20T08:00:00.000Z');
      final f = json['fields']! as Map;
      expect(f['amount_minor'], 4550);
      expect(f['currency'], 'AED');
      expect(f['direction'], 'debit');
      expect(
        f.containsKey('last4'),
        isFalse,
        reason: 'invalid last4 is dropped',
      );
    });

    test('omits null fields', () {
      expect(const IngestRequestDto(rawText: 'hi').toJson(), {
        'raw_text': 'hi',
      });
    });

    test('result', () {
      final r = IngestResultDto.fromJson({
        'id': 'i',
        'duplicate': true,
        'parse_status': 'parsed',
      });
      expect(r.duplicate, isTrue);
      expect(r.parseStatus, 'parsed');
    });
  });

  group('ApiException', () {
    DioException dioErr(int status, Object? data) {
      final req = RequestOptions(path: '/x');
      return DioException(
        requestOptions: req,
        response: Response(requestOptions: req, statusCode: status, data: data),
        type: DioExceptionType.badResponse,
      );
    }

    test('parses the error envelope', () {
      final e = ApiException.fromDio(
        dioErr(422, {
          'error': {
            'code': 'validation_error',
            'message': 'bad',
            'details': [1],
            'request_id': 'r1',
          },
        }),
      );
      expect(e.code, 'validation_error');
      expect(e.message, 'bad');
      expect(e.requestId, 'r1');
      expect(e.isPermanent, isTrue);
      expect(e.isRetryable, isFalse);
    });

    test('retry classification', () {
      expect(ApiException.fromDio(dioErr(503, 'oops')).isRetryable, isTrue);
      expect(ApiException.fromDio(dioErr(429, null)).isRetryable, isTrue);
      expect(ApiException.fromDio(dioErr(401, null)).isUnauthorized, isTrue);
      expect(ApiException.fromDio(dioErr(401, null)).isPermanent, isFalse);
      final net = ApiException.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(net.isNetwork, isTrue);
      expect(net.isRetryable, isTrue);
    });
  });
}
