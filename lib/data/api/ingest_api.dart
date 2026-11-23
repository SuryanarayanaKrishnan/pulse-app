import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'dto.dart';

/// Backend ingest channels (`POST /v1/ingest/<channel>`).
enum IngestChannel {
  sms('sms', '/v1/ingest/sms'),
  notification('notification', '/v1/ingest/notification'),
  appleShortcut('apple_shortcut', '/v1/ingest/apple-shortcut');

  const IngestChannel(this.wire, this.path);
  final String wire;
  final String path;

  static IngestChannel fromWire(String w) =>
      values.firstWhere((c) => c.wire == w, orElse: () => sms);
}

/// Thin client for the three ingest endpoints.
class IngestApi {
  IngestApi(this._dio);
  final Dio _dio;

  /// Posts [payload] (an [IngestRequestDto.toJson] map). Returns the server
  /// result; `duplicate: true` (HTTP 200) is a success. Throws [ApiException].
  Future<IngestResultDto> send(
    IngestChannel channel,
    Map<String, Object?> payload,
  ) => guardApi(() async {
    final res = await _dio.post<Map<String, Object?>>(
      channel.path,
      data: payload,
    );
    return IngestResultDto.fromJson(res.data!);
  });
}
