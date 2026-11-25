import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../env/env.dart';

/// Dio client with Supabase JWT auth interceptor.
Dio buildApiClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(AuthInterceptor(devTokens: DevTokenSource.maybe()));
  return dio;
}

/// Attaches the current Supabase access token (if Supabase is configured).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({this.devTokens});

  /// Local dev only (null in every normal and release build).
  final DevTokenSource? devTokens;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final dev = devTokens;
    if (dev != null) {
      final token = await dev.token();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      return handler.next(options);
    }
    if (Env.hasSupabase) {
      try {
        final token = Supabase.instance.client.auth.currentSession?.accessToken;
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
      } catch (_) {
        // Supabase not initialised; proceed unauthenticated.
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) devTokens?.invalidate();
    if (err.response?.statusCode == 401 && Env.hasSupabase) {
      try {
        await Supabase.instance.client.auth.refreshSession();
      } catch (_) {}
    }
    handler.next(err);
  }
}

/// Fetches a real backend token without a login, from the local backend's
/// dev-only `POST /v1/dev/token`. Only built with `--dart-define=DEV_AUTH=true`
/// in a non-release build ([Env.devAuthEnabled]); the backend refuses to
/// expose that route outside APP_ENV=development. docs/LOCAL_DEV.md.
class DevTokenSource {
  DevTokenSource(this._dio);

  /// Null unless dev auth is enabled for this build.
  static DevTokenSource? maybe() {
    if (!Env.devAuthEnabled) return null;
    return DevTokenSource(
      Dio(
        BaseOptions(
          baseUrl: Env.apiBaseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      ),
    );
  }

  final Dio _dio;
  String? _token;
  Future<String?>? _inFlight;

  void invalidate() => _token = null;

  Future<String?> token() async {
    if (_token != null) return _token;
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  Future<String?> _fetch() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/v1/dev/token');
      return _token = res.data?['access_token'] as String?;
    } catch (_) {
      // Backend without ALLOW_DEV_AUTH or not running: carry on unauthenticated.
      return null;
    }
  }
}
