import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/api/api_pulse_repository.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';

/// A backend that is down, refuses the token or sends rubbish.
class _BadAdapter implements HttpClientAdapter {
  _BadAdapter(this.mode);
  final String mode;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    switch (mode) {
      case 'refused':
        throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      case '401':
        return ResponseBody.fromString('{"detail":"nope"}', 401, headers: {'content-type': ['application/json']});
      case '500':
        return ResponseBody.fromString('boom', 500);
      default:
        return ResponseBody.fromString('{"unexpected": true}', 200, headers: {'content-type': ['application/json']});
    }
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  for (final mode in ['refused', '401', '500', 'garbage']) {
    test('shared features fall back to empty when the backend is $mode', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final db = PulseDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final catalog = CatalogService(db: db, bundled: () async => File('assets/catalog/cards.json').readAsStringSync());
      await catalog.loadBundled();
      final pipeline = IngestPipeline(db);
      addTearDown(pipeline.dispose);
      final dio = Dio(BaseOptions(baseUrl: 'http://backend.invalid'))..httpClientAdapter = _BadAdapter(mode);
      final repo = LocalPulseRepository(db: db, catalog: catalog, pipeline: pipeline, shared: ApiPulseRepository(dio));
      expect(await repo.splitGroups(), isEmpty);
      expect(await repo.statements(), isEmpty);
      expect(await repo.emailConnections(), isEmpty);
      expect(await repo.statementPasswords(), isEmpty);
    });
  }
}
