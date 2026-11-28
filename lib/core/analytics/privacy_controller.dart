import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../capture/kv_store.dart';

/// Where the person stands on sharing anonymous usage.
enum ConsentState {
  /// Not asked yet. Nothing is sent.
  unasked,
  granted,

  /// Asked and said no (or closed the question). Nothing is sent.
  declined,
}

/// The person's analytics choice, their random anonymous id, and the small
/// bits of local bookkeeping the funnel needs. All of it lives on this phone.
///
/// * Default is off. Only an explicit "yes" turns sharing on.
/// * The anonymous id is random (not derived from the account, the device or
///   anything else), created only when sharing is on, replaced when the person
///   taps "Reset anonymous id", rotated on its own every [idLifetime], and
///   deleted when sharing is turned off.
class PrivacyController extends ChangeNotifier {
  PrivacyController(
    this._kv, {
    DateTime Function()? clock,
    Random? random,
    this.idLifetime = const Duration(days: 90),
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  final KvStore _kv;
  final DateTime Function() _clock;
  final Random _random;
  final Duration idLifetime;

  static const consentKey = 'analytics.consent';
  static const idKey = 'analytics.install_id';
  static const idCreatedKey = 'analytics.install_id_created';
  static const firstOpenKey = 'analytics.first_open';
  static String _milestoneKey(String n) => 'analytics.once.$n';
  static String _returnKey(String b) => 'analytics.returned.$b';

  ConsentState _consent = ConsentState.unasked;
  String? _id;
  DateTime? _idCreated;
  DateTime? _firstOpen;
  final _flags = <String>{};

  ConsentState get consent => _consent;

  /// True only after an explicit yes.
  bool get sharing => _consent == ConsentState.granted;
  bool get asked => _consent != ConsentState.unasked;

  /// The current anonymous id, or null when not sharing. Rotates it first if
  /// it has outlived [idLifetime].
  String? get installId {
    if (!sharing) return null;
    final created = _idCreated;
    if (_id == null ||
        created == null ||
        _clock().difference(created) >= idLifetime) {
      _newId();
    }
    return _id;
  }

  /// Reads saved state. Await once before the app starts.
  Future<void> load() async {
    try {
      final c = await _kv.read(consentKey);
      _consent = switch (c) {
        'granted' => ConsentState.granted,
        'declined' => ConsentState.declined,
        _ => ConsentState.unasked,
      };
      _id = await _kv.read(idKey);
      _idCreated = DateTime.tryParse(await _kv.read(idCreatedKey) ?? '');
      _firstOpen = DateTime.tryParse(await _kv.read(firstOpenKey) ?? '');
      for (final k in [
        'onboarding_completed', 'first_capture', 'first_card_added', //
        'first_budget_set', 'first_split_settled',
      ]) {
        if (await _kv.read(_milestoneKey(k)) == '1')
          _flags.add(_milestoneKey(k));
      }
      for (final b in ['d1', 'd7']) {
        if (await _kv.read(_returnKey(b)) == '1') _flags.add(_returnKey(b));
      }
      if (!sharing) _id = null; // never keep an id around without consent
    } catch (e) {
      debugPrint('Privacy settings unreadable, staying private: $e');
      _consent = ConsentState.unasked;
      _id = null;
    }
    notifyListeners();
  }

  Future<void> setSharing(bool on) async {
    if (on) {
      _consent = ConsentState.granted;
      _write(consentKey, 'granted');
      _newId();
    } else {
      _consent = ConsentState.declined;
      _write(consentKey, 'declined');
      _id = null;
      _idCreated = null;
      _remove(idKey);
      _remove(idCreatedKey);
    }
    notifyListeners();
  }

  /// A brand-new random id. Nothing links it to the old one.
  void resetId() {
    if (!sharing) return;
    _newId();
    notifyListeners();
  }

  void _newId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    _id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    _idCreated = _clock();
    _write(idKey, _id!);
    _write(idCreatedKey, _idCreated!.toUtc().toIso8601String());
  }

  /// True the first time [name] is passed, ever. Counted whether or not
  /// sharing is on, so a milestone from before opting in is never sent late.
  bool firstTime(String name) {
    final k = _milestoneKey(name);
    if (!_flags.add(k)) return false;
    _write(k, '1');
    return true;
  }

  /// `d1` about a day after the first open, `d7` a week to two weeks after;
  /// each at most once, and only while sharing. Remembers the first open
  /// (a local date, never sent).
  String? returnBucket() {
    final now = _clock();
    if (_firstOpen == null) {
      _firstOpen = now;
      _write(firstOpenKey, now.toUtc().toIso8601String());
      return null;
    }
    if (!sharing) return null;
    final a = _firstOpen!.toLocal();
    final b = now.toLocal();
    final days = DateTime(
      b.year,
      b.month,
      b.day,
    ).difference(DateTime(a.year, a.month, a.day)).inDays;
    final bucket = days == 1 ? 'd1' : (days >= 7 && days < 14 ? 'd7' : null);
    if (bucket == null || !_flags.add(_returnKey(bucket))) return null;
    _write(_returnKey(bucket), '1');
    return bucket;
  }

  void _write(String k, String v) =>
      unawaited(_kv.write(k, v).catchError((_) {}));
  void _remove(String k) => unawaited(_kv.remove(k).catchError((_) {}));
}

/// Tests and previews get a throwaway in-memory controller (sharing off).
/// The app overrides this with the saved one.
final privacyControllerProvider = Provider<PrivacyController>(
  (ref) => PrivacyController(MemoryKvStore()),
);
