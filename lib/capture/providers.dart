import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analytics/analytics.dart';
import '../core/env/env.dart';
import '../data/providers.dart';
import 'apple_shortcut.dart';
import 'capture_config.dart';
import 'capture_confirmation.dart';
import 'capture_platform.dart';
import 'capture_service.dart';
import 'capture_source.dart';
import 'ingest_queue.dart';
import 'kv_store.dart';

final kvStoreProvider = Provider<KvStore>((ref) => SharedPrefsKvStore());

/// Hands each queued capture to the on-device pipeline. Nothing is uploaded:
/// the queue is only a durable inbox between the native layer and the
/// pipeline. Without a database (tests, demo data) the queue drains into the
/// void so it never builds a backlog.
final captureConfirmerProvider = Provider<CaptureConfirmer>(
  (ref) => kIsWeb || ref.watch(ingestPipelineProvider) == null || Env.demoData
      ? const NoopCaptureConfirmer()
      : LocalNotificationCaptureConfirmer(),
);

final ingestSenderProvider = Provider<IngestSender>((ref) {
  final pipeline = ref.watch(ingestPipelineProvider);
  if (pipeline == null || Env.demoData) {
    return (item) async {
      debugPrint('[ingest:demo] ${item.channel.wire} ${item.id}');
      return SendOutcome.sent;
    };
  }
  return localIngestSender(
    pipeline,
    confirmer: ref.watch(captureConfirmerProvider),
  );
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
      : (!kIsWeb && Platform.isIOS)
      ? AppleInboxCapturePlatform()
      : const UnsupportedCapturePlatform(),
);

/// Wall clock for capture and the setup "Test it" checks. Overridden in tests.
final captureClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

final captureServiceProvider = Provider<CaptureService>((ref) {
  final s = CaptureService(
    platform: ref.watch(capturePlatformProvider),
    queue: ref.watch(ingestQueueProvider),
    kv: ref.watch(kvStoreProvider),
    analytics: ref.watch(analyticsProvider),
    config: const CaptureConfig(),
    clock: ref.watch(captureClockProvider),
  );
  ref.onDispose(s.dispose);
  return s;
});

final ingestTokenStoreProvider = Provider<IngestTokenStore>(
  (ref) => IngestTokenStore(ref.watch(kvStoreProvider)),
);

/// True on iOS, where the four guided capture paths apply. Overridden in tests.
final iosCaptureProvider = Provider<bool>(
  (ref) => AppleInboxCapturePlatform.isAvailable,
);

/// Which of the four paths have delivered at least one event. Invalidate after
/// a drain to refresh the Settings row and the Home nudge.
final captureProgressProvider = FutureProvider.autoDispose<Set<CaptureSource>>((
  ref,
) async {
  final svc = ref.watch(captureServiceProvider);
  return {
    for (final s in CaptureSource.values)
      if (await svc.sourceFirstSeen(s) != null) s,
  };
});
