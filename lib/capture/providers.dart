import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analytics/analytics.dart';
import '../core/env/env.dart';
import '../data/api/ingest_api.dart';
import '../data/providers.dart';
import 'apple_shortcut.dart';
import 'capture_config.dart';
import 'capture_platform.dart';
import 'capture_service.dart';
import 'ingest_queue.dart';
import 'kv_store.dart';

final kvStoreProvider = Provider<KvStore>((ref) => SharedPrefsKvStore());

final ingestApiProvider = Provider<IngestApi>(
  (ref) => IngestApi(ref.watch(dioProvider)),
);

/// Uploads through the API when configured. In mock mode the queue drains
/// into the void so the demo never accumulates a backlog.
final ingestSenderProvider = Provider<IngestSender>((ref) {
  if (Env.useApi) return apiIngestSender(ref.watch(ingestApiProvider));
  return (item) async {
    debugPrint('[ingest:mock] ${item.channel.wire} ${item.id}');
    return SendOutcome.sent;
  };
});

final ingestQueueProvider = Provider<IngestQueue>(
  (ref) => IngestQueue(
    store: ref.watch(kvStoreProvider),
    sender: ref.watch(ingestSenderProvider),
  ),
);

final capturePlatformProvider = Provider<CapturePlatform>(
  (ref) => (!kIsWeb && Platform.isAndroid)
      ? MethodChannelCapturePlatform()
      : const UnsupportedCapturePlatform(),
);

final captureServiceProvider = Provider<CaptureService>((ref) {
  final s = CaptureService(
    platform: ref.watch(capturePlatformProvider),
    queue: ref.watch(ingestQueueProvider),
    kv: ref.watch(kvStoreProvider),
    analytics: ref.watch(analyticsProvider),
    config: const CaptureConfig(),
  );
  ref.onDispose(s.dispose);
  return s;
});

final ingestTokenStoreProvider = Provider<IngestTokenStore>(
  (ref) => IngestTokenStore(ref.watch(kvStoreProvider)),
);
