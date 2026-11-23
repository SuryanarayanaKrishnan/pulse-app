import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/api/api_exception.dart';
import 'package:pulse/data/api/dto.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/rules.dart';

const _dining = CategoryDto(
  id: 'cat-dining',
  name: 'Dining',
  kind: 'expense',
  slug: 'dining',
);
const _fab = AccountDto(
  id: 'acc-fab',
  type: 'credit_card',
  name: 'Cashback',
  institution: 'FAB',
  last4: '1234',
);

AutomationRule _rule(
  RuleField f,
  RuleOperator op,
  String v, {
  RuleAction action = RuleAction.setCategory,
}) => AutomationRule(
  id: 'r1',
  field: f,
  op: op,
  value: v,
  action: action,
  category: action == RuleAction.setCategory ? SpendCategory.dining : null,
  renameTo: action == RuleAction.rename ? 'Tabby' : null,
);

void main() {
  test('starts-with becomes an escaped, anchored, lower-case regex', () {
    final j = ruleToJson(
      _rule(RuleField.merchant, RuleOperator.startsWith, 'Careem.Food'),
      categoryId: 'cat-dining',
    );
    expect(j['conditions'], [
      {'field': 'merchant', 'op': 'regex', 'value': r'^careem\.food'},
    ]);
    expect(j['category_id'], 'cat-dining');
  });

  test('amount bounds map to inclusive minor units', () {
    final over = ruleToJson(
      _rule(RuleField.amount, RuleOperator.greaterThan, '100', action: RuleAction.exclude),
    );
    expect((over['conditions']! as List).single, {
      'field': 'amount',
      'op': 'gte',
      'value_minor': 10001,
    });
    expect(over['exclude_from_budget'], true);
    final under = ruleToJson(
      _rule(RuleField.amount, RuleOperator.lessThan, '20', action: RuleAction.exclude),
    );
    expect((under['conditions']! as List).single['value_minor'], 1999);
  });

  test('account conditions resolve to an account id or fail clearly', () {
    final j = ruleToJson(
      _rule(RuleField.account, RuleOperator.contains, 'fab'),
      categoryId: 'cat-dining',
      accounts: const [_fab],
    );
    expect((j['conditions']! as List).single, {
      'field': 'account',
      'account_id': 'acc-fab',
    });
    expect(
      () => ruleToJson(
        _rule(RuleField.account, RuleOperator.contains, 'hsbc'),
        categoryId: 'cat-dining',
        accounts: const [_fab],
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('server rules read back into the editor shape', () {
    final r = ruleFromJson(
      {
        'id': 'r9',
        'is_active': false,
        'conditions': [
          {'field': 'merchant', 'op': 'regex', 'value': r'^careem\.food'},
        ],
        'category_id': 'cat-dining',
      },
      categories: const {'cat-dining': _dining},
    )!;
    expect(r.op, RuleOperator.startsWith);
    expect(r.value, 'careem.food');
    expect(r.category, SpendCategory.dining);
    expect(r.enabled, isFalse);

    final amount = ruleFromJson({
      'id': 'r10',
      'conditions': [
        {'field': 'amount', 'op': 'gte', 'value_minor': 10001},
      ],
      'rename_merchant': 'Big spend',
    })!;
    expect(amount.op, RuleOperator.greaterThan);
    expect(amount.value, '100.00');
    expect(amount.action, RuleAction.rename);
  });

  test('rules the editor cannot show are skipped', () {
    expect(
      ruleFromJson({
        'id': 'x',
        'conditions': [
          {'field': 'merchant', 'op': 'regex', 'value': r'(uber|careem)'},
        ],
        'category_id': 'c',
      }),
      isNull,
    );
    expect(
      ruleFromJson({
        'id': 'y',
        'conditions': [
          {'field': 'merchant', 'op': 'contains', 'value': 'x'},
        ],
        'tags': ['a'],
      }),
      isNull,
    );
  });
}
