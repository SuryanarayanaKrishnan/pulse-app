import 'dart:convert';
import 'dart:io';

/// Loads a golden file generated from the Python backend
/// (`tool/gen_engine_fixtures.py`).
Object? loadFixture(String name) =>
    jsonDecode(File('test/fixtures/engine/$name').readAsStringSync());

List<Map<String, Object?>> loadFixtureList(String name) => [
  for (final e in loadFixture(name)! as List)
    Map<String, Object?>.from(e as Map),
];
