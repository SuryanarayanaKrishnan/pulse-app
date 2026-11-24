import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Records requests and answers from a route table: `"GET /v1/accounts"`.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.routes);

  /// Value is a JSON-encodable body, a `(status, body)` record, or a function
  /// of the request returning either.
  final Map<String, Object?> routes;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final key = '${options.method} ${options.path}';
    var r = routes[key];
    if (r is Function) r = r(options);
    if (r == null) {
      return ResponseBody.fromString(
        jsonEncode({
          'error': {
            'code': 'not_found',
            'message': 'no route $key',
            'details': [],
          },
        }),
        404,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    var status = 200;
    Object? body = r;
    if (r is (int, Object?)) {
      status = r.$1;
      body = r.$2;
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio fakeDio(FakeAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
