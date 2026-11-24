import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../capture/kv_store.dart';
import '../engine/merchants.dart' show merchantKey, normalizeMerchant;
import 'contribution.dart';
import 'contribution_transport.dart';
import 'global_merchant_map.dart';
import 'privacy_filter.dart';

/// "Help improve categories": the person's choice, the queue of confirmed
/// pairs, and the weekly upload. Off by default, independent of the
/// analytics switch, and everything it keeps is on this phone.
class LearningController extends ChangeNotifier {
  LearningController(
    this._kv, {
    GlobalMerchantMap? map,
    this.transport = const DisabledContributionTransport(),
    DateTime Function()? clock,
    Random? random,
    this.interval = const Duration(days: 7),
  }) : map = map ?? GlobalMerchantMap.empty,
       _clock = clock ?? DateTime.now {
    filter = MerchantKeyFilter(this.map);
    queue = ContributionQueue(_kv, filter);
    batcher = ContributionBatcher(filter: filter, random: random);
  }

  final KvStore _kv;
  final ContributionTransport transport;
  final DateTime Function() _clock;
  final Duration interval;

  final GlobalMerchantMap map;
  late final MerchantKeyFilter filter;
  late final ContributionQueue queue;
  late final ContributionBatcher batcher;

  static const optInKey = 'learning.opt_in';
  static const lastBatchKey = 'learning.last_batch';

  bool _optIn = false;
  DateTime? _lastBatch;
  bool _busy = false;

  /// True only after an explicit yes.
  bool get optIn => _optIn;

  /// Whether an upload endpoint is configured in this build.
  bool get uploadsConfigured => transport.enabled;

  Future<void> load() async {
    try {
      _optIn = await _kv.read(optInKey) == 'on';
      _lastBatch = DateTime.tryParse(await _kv.read(lastBatchKey) ?? '');
      if (_optIn) {
        await queue.load();
      } else {
        // Never keep queued data around without consent.
        await queue.clear();
      }
    } on Object catch (e) {
      debugPrint('Learning settings unreadable, staying off: $e');
      _optIn = false;
    }
    notifyListeners();
  }

  /// Turning it on starts an empty queue and the weekly clock. Turning it off
  /// deletes everything queued and the clock.
  Future<void> setOptIn(bool on) async {
    if (on == _optIn) return;
    _optIn = on;
    if (on) {
      _lastBatch = _clock();
      await _kv.write(optInKey, 'on');
      await _kv.write(lastBatchKey, _lastBatch!.toUtc().toIso8601String());
    } else {
      _lastBatch = null;
      await queue.clear();
      await _kv.remove(lastBatchKey);
      await _kv.write(optInKey, 'off');
    }
    notifyListeners();
  }

  /// Deletes everything waiting to be shared, staying opted in.
  Future<void> clearQueue() async {
    await queue.clear();
    notifyListeners();
  }

  /// Call when the person confirms a category for a payment (recategorise or
  /// a Review swipe). Does nothing unless opted in. [merchant] is the name
  /// shown for the payment; only its normalised key may be kept, and only if
  /// it passes the privacy filter. Returns whether anything was queued.
  Future<bool> recordConfirmation({
    required String paymentId,
    required String? merchant,
    required String categoryId,
  }) async {
    if (!_optIn) return false;
    final key = merchantKey(normalizeMerchant(merchant));
    if (key == null) return false;
    final stored = await queue.confirm(paymentId, key, categoryId);
    if (stored) notifyListeners();
    return stored;
  }

  /// What "See what would be shared" shows. Works while off too (it is just
  /// empty).
  ContributionPreview preview() {
    final queued = queue.all();
    final items = batcher.candidates(queued);
    return ContributionPreview(
      items: items,
      waiting: queued.length - items.length,
      dropPercent: (batcher.dropProbability * 100).round(),
      nextSend: _optIn && transport.enabled && _lastBatch != null
          ? _lastBatch!.add(interval)
          : null,
    );
  }

  /// Sends one batch if opted in, an endpoint is configured and a week has
  /// passed since the last one. Safe to call often. A failed upload keeps the
  /// queue and tries again on the next call.
  Future<void> flushIfDue() async {
    if (!_optIn || !transport.enabled || _busy) return;
    final last = _lastBatch;
    final now = _clock();
    if (last != null && now.difference(last) < interval) return;
    _busy = true;
    try {
      final queued = queue.all();
      final batch = batcher.build(queued, mapVersion: map.version);
      if (!batch.isEmpty && !await transport.send(batch)) return;
      // Every eligible pair is removed, sent or left out by chance, so a
      // retry never re-rolls the dice for the same pair.
      await queue.remove(batcher.candidates(queued));
      _lastBatch = now;
      await _kv.write(lastBatchKey, now.toUtc().toIso8601String());
      notifyListeners();
    } on Object catch (e) {
      debugPrint('Category contribution failed: $e');
    } finally {
      _busy = false;
    }
  }
}

/// Tests and previews get an in-memory controller (off). The app overrides it.
final learningControllerProvider = Provider<LearningController>(
  (ref) => LearningController(MemoryKvStore()),
);

/// The merchant map in force. Defaults to empty; the app overrides it with the
/// loaded one.
final globalMerchantMapProvider = Provider<GlobalMerchantMap>(
  (ref) => GlobalMerchantMap.empty,
);
