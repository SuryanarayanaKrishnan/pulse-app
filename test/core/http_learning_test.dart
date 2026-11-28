import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/learning/contribution.dart';
import 'package:pulse/core/learning/global_merchant_map.dart';
import 'package:pulse/core/learning/http_learning.dart';

class _Fake implements HttpClientAdapter {
  _Fake(this.status, [this.body = '']);
  final int status;
  final String body;
  final seen = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    seen.add(o);
    return ResponseBody.fromString(body, status);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('upload sends the contract body with no auth and no ids; 204 means accepted', () async {
    final fake = _Fake(204);
    final dio = anonymousClient('https://x.test')..httpClientAdapter = fake;
    final ok = await HttpContributionTransport(dio).send(
      ContributionBatch(
        mapVersion: 3,
        pairs: [PairCount('spinneys', 'groceries', 2)],
      ),
    );
    expect(ok, isTrue);
    final req = fake.seen.single;
    expect(req.path, '/v1/category-contributions');
    expect(
      req.headers.keys.map((k) => k.toLowerCase()),
      isNot(contains('authorization')),
    );
    expect(req.data, {
      'format': 1,
      'map_version': 3,
      'pairs': [
        {'k': 'spinneys', 'c': 'groceries', 'n': 2},
      ],
    });
  });

  test('a rejected or failed upload keeps the queue (false)', () async {
    for (final s in [422, 429, 500]) {
      final dio = anonymousClient('https://x.test')
        ..httpClientAdapter = _Fake(s);
      final ok = await HttpContributionTransport(dio)
          .send(ContributionBatch(mapVersion: 1, pairs: []));
      expect(ok, isFalse);
    }
  });

  test('a newer valid map is stored, an older one is not', () async {
    final kv = MemoryKvStore();
    final current = GlobalMerchantMap.parse(
      jsonEncode({
        'version': 2,
        'schema': 1,
        'entries': {'spinneys': 'groceries'},
      }),
    );
    final newer = jsonEncode({
      'version': 3,
      'schema': 1,
      'entries': {'spinneys': 'groceries', 'lulu': 'groceries'},
    });
    var dio = anonymousClient('https://x.test')
      ..httpClientAdapter = _Fake(200, newer);
    expect(await refreshMerchantMap(dio, kv: kv, current: current), isTrue);
    dio = anonymousClient('https://x.test')
      ..httpClientAdapter = _Fake(
        200,
        jsonEncode({
          'version': 1,
          'schema': 1,
          'entries': {'a b': 'dining'},
        }),
      );
    expect(await refreshMerchantMap(dio, kv: kv, current: current), isFalse);
    dio = anonymousClient('https://x.test')
      ..httpClientAdapter = _Fake(500, 'nope');
    expect(await refreshMerchantMap(dio, kv: kv, current: current), isFalse);
  });
}
