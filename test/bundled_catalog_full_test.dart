import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/catalog.dart';

void main() {
  test('bundled catalog is the full catalog, not a sample', () {
    final json = jsonDecode(
      File('assets/catalog/cards.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final catalog = CardCatalog.fromJson(json);
    expect(catalog.cards.length, greaterThanOrEqualTo(190));
    expect(catalog.cards.any((c) => c.id.contains('noon')), isTrue);
  });
}
