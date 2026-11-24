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
  dio.interceptors.add(AuthInterceptor());
  return dio;
}

/// Attaches the current Supabase access token (if Supabase is configured).
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
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
    if (err.response?.statusCode == 401 && Env.hasSupabase) {
      try {
        await Supabase.instance.client.auth.refreshSession();
      } catch (_) {}
    }
    handler.next(err);
  }
}
