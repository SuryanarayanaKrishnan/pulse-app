import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/api/api_exception.dart';
import 'package:pulse/data/api/api_pulse_repository.dart';
import 'package:pulse/data/models.dart';

import 'support/fake_adapter.dart';

Map<String, Object?> _tx(String id, String at, {String? cat}) => {
  'id': id,
  'user_id': 'u',
  'account_id': 'a1',
  'category_id': cat,
  'amount_minor': 1000,
  'currency': 'AED',
  'direction': 'debit',
  'merchant_raw': 'M$id',
  'merchant_normalized': null,
  'posted_at': at,
  'source': 'notification',
};

final _accounts = [
  {
    'id': 'a1',
    'type': 'credit_card',
    'name': 'Card',
    'institution': 'Mashreq',
    'last4': '1111',
    'currency': 'AED',
    'credit_limit_minor': 1000000,
    'due_day': 15,
  },
];
final _cats = [
  {'id': 'c1', 'name': 'Groceries', 'kind': 'expense'},
  {'id': 'c2', 'name': 'Dining', 'kind': 'expense'},
];

void main() {
  test('transactions() follows next_cursor across pages', () {
    final adapter = FakeAdapter({
      'GET /v1/accounts': _accounts,
      'GET /v1/categories': _cats,
      'GET /v1/transactions': (o) {
        final cursor = o.queryParameters['cursor'];
        return cursor == null
            ? {
                'items': [
                  _tx('1', '2026-11-03T00:00:00Z'),
                  _tx('2', '2026-11-02T00:00:00Z'),
                ],
                'next_cursor': 'p2',
              }
            : {
                'items': [_tx('3', '2026-11-01T00:00:00Z')],
                'next_cursor': null,
              };
      },
    });
    final repo = ApiPulseRepository(fakeDio(adapter));
    return repo.transactions().then((list) {
      expect(list.map((t) => t.id), ['1', '2', '3']);
      expect(list.first.accountLabel, 'Mashreq ••1111');
      final tx = adapter.requests
          .where((r) => r.path == '/v1/transactions')
          .toList();
      expect(tx, hasLength(2));
      expect(tx[0].queryParameters['cursor'], isNull);
      expect(tx[1].queryParameters['cursor'], 'p2');
      expect(tx[0].queryParameters['limit'], 200);
    });
  });

  test('transactionsPage exposes the cursor', () async {
    final adapter = FakeAdapter({
      'GET /v1/accounts': _accounts,
      'GET /v1/categories': _cats,
      'GET /v1/transactions': {
        'items': [_tx('1', '2026-11-03T00:00:00Z', cat: 'c2')],
        'next_cursor': 'next',
      },
    });
    final page = await ApiPulseRepository(fakeDio(adapter))
        .transactionsPage(limit: 1);
    expect(page.hasMore, isTrue);
    expect(page.nextCursor, 'next');
    expect(page.items.single.category, SpendCategory.dining);
  });

  test('recategorise PATCHes the matching backend category', () async {
    final adapter = FakeAdapter({
      'GET /v1/accounts': _accounts,
      'GET /v1/categories': _cats,
      'PATCH /v1/transactions/1': _tx('1', '2026-11-03T00:00:00Z', cat: 'c1'),
    });
    final tx = await ApiPulseRepository(fakeDio(adapter))
        .recategorise('1', SpendCategory.groceries);
    expect(tx.category, SpendCategory.groceries);
    final patch = adapter.requests.firstWhere((r) => r.method == 'PATCH');
    expect(patch.data, {'category_id': 'c1', 'remember_merchant': false});
  });

  test('server errors surface as ApiException with the envelope', () async {
    final adapter = FakeAdapter({
      'GET /v1/net-worth': (
        500,
        {
          'error': {'code': 'internal_error', 'message': 'boom', 'details': []},
        },
      ),
    });
    await expectLater(
      ApiPulseRepository(fakeDio(adapter)).netWorth(),
      throwsA(
        isA<ApiException>()
            .having((e) => e.isRetryable, 'retryable', true)
            .having((e) => e.code, 'code', 'internal_error'),
      ),
    );
  });

  test('myCards derives cards from credit-card accounts', () async {
    final adapter = FakeAdapter({
      'GET /v1/accounts': [
        ..._accounts,
        {'id': 'a2', 'type': 'bank', 'name': 'Current'},
      ],
      'GET /v1/liabilities': [
        {
          'id': 'l1',
          'kind': 'credit_card',
          'name': 'Card',
          'outstanding_minor': 250000,
          'account_id': 'a1',
        },
      ],
    });
    final cards = await ApiPulseRepository(
      fakeDio(adapter),
      clock: () => DateTime(2026, 11, 20),
    ).myCards();
    expect(cards, hasLength(1));
    expect(cards.single.limit, 10000);
    expect(cards.single.balance, 2500);
    expect(cards.single.dueDate, DateTime(2026, 12, 15));
  });

  test('addSplitExpense resolves "me" to the member id', () async {
    final adapter = FakeAdapter({
      'GET /v1/me': {'id': 'u1'},
      'GET /v1/splits/groups/g': {
        'id': 'g',
        'name': 'Trip',
        'currency': 'AED',
        'members': [
          {'id': 'm1', 'user_id': 'u1', 'display_name': 'Sara'},
          {'id': 'm2', 'user_id': null, 'display_name': 'Omar'},
        ],
      },
      'POST /v1/splits/groups/g/expenses': (
        201,
        {
          'id': 'e1',
          'description': 'Dinner',
          'amount_minor': 9000,
          'paid_by_member_id': 'm1',
          'spent_at': '2026-11-20T10:00:00Z',
          'shares': [
            {'member_id': 'm1', 'share_minor': 4500},
            {'member_id': 'm2', 'share_minor': 4500},
          ],
        },
      ),
    });
    final e = await ApiPulseRepository(fakeDio(adapter)).addSplitExpense(
      'g',
      SplitExpense(
        id: 'x',
        title: 'Dinner',
        paidBy: 'me',
        amount: 90,
        participants: const ['me', 'm2'],
        date: DateTime.utc(2026, 11, 20, 10),
      ),
    );
    final post = adapter.requests.firstWhere((r) => r.method == 'POST');
    final body = post.data as Map;
    expect(body['paid_by_member_id'], 'm1');
    expect(body['amount_minor'], 9000);
    expect(body['split_type'], 'equal');
    expect((body['participants'] as List).map((p) => (p as Map)['member_id']), [
      'm1',
      'm2',
    ]);
    expect(e.paidBy, 'me');
  });
}
