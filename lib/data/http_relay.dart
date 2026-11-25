import 'package:dio/dio.dart';

import '../core/vault/release.dart';

/// The real [InactivityRelay]: talks to the Pulse backend's `/v1/vault/relay`.
///
/// The server only ever receives the sealed (already encrypted) file and a
/// hash of the claim code. Owner calls carry the owner's session; the nominee's
/// claim carries nothing but the hash of the code they were given.
class HttpInactivityRelay implements InactivityRelay {
  HttpInactivityRelay(this._dio);
  final Dio _dio;

  @override
  bool get isAvailable => true;

  @override
  Future<void> arm({
    required String nomineeId,
    required String sealedFile,
    required String claimCodeHash,
    required int intervalDays,
    required DateTime now,
  }) async {
    await _dio.put<Object?>(
      '/v1/vault/relay/${Uri.encodeComponent(nomineeId)}',
      data: {
        'sealed_file': sealedFile,
        'claim_code_hash': claimCodeHash,
        'interval_days': intervalDays,
      },
      options: Options(
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 1),
      ),
    );
  }

  @override
  Future<void> heartbeat(DateTime now) async {
    await _dio.post<Object?>('/v1/vault/relay/heartbeat');
  }

  @override
  Future<void> setInterval(int intervalDays) async {
    await _dio.put<Object?>(
      '/v1/vault/relay',
      data: {'interval_days': intervalDays},
    );
  }

  @override
  Future<void> disarm(String nomineeId) async {
    try {
      await _dio.delete<Object?>(
        '/v1/vault/relay/${Uri.encodeComponent(nomineeId)}',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow;
    }
  }

  @override
  Future<ClaimResult> claim({
    required String nomineeId,
    required String claimCode,
    required DateTime now,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/vault/relay/claim',
        data: {'claim_code_hash': hashClaimCode(claimCode)},
      );
      return parseClaim(res.data ?? const {});
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        return const ClaimWrongCode(locked: true);
      }
      return const ClaimUnavailable();
    }
  }
}

ClaimResult parseClaim(Map<String, dynamic> j) {
  switch (j['status']) {
    case 'released':
      final f = j['sealed_file'];
      return f is String ? ClaimReleased(f) : const ClaimUnavailable();
    case 'pending':
      final at = DateTime.tryParse('${j['release_at']}');
      return at == null ? const ClaimUnavailable() : ClaimPending(at.toLocal());
    case 'not_yet':
      return ClaimNotYet((j['days_left'] as num?)?.toInt() ?? 0);
    case 'wrong_code':
      return const ClaimWrongCode();
  }
  return const ClaimUnavailable();
}
