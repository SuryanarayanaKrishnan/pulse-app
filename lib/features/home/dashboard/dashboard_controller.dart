import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../capture/kv_store.dart';
import '../../../capture/providers.dart';
import '../../../core/analytics/analytics.dart';
import 'dashboard_layout.dart';

@immutable
class DashboardState {
  const DashboardState({
    required this.layout,
    this.editing = false,
    this.offerCalm = false,
  });
  final DashboardLayout layout;
  final bool editing;

  /// An existing Home was found: offer the calm one once.
  final bool offerCalm;

  DashboardState copyWith({
    DashboardLayout? layout,
    bool? editing,
    bool? offerCalm,
  }) => DashboardState(
    layout: layout ?? this.layout,
    editing: editing ?? this.editing,
    offerCalm: offerCalm ?? this.offerCalm,
  );
}

/// Owns the Home dashboards and their persistence.
///
/// Layouts live in the local settings store ([KvStore], like the tour and
/// backup flags), not in the ledger database. They are a per-device view
/// preference, so they are deliberately not part of the sync allow-list in
/// `sync_scope.dart`. Dashboard names are typed by the user and never leave
/// the phone, nor does analytics see them.
class DashboardController extends Notifier<DashboardState> {
  static const storageKey = 'home.dashboards';
  static const calmMigrationKey = 'home.calm_v1';

  var _touched = false;

  @override
  DashboardState build() {
    _load();
    return DashboardState(layout: DashboardLayout.defaults());
  }

  KvStore get _kv => ref.read(kvStoreProvider);

  Future<void> _load() async {
    try {
      final raw = await _kv.read(storageKey);
      if (_touched || !ref.mounted) return;
      var layout = DashboardLayout.decode(raw);
      var offer = false;
      // Someone who set Home up before the calm default keeps what they see
      // until they answer a one-time offer to try the calm Home.
      if (raw != null && raw.isNotEmpty) {
        if (await _kv.read(calmMigrationKey) == null) {
          layout = layout.withLegacyExtras();
          offer = true;
        }
      } else {
        await _kv.write(calmMigrationKey, '1');
      }
      state = state.copyWith(layout: layout, offerCalm: offer);
    } on Object {
      // Storage unavailable: keep the defaults, quietly.
    }
  }

  void _set(DashboardLayout next, {String? action, DashKind? kind}) {
    if (next == state.layout) return;
    _touched = true;
    state = state.copyWith(layout: next);
    () async {
      try {
        await _kv.write(storageKey, next.encode());
      } on Object {
        // Not saved; the layout still works for this session.
      }
    }();
    if (action != null && kind != null) {
      ref
          .read(analyticsProvider)
          .track(
            AnalyticsEvent.dashboardCustomised(
              action: action,
              widget: kind.key,
            ),
          );
    }
  }

  DashboardLayout get _l => state.layout;

  /// The answer to the one-time offer. Yes: the calm Home. No: keep their
  /// Home exactly as it is. Either way the offer never comes back.
  Future<void> answerCalmOffer({required bool calm}) async {
    final next = calm ? _l.calmed() : _l;
    state = state.copyWith(offerCalm: false);
    _set(next);
    try {
      await _kv.write(storageKey, state.layout.encode());
      await _kv.write(calmMigrationKey, '1');
    } on Object {
      // Not saved: the offer may show again next launch.
    }
    ref
        .read(analyticsProvider)
        .track(
          AnalyticsEvent.dashboardCustomised(
            action: calm ? 'calm_accepted' : 'calm_declined',
            widget: DashKind.safeToSpend.key,
          ),
        );
  }

  void setEditing(bool v) => state = state.copyWith(editing: v);

  void select(String id) => _set(_l.select(id));

  void add(DashKind k) => _set(_l.addWidget(k), action: 'added', kind: k);
  void remove(DashKind k) =>
      _set(_l.removeWidget(k), action: 'removed', kind: k);
  void resize(DashKind k, WidgetSize s) =>
      _set(_l.resizeWidget(k, s), action: 'resized', kind: k);
  void reorder(int from, int to) {
    final moved = from >= 0 && from < _l.active.widgets.length
        ? _l.active.widgets[from].kind
        : null;
    _set(_l.reorderWidget(from, to), action: 'moved', kind: moved);
  }

  void addDashboard(String name) => _set(
    _l.addDashboard(name, id: 'd${DateTime.now().microsecondsSinceEpoch}'),
  );
  void renameActive(String name) => _set(_l.renameActive(name));
  void deleteActive() => _set(_l.deleteActive());
}

final dashboardProvider = NotifierProvider<DashboardController, DashboardState>(
  DashboardController.new,
);
