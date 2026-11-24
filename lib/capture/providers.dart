import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analytics/analytics.dart';
import '../core/env/env.dart';
import '../data/providers.dart';
import 'apple_shortcut.dart';
import 'capture_config.dart';
import 'capture_platform.dart';
import 'capture_service.dart';
import 'ingest_queue.dart';
import 'kv_store.dart';

final kvStoreProvider = Provider<KvStore>((ref) => SharedPrefsKvStore());

/// Hands each queued capture to the on-device pipeline. Nothing is uploaded:
/// the queue is only a durable inbox between the native layer and the
/// pipeline. Without a database (tests, demo data) the queue drains into the
/// void so it never builds a backlog.
final ingestSenderProvider = Provider<IngestSender>((ref) {
  final pipeline = ref.watch(ingestPipelineProvider);
  if (pipeline == null || Env.demoData) {
    return (item) async {
      debugPrint('[ingest:demo] ${item.channel.wire} ${item.id}');
      return SendOutcome.sent;
    };
  }
  return localIngestSender(pipeline);
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
