import 'package:dio/dio.dart';

/// Error raised by the API layer. Mirrors the backend envelope
/// `{"error": {"code", "message", "details", "request_id"}}`.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.code = 'unknown',
    this.details = const [],
    this.requestId,
    this.isNetwork = false,
  });

  final String message;
  final int? statusCode;
  final String code;
  final List<Object?> details;
  final String? requestId;

  /// No response at all: offline, DNS failure, timeout.
  final bool isNetwork;

  bool get isUnauthorized => statusCode == 401;

  /// Worth retrying later: transport failures, timeouts, 408/425/429, 5xx.
  bool get isRetryable {
    if (isNetwork) return true;
    final s = statusCode;
    if (s == null) return false;
    return s >= 500 || s == 408 || s == 425 || s == 429;
  }

  /// Retrying can never succeed (bad payload, not found, conflict...).
  bool get isPermanent => !isRetryable && !isUnauthorized;

  factory ApiException.fromDio(DioException e) {
    final res = e.response;
    if (res == null) {
      return ApiException(
        message: switch (e.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout =>
            'The server took too long to respond.',
          _ => 'Could not reach the server. Check your connection.',
        },
        code: 'network_error',
        isNetwork: true,
      );
    }
    final data = res.data;
    if (data is Map && data['error'] is Map) {
      final err = Map<String, Object?>.from(data['error'] as Map);
      return ApiException(
        message: (err['message'] as String?) ?? 'Request failed',
        statusCode: res.statusCode,
        code: (err['code'] as String?) ?? 'http_error',
        details: (err['details'] as List?)?.cast<Object?>() ?? const [],
        requestId: err['request_id'] as String?,
      );
    }
    return ApiException(
      message: 'Request failed (${res.statusCode})',
      statusCode: res.statusCode,
      code: 'http_error',
    );
  }

  @override
  String toString() =>
      'ApiException($statusCode $code: $message${requestId != null ? ' [$requestId]' : ''})';
}

/// Runs [body], converting [DioException] into [ApiException].
Future<T> guardApi<T>(Future<T> Function() body) async {
  try {
    return await body();
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
}
