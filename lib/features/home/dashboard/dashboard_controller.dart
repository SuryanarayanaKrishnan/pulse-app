import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../capture/kv_store.dart';
import '../../../capture/providers.dart';
import '../../../core/analytics/analytics.dart';
import 'dashboard_layout.dart';

@immutable
class DashboardState {
  const DashboardState({required this.layout, this.editing = false});
  final DashboardLayout layout;
  final bool editing;

  DashboardState copyWith({DashboardLayout? layout, bool? editing}) =>
      DashboardState(
        layout: layout ?? this.layout,
        editing: editing ?? this.editing,
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
      state = state.copyWith(layout: DashboardLayout.decode(raw));
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
