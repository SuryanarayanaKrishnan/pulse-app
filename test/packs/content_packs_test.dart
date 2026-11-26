import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/packs/content_packs.dart';
import 'package:pulse/core/remote_config/remote_config.dart';

/// Answers every request from a map of path -> JSON body.
class _Fake implements HttpClientAdapter {
  _Fake(this.routes);
  final Map<String, Object> routes;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    final body = routes[o.path];
    if (body == null) return ResponseBody.fromString('{}', 404);
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> env(Map<String, Object?> p) => {'payload': p, 'signature': null};

void main() {
  late KvStore kv;
  late RemoteConfigService cfg;
  ContentPackService svc(Map<String, Object> routes, {String? bundledTips}) => ContentPackService(
    kv: kv,
    config: cfg,
    dio: Dio()..httpClientAdapter = _Fake(routes),
    bundled: (n) async => n == 'tips' ? bundledTips : null,
  );

  setUp(() {
    kv = MemoryKvStore();
    cfg = RemoteConfigService(kv: kv, bundled: () async => '{"version":1}', randomId: () => 'x');
  });

  test('bundled pack is used offline', () async {
    final s = ContentPackService(kv: kv, config: cfg, bundled: (n) async => '{"version":1,"items":[]}');
    await s.load(['tips']);
    expect(s.pack('tips')!['version'], 1);
    expect(s.pack('missing'), isNull);
  });

  test('newer download replaces bundled and is cached for next start', () async {
    final routes = <String, Object>{
      '/v1/packs': env({'packs': {'tips': {'version': 2}}}),
      '/v1/packs/tips': env({'version': 2, 'items': ['new']}),
    };
    final s = svc(routes, bundledTips: '{"version":1,"items":[]}');
    await s.load(['tips']);
    expect(await s.refresh(), ['tips']);
    expect(s.pack('tips')!['items'], ['new']);

    final next = ContentPackService(kv: kv, config: cfg, bundled: (n) async => '{"version":1,"items":[]}');
    await next.load(['tips']);
    expect(next.pack('tips')!['version'], 2);
  });

  test('older or equal server version changes nothing', () async {
    final routes = <String, Object>{
      '/v1/packs': env({'packs': {'tips': {'version': 1}}}),
    };
    final s = svc(routes, bundledTips: '{"version":1,"items":[]}');
    await s.load(['tips']);
    expect(await s.refresh(), isEmpty);
  });

  test('a failing server leaves the pack alone', () async {
    final s = svc({}, bundledTips: '{"version":1,"items":[]}');
    await s.load(['tips']);
    expect(await s.refresh(), isEmpty);
    expect(s.pack('tips')!['version'], 1);
  });
}
