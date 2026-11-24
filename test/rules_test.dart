import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/rules.dart';

Transaction _tx({
  String merchant = 'Talabat',
  double amount = 86,
  String account = 'FAB Cashback',
  String? raw,
  SpendCategory category = SpendCategory.other,
}) => Transaction(
  id: 't',
  merchant: merchant,
  amount: amount,
  category: category,
  date: DateTime(2026, 11, 20),
  source: TxSource.sms,
  cardId: 'c',
  accountLabel: account,
  rawDescription: raw,
);

AutomationRule _rule(
  RuleField f,
  RuleOperator op,
  String v,
  RuleAction a, {
  SpendCategory? cat,
  String? rename,
}) => AutomationRule(
  id: 'r',
  field: f,
  op: op,
  value: v,
  action: a,
  category: cat,
  renameTo: rename,
);

void main() {
  test('text matching is case and whitespace insensitive', () {
    final r = _rule(
      RuleField.merchant,
      RuleOperator.contains,
      ' talabat ',
      RuleAction.setCategory,
      cat: SpendCategory.dining,
    );
    expect(r.matches(_tx(merchant: 'TALABAT  UAE')), isTrue);
    expect(r.matches(_tx(merchant: 'Deliveroo')), isFalse);
    final eq = _rule(
      RuleField.merchant,
      RuleOperator.equals,
      'talabat',
      RuleAction.setCategory,
      cat: SpendCategory.dining,
    );
    expect(eq.matches(_tx(merchant: 'Talabat Mart')), isFalse);
  });

  test('amount operators', () {
    final over = _rule(
      RuleField.amount,
      RuleOperator.greaterThan,
      '100',
      RuleAction.exclude,
    );
    expect(over.matches(_tx(amount: 100.5)), isTrue);
    expect(over.matches(_tx(amount: 99)), isFalse);
    final eq = _rule(
      RuleField.amount,
      RuleOperator.equals,
      '86',
      RuleAction.exclude,
    );
    expect(eq.matches(_tx(amount: 86.001)), isTrue);
  });

  test('description falls back to merchant; account matching', () {
    final d = _rule(
      RuleField.description,
      RuleOperator.startsWith,
      'transfer to',
      RuleAction.exclude,
    );
    expect(d.matches(_tx(raw: 'Transfer to Liv Savings')), isTrue);
    expect(d.matches(_tx()), isFalse);
    final a = _rule(
      RuleField.account,
      RuleOperator.contains,
      'fab',
      RuleAction.exclude,
    );
    expect(a.matches(_tx()), isTrue);
  });

  test('invalid rules never match', () {
    expect(
      _rule(
        RuleField.merchant,
        RuleOperator.contains,
        'x',
        RuleAction.setCategory,
      ).isValid,
      isFalse,
    );
    expect(
      _rule(
        RuleField.amount,
        RuleOperator.contains,
        '1',
        RuleAction.exclude,
      ).isValid,
      isFalse,
    );
    expect(
      _rule(
        RuleField.amount,
        RuleOperator.lessThan,
        'abc',
        RuleAction.exclude,
      ).matches(_tx()),
      isFalse,
    );
  });

  test('applyRules: category, rename, exclude; later rules win', () {
    final out = applyRules(_tx(merchant: 'Tabby · Namshi', amount: 215), [
      _rule(
        RuleField.merchant,
        RuleOperator.contains,
        'namshi',
        RuleAction.setCategory,
        cat: SpendCategory.shopping,
      ),
      _rule(
        RuleField.merchant,
        RuleOperator.startsWith,
        'tabby',
        RuleAction.rename,
        rename: 'Namshi',
      ),
      _rule(
        RuleField.amount,
        RuleOperator.greaterThan,
        '200',
        RuleAction.setCategory,
        cat: SpendCategory.fees,
      ),
    ]);
    expect(out.merchant, 'Namshi');
    expect(out.category, SpendCategory.fees);
    expect(out.excluded, isFalse);
    final ex = applyRules(_tx(), [
      _rule(
        RuleField.merchant,
        RuleOperator.equals,
        'talabat',
        RuleAction.exclude,
      ),
    ]);
    expect(ex.excluded, isTrue);
  });

  test('merchant suggestion and redundancy check', () {
    final s = suggestMerchantRule(_tx(), SpendCategory.dining);
    expect(s.isMerchantCategoryRule, isTrue);
    expect(s.condition, 'Merchant is "Talabat"');
    expect(s.outcome, 'Categorise as Dining & Delivery');
    expect(
      hasMerchantRule([s.copyWith(id: '1')], 'talabat', SpendCategory.dining),
      isTrue,
    );
    expect(
      hasMerchantRule(
        [s.copyWith(id: '1')],
        'Talabat',
        SpendCategory.groceries,
      ),
      isFalse,
    );
    expect(
      hasMerchantRule(
        [s.copyWith(id: '1', enabled: false)],
        'Talabat',
        SpendCategory.dining,
      ),
      isFalse,
    );
  });

  test('category defaults: 20, unique ids, equality by id', () {
    expect(SpendCategory.defaults, hasLength(20));
    expect({for (final c in SpendCategory.defaults) c.id}, hasLength(20));
    expect(
      const SpendCategory.custom('groceries', 'Food'),
      SpendCategory.groceries,
    );
    expect(SpendCategory.byId('cc_payment')!.isTransfer, isTrue);
    expect(SpendCategory.salary.isIncome, isTrue);
  });
}
