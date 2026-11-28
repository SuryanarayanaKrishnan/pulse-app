import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/dedupe.dart';
import 'package:pulse/core/engine/superapps.dart';

void main() {
  test('families are recognised through bank noise', () {
    expect(superAppFor('NOON.COM DUBAI AE')?.key, 'noon');
    expect(superAppFor('CAREEM  *RIDE 1234')?.key, 'careem');
    expect(superAppFor('AMZN MKTP AE')?.key, 'amazon');
    expect(superAppFor('Carrefour'), isNull);
    expect(superAppFor('Noonan Bakery'), isNull);
  });

  test('a named sub-service settles the category, a bare name does not', () {
    expect(hintFrom('NOON FOOD DUBAI')?.category, 'dining');
    expect(hintFrom('Noon Minutes')?.category, 'groceries');
    expect(hintFrom('CAREEM QUIK')?.category, 'groceries');
    expect(hintFrom('CAREEM')?.category, isNull);
    expect(isAmbiguous('CAREEM'), isTrue);
    expect(isAmbiguous('CAREEM FOOD'), isFalse);
    expect(isAmbiguous('Spinneys'), isFalse);
  });

  test('brand variants are one merchant when matching channels', () {
    expect(sameFamily('NOON.COM', 'Noon Food'), isTrue);
    expect(sameFamily('NOON.COM', 'CAREEM'), isFalse);
    expect(merchantScore('NOON.COM', 'Noon Food'), 100);
  });

  test('chips lead with the learned choice, at most three', () {
    expect(chipsFor('NOON.COM'), ['shopping', 'groceries', 'dining']);
    expect(chipsFor('NOON.COM', ranked: ['dining']), [
      'dining',
      'shopping',
      'groceries',
    ]);
    expect(chipsFor('Carrefour'), isEmpty);
  });

  test(
    'a second source upgrades an unconfirmed row, never a confirmed one',
    () {
      final up = mergeUpgrade(
        existingMerchant: 'Noon',
        incomingMerchant: 'Noon Food',
        existingReviewed: false,
      );
      expect(up.merchantName, 'Noon Food');
      expect(up.categorySlug, 'dining');
      expect(
        mergeUpgrade(
          existingMerchant: 'Noon',
          incomingMerchant: 'Noon Food',
          existingReviewed: true,
        ).isEmpty,
        isTrue,
      );
      expect(
        mergeUpgrade(
          existingMerchant: 'Noon Food',
          incomingMerchant: 'Noon Minutes',
          existingReviewed: false,
        ).isEmpty,
        isTrue,
      );
    },
  );
}
