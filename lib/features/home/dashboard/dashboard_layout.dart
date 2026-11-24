/// The pure model behind customisable Home dashboards. No Flutter, no
/// storage: everything is immutable and every edit returns a new value, so
/// it is trivial to test.
///
/// Each dashboard holds an ordered list of metric widgets, at most one of
/// each kind, each either [WidgetSize.compact] or [WidgetSize.regular].
library;

import 'dart:convert';

/// The metrics a dashboard can show. [key] is the stable serialised and
/// analytics value (a fixed choice, never free text).
enum DashKind {
  safeToSpend('safe_to_spend', 'Safe to spend'),
  budgetProgress('budget_progress', 'Budget progress'),
  upcoming('upcoming', 'Upcoming bills and dues'),
  cardRewards('card_rewards', 'Card rewards'),
  netWorth('net_worth', 'Net worth'),
  spendByCategory('spend_by_category', 'Spend by category'),
  cashFlow('cash_flow', 'Cash flow'),
  savingsRate('savings_rate', 'Savings rate'),
  splitBalances('split_balances', 'Split balances'),
  recentCaptures('recent_captures', 'Recent captures'),
  goals('goals', 'Goals');

  const DashKind(this.key, this.label);
  final String key;
  final String label;

  static DashKind? fromKey(Object? key) {
    for (final k in values) {
      if (k.key == key) return k;
    }
    return null;
  }

  /// Every key, for the analytics allow-list.
  static List<String> get keys => [for (final k in values) k.key];
}

enum WidgetSize {
  compact,
  regular;

  static WidgetSize fromName(Object? n) =>
      n == 'compact' ? WidgetSize.compact : WidgetSize.regular;
}

class DashWidget {
  const DashWidget(this.kind, [this.size = WidgetSize.regular]);
  final DashKind kind;
  final WidgetSize size;

  DashWidget withSize(WidgetSize s) => DashWidget(kind, s);

  Map<String, Object?> toJson() => {'kind': kind.key, 'size': size.name};

  @override
  bool operator ==(Object other) =>
      other is DashWidget && other.kind == kind && other.size == size;
  @override
  int get hashCode => Object.hash(kind, size);
  @override
  String toString() => '${kind.key}:${size.name}';
}

class Dashboard {
  const Dashboard({
    required this.id,
    required this.name,
    this.widgets = const [],
  });
  final String id;
  final String name;
  final List<DashWidget> widgets;

  Dashboard _with({String? name, List<DashWidget>? widgets}) => Dashboard(
    id: id,
    name: name ?? this.name,
    widgets: widgets ?? this.widgets,
  );

  bool has(DashKind k) => widgets.any((w) => w.kind == k);

  /// Kinds that can still be added.
  List<DashKind> get available => [
    for (final k in DashKind.values)
      if (!has(k)) k,
  ];

  Dashboard add(DashKind k, [WidgetSize size = WidgetSize.regular]) =>
      has(k) ? this : _with(widgets: [...widgets, DashWidget(k, size)]);

  Dashboard remove(DashKind k) => _with(
    widgets: [
      for (final w in widgets)
        if (w.kind != k) w,
    ],
  );

  /// Moves the widget at [oldIndex] so it ends up at [newIndex] in the
  /// result, as `ReorderableListView.onReorderItem` reports it.
  Dashboard reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= widgets.length) return this;
    final to = newIndex.clamp(0, widgets.length - 1);
    if (to == oldIndex) return this;
    final list = [...widgets];
    list.insert(to, list.removeAt(oldIndex));
    return _with(widgets: list);
  }

  Dashboard resize(DashKind k, WidgetSize size) => _with(
    widgets: [for (final w in widgets) w.kind == k ? w.withSize(size) : w],
  );

  Dashboard rename(String n) => _with(name: DashboardLayout.cleanName(n));

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'widgets': [for (final w in widgets) w.toJson()],
  };
}

/// All dashboards plus which one is showing.
class DashboardLayout {
  const DashboardLayout({required this.dashboards, required this.activeId});

  /// Bumped when the stored shape changes. See [DashboardLayout.decode].
  static const schemaVersion = 2;
  static const maxDashboards = 5;
  static const maxNameLength = 20;

  final List<Dashboard> dashboards;
  final String activeId;

  /// What a new install gets: the Home it always had, as "Everyday", and a
  /// "Month end" view for closing the month.
  factory DashboardLayout.defaults() => const DashboardLayout(
    activeId: 'everyday',
    dashboards: [
      Dashboard(
        id: 'everyday',
        name: 'Everyday',
        widgets: [
          DashWidget(DashKind.safeToSpend),
          DashWidget(DashKind.upcoming),
          DashWidget(DashKind.netWorth, WidgetSize.compact),
          DashWidget(DashKind.splitBalances, WidgetSize.compact),
          DashWidget(DashKind.goals, WidgetSize.compact),
          DashWidget(DashKind.recentCaptures),
        ],
      ),
      Dashboard(
        id: 'month_end',
        name: 'Month end',
        widgets: [
          DashWidget(DashKind.budgetProgress),
          DashWidget(DashKind.cashFlow),
          DashWidget(DashKind.savingsRate, WidgetSize.compact),
          DashWidget(DashKind.spendByCategory),
          DashWidget(DashKind.cardRewards, WidgetSize.compact),
        ],
      ),
    ],
  );

