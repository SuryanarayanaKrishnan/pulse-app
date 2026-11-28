import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/engine/rule_engine.dart';
import 'package:pulse/core/engine/types.dart';
import 'package:pulse/core/learning/global_merchant_map.dart';
import 'package:pulse/core/learning/global_merchant_map_loader.dart';
import 'package:pulse/core/learning/privacy_filter.dart';

GlobalMerchantMap small([int version = 1]) => GlobalMerchantMap(
  version: version,
  entries: const {
    'carrefour': 'groceries',
    'noon': 'shopping',
    'obscure bakery shop': 'dining',
    'zzz unknown cafe': 'dining',
    'abcd': 'dining',
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled asset', () {
    late GlobalMerchantMap map;
    setUpAll(() {
      map = GlobalMerchantMap.parse(
        File('assets/merchant_map.json').readAsStringSync(),
      );
    });

    test('is versioned and has a few hundred entries', () {
      expect(map.version, greaterThanOrEqualTo(1));
      expect(map.length, greaterThanOrEqualTo(300));
    });

    test(
      'every entry is valid in the file itself (nothing silently skipped)',
      () {
        final raw = jsonDecode(
          File('assets/merchant_map.json').readAsStringSync(),
        ) as Map;
        expect((raw['entries'] as Map).length, map.length);
      },
    );

    test('every key passes the privacy filter, so known merchants can be contributed', () {
      final f = MerchantKeyFilter(map);
      final bad = [
        for (final k in map.entries.keys)
          if (!f.accepts(k)) k,
      ];
      expect(bad, isEmpty);
    });

    test(
      'contains no digits runs, emails or numbers (public merchants only)',
      () {
        for (final k in map.entries.keys) {
          expect(RegExp(r'\d{4}').hasMatch(k), isFalse, reason: k);
          expect(k.contains('@'), isFalse, reason: k);
        }
      },
    );

    test('is declared in pubspec and loads through the asset bundle', () async {
      final m = await GlobalMerchantMapLoader().load();
      expect(m.length, map.length);
    });

    test('knows some common merchants', () {
      expect(map.lookup('Carrefour'), 'groceries');
      expect(map.lookup('CARREFOUR MOE DUBAI AE'), 'groceries');
      expect(map.lookup('Salik Recharge'), 'transport');
      expect(map.lookup('Netflix'), 'entertainment');
    });
  });

  group('lookup', () {
    test('exact, case and spacing insensitive', () {
      expect(small().lookup('  CarreFour '), 'groceries');
      expect(small().lookup('Noon'), 'shopping');
    });

    test('whole-word prefix of a longer name, never a partial word', () {
      expect(small().lookup('carrefour city centre'), 'groceries');
      expect(small().lookup('carrefourish'), isNull);
    });

    test('short entries never prefix-match', () {
      expect(small().lookup('abcd restaurant house'), isNull);
      expect(small().lookup('abcd'), 'dining');
    });

    test('miss, null and empty', () {
      expect(small().lookup('unknown thing'), isNull);
      expect(small().lookup(null), isNull);
      expect(small().lookup('   '), isNull);
      expect(GlobalMerchantMap.empty.lookup('carrefour'), isNull);
    });
  });

  group('parsing and merging', () {
    test('rejects files without a version or entries', () {
      expect(() => GlobalMerchantMap.parse('[]'), throwsFormatException);
      expect(
        () => GlobalMerchantMap.parse('{"entries":{}}'),
        throwsFormatException,
      );
      expect(
        () => GlobalMerchantMap.parse('{"version":1}'),
        throwsFormatException,
      );
      expect(
        () => GlobalMerchantMap.parse('{"version":0,"entries":{}}'),
        throwsFormatException,
      );
      expect(() => GlobalMerchantMap.parse('nope'), throwsFormatException);
    });

    test(
      'skips unknown categories, custom, non-normalised keys and non-strings',
      () {
        final m = GlobalMerchantMap.parse(
          jsonEncode({
            'version': 2,
            'entries': {
              'good shop': 'dining',
              'bad cat': 'made_up',
              'custom one': 'custom',
              'Upper Case': 'dining',
              'double  space': 'dining',
              'num': 5,
            },
          }),
        );
        expect(m.entries.keys, ['good shop']);
      },
    );

    test('merge: overlay wins on a clash, version is the higher', () {
      final a = GlobalMerchantMap(
        version: 3,
        entries: const {'a': 'dining', 'b': 'health'},
      );
      final b = GlobalMerchantMap(
        version: 2,
        entries: const {'b': 'travel', 'c': 'fees'},
      );
      final m = GlobalMerchantMap.merge(a, b);
      expect(m.entries, {'a': 'dining', 'b': 'travel', 'c': 'fees'});
      expect(m.version, 3);
    });

    test('newer picks by version and keeps the first on a tie', () {
      final a = small(2);
      final b = small(3);
      expect(GlobalMerchantMap.newer(a, b), same(b));
      expect(GlobalMerchantMap.newer(b, a), same(b));
      final c = small(3);
      expect(GlobalMerchantMap.newer(b, c), same(b));
    });
  });

  group('refresh', () {
    final newer = jsonEncode({
      'version': 99,
      'entries': {'brand new shop': 'dining'},
    });

    test(
      'a newer valid map is stored and then wins over the bundled one',
      () async {
        final kv = MemoryKvStore();
        final loader = GlobalMerchantMapLoader(kv: kv);
        final bundled = await loader.load();
        expect(await loader.offerRefreshed(newer, bundled), isTrue);
        final after = await loader.load();
        expect(after.version, 99);
        expect(after.lookup('brand new shop'), 'dining');
      },
    );

    test('older, equal, invalid and empty maps are refused', () async {
      final kv = MemoryKvStore();
      final loader = GlobalMerchantMapLoader(kv: kv);
      final bundled = await loader.load();
      expect(
        await loader.offerRefreshed(
          jsonEncode({
            'version': bundled.version,
            'entries': {'x y': 'dining'},
          }),
          bundled,
        ),
        isFalse,
      );
      expect(
        await loader.offerRefreshed(
          jsonEncode({'version': 0, 'entries': {}}),
          bundled,
        ),
        isFalse,
      );
      expect(await loader.offerRefreshed('garbage', bundled), isFalse);
      expect(
        await loader.offerRefreshed(
          jsonEncode({'version': 500, 'entries': {}}),
          bundled,
        ),
        isFalse,
      );
      expect(kv.data, isEmpty);
    });

    test('a corrupt stored copy is ignored', () async {
      final kv = MemoryKvStore()
        ..data[GlobalMerchantMapLoader.refreshedKey] = '{{{';
      final m = await GlobalMerchantMapLoader(kv: kv).load();
      expect(m.length, greaterThan(300));
    });

    test('a missing asset gives an empty map, not a crash', () async {
      final m = await GlobalMerchantMapLoader(assetPath: 'assets/nope.json')
          .load();
      expect(m.length, 0);
    });
  });

  group('categoriser precedence: user rules, dictionary, map, nothing', () {
    const system = {'groceries': 'g', 'dining': 'd', 'shopping': 's'};
    final map = GlobalMerchantMap(
      version: 1,
      entries: const {
        'carrefour': 'dining', // deliberately disagrees with the dictionary
        'obscure bakery shop': 'dining',
        'noon': 'shopping',
      },
    );

    test('a user rule beats everything', () {
      final r = CategoryResolver(
        [merchantEqualsRule('obscure bakery shop', 's')],
        system,
        globalMap: map,
      );
      final e = r.enrich('Obscure Bakery Shop', Direction.debit);
      expect((e.categoryId, e.source), ('s', 'rule'));
    });

    test('the built-in dictionary beats the map', () {
      final e = CategoryResolver(
        [],
        system,
        globalMap: map,
      ).enrich('CARREFOUR MOE', Direction.debit);
      expect((e.categoryId, e.source), ('g', 'dictionary'));
    });

    test('the map beats the generic fallback', () {
      final e = CategoryResolver(
        [],
        system,
        globalMap: map,
      ).enrich('Obscure Bakery Shop', Direction.debit);
      expect((e.categoryId, e.source), ('d', 'global_map'));
    });

    test('with no map, or a miss, nothing is assigned', () {
      expect(
        CategoryResolver(
          [],
          system,
        ).enrich('Obscure Bakery Shop', Direction.debit).categoryId,
        isNull,
      );
      expect(
        CategoryResolver(
          [],
          system,
          globalMap: map,
        ).enrich('Totally Unknown Place', Direction.debit).categoryId,
        isNull,
      );
    });

    test('a category the user does not have is skipped', () {
      final e = CategoryResolver([], {
        'groceries': 'g',
      }, globalMap: map).enrich('Obscure Bakery Shop', Direction.debit);
      expect(e.categoryId, isNull);
    });
  });
}
