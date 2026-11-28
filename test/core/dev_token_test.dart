import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/env/env.dart';
import 'package:pulse/core/network/api_client.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final ResponseBody Function(RequestOptions) handler;
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<List<int>>? s,
    Future<void>? c,
  ) async {
    calls++;
    return handler(o);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(String body, [int status = 200]) => ResponseBody.fromString(
  body,
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

void main() {
  test('dev auth is off unless built with DEV_AUTH', () {
    expect(Env.devAuth, isFalse);
    expect(Env.devAuthEnabled, isFalse);
    expect(DevTokenSource.maybe(), isNull);
  });

  test('fetches once, caches, refetches after invalidate', () async {
    final a = _Adapter((_) => _json('{"access_token":"t1"}'));
    final src = DevTokenSource(Dio()..httpClientAdapter = a);
    expect(await src.token(), 't1');
    expect(await src.token(), 't1');
    expect(a.calls, 1);
    src.invalidate();
    await src.token();
    expect(a.calls, 2);
  });

  test('a missing endpoint yields no token instead of throwing', () async {
    final a = _Adapter((_) => _json('{}', 404));
    final src = DevTokenSource(Dio()..httpClientAdapter = a);
    expect(await src.token(), isNull);
  });

  test('interceptor attaches the dev token as bearer', () async {
    final a = _Adapter((o) {
      if (o.path.endsWith('/v1/dev/token'))
        return _json('{"access_token":"abc"}');
      return _json('{"auth":"${o.headers['Authorization']}"}');
    });
    final tokenDio = Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = a;
    final dio = Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = a;
    dio.interceptors.add(AuthInterceptor(devTokens: DevTokenSource(tokenDio)));
    final r = await dio.get<Map<String, dynamic>>('/v1/me');
    expect(r.data!['auth'], 'Bearer abc');
  });
}