  Dashboard get active => dashboards.firstWhere(
    (d) => d.id == activeId,
    orElse: () => dashboards.first,
  );

  bool get canAddDashboard => dashboards.length < maxDashboards;
  bool get canDeleteDashboard => dashboards.length > 1;

  static String cleanName(String raw) {
    final t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return 'Dashboard';
    return t.length > maxNameLength
        ? t.substring(0, maxNameLength).trimRight()
        : t;
  }

  DashboardLayout _replaceActive(Dashboard d) => DashboardLayout(
    activeId: activeId,
    dashboards: [for (final x in dashboards) x.id == d.id ? d : x],
  );

  DashboardLayout select(String id) => dashboards.any((d) => d.id == id)
      ? DashboardLayout(dashboards: dashboards, activeId: id)
      : this;

  DashboardLayout addWidget(DashKind k, [WidgetSize s = WidgetSize.regular]) =>
      _replaceActive(active.add(k, s));
  DashboardLayout removeWidget(DashKind k) => _replaceActive(active.remove(k));
  DashboardLayout reorderWidget(int from, int to) =>
      _replaceActive(active.reorder(from, to));
  DashboardLayout resizeWidget(DashKind k, WidgetSize s) =>
      _replaceActive(active.resize(k, s));
  DashboardLayout renameActive(String name) =>
      _replaceActive(active.rename(name));

  /// A new empty dashboard, which becomes the active one. [id] must be unique;
  /// a clash gets a numeric suffix.
  DashboardLayout addDashboard(String name, {required String id}) {
    if (!canAddDashboard) return this;
    var uid = id;
    for (var n = 2; dashboards.any((d) => d.id == uid); n++) {
      uid = '$id-$n';
    }
    final d = Dashboard(id: uid, name: cleanName(name));
    return DashboardLayout(dashboards: [...dashboards, d], activeId: uid);
  }

  /// Deletes the active dashboard (never the last one).
  DashboardLayout deleteActive() {
    if (!canDeleteDashboard) return this;
    final i = dashboards.indexWhere((d) => d.id == activeId);
    final rest = [
      for (final d in dashboards)
        if (d.id != activeId) d,
    ];
    return DashboardLayout(
      dashboards: rest,
      activeId: rest[(i - 1).clamp(0, rest.length - 1)].id,
    );
  }

  // ---- Serialise / migrate ----

  Map<String, Object?> toJson() => {
    'v': schemaVersion,
    'active': activeId,
    'dashboards': [for (final d in dashboards) d.toJson()],
  };

  String encode() => jsonEncode(toJson());

  /// Reads a stored layout. Anything unreadable, empty or from a newer app
  /// version falls back to [defaults]; nothing here throws.
  ///
  /// * v1 (the first draft): `{"widgets": ["net_worth", ...]}`, one list of
  ///   kind keys. It becomes a single "Everyday" dashboard.
  /// * v2 (current): named dashboards with sized widgets.
  ///
  /// Unknown kinds are dropped and duplicates collapse, so a later app that
  /// removes a kind does not break an older layout.
  factory DashboardLayout.decode(String? raw) {
    if (raw == null || raw.isEmpty) return DashboardLayout.defaults();
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return DashboardLayout.defaults();
      final v = j['v'] ?? 1;
      if (v is! int || v > schemaVersion || v < 1)
        return DashboardLayout.defaults();
      if (v == 1) return _fromV1(j);
      return _fromV2(j);
    } on Object {
      return DashboardLayout.defaults();
    }
  }

  static DashboardLayout _fromV1(Map j) {
    final kinds = [
      for (final k in (j['widgets'] as List? ?? const [])) DashKind.fromKey(k),
    ];
    var d = const Dashboard(id: 'everyday', name: 'Everyday');
    for (final k in kinds) {
      if (k != null) d = d.add(k);
    }
    return DashboardLayout(dashboards: [d], activeId: d.id);
  }

  static DashboardLayout _fromV2(Map j) {
    final out = <Dashboard>[];
    final seen = <String>{};
    for (final raw in (j['dashboards'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final id = raw['id'];
      if (id is! String || id.isEmpty || !seen.add(id)) continue;
      var d = Dashboard(id: id, name: cleanName('${raw['name'] ?? ''}'));
      for (final w in (raw['widgets'] as List? ?? const [])) {
        if (w is! Map) continue;
        final k = DashKind.fromKey(w['kind']);
        if (k != null) d = d.add(k, WidgetSize.fromName(w['size']));
      }
      out.add(d);
      if (out.length == maxDashboards) break;
    }
    if (out.isEmpty) return DashboardLayout.defaults();
    final active = j['active'];
    return DashboardLayout(
      dashboards: out,
      activeId: out.any((d) => d.id == active)
          ? active as String
          : out.first.id,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DashboardLayout && other.encode() == encode();
  @override
  int get hashCode => encode().hashCode;
}
