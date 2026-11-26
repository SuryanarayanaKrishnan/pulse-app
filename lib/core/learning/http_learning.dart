/// The real network side of "Help improve categories" (docs/LEARNING.md):
/// upload of anonymous confirmed pairs and refresh of the shared merchant map.
/// Both use a plain client with no auth header and no user or install id.
library;

import 'package:dio/dio.dart';

import '../../capture/kv_store.dart';
import 'contribution.dart';
import 'contribution_transport.dart';
import 'global_merchant_map.dart';
import 'global_merchant_map_loader.dart';

Dio anonymousClient(String baseUrl) => Dio(
  BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    headers: const {'User-Agent': 'PulseApp'},
  ),
);

class HttpContributionTransport implements ContributionTransport {
  HttpContributionTransport(this._dio);
  final Dio _dio;

  @override
  bool get enabled => true;

  @override
  Future<bool> send(ContributionBatch batch) async {
    try {
      final r = await _dio.post<Object?>(
        '/v1/category-contributions',
        data: batch.toJson(),
        options: Options(validateStatus: (_) => true),
      );
      return r.statusCode == 200 || r.statusCode == 204;
    } on Object {
      return false;
    }
  }
}

/// Fetches the shared map and keeps it if it is valid and newer. Applies on
/// the next launch. Never throws.
Future<bool> refreshMerchantMap(
  Dio dio, {
  required KvStore kv,
  required GlobalMerchantMap current,
}) async {
  try {
    final r = await dio.get<String>(
      '/v1/merchant-map',
      options: Options(responseType: ResponseType.plain),
    );
    final body = r.data;
    if (body == null) return false;
    return await GlobalMerchantMapLoader(kv: kv).offerRefreshed(body, current);
  } on Object {
    return false;
  }
}
