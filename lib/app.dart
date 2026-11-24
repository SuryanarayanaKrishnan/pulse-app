import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'capture/providers.dart';
import 'core/analytics/analytics.dart';
import 'core/env/env.dart';
import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'core/theme/theme_mode.dart';
import 'data/providers.dart';
import 'features/auth/session.dart';

class PulseApp extends ConsumerStatefulWidget {
  const PulseApp({super.key, this.initialLocation});
  final String? initialLocation;
  @override
  ConsumerState<PulseApp> createState() => _PulseAppState();
}

class _PulseAppState extends ConsumerState<PulseApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // No-op off Android. Drains buffered SMS/notifications into the offline
    // queue and uploads them.
    ref.read(captureServiceProvider).start();
    _refreshWealth();
    _router = buildRouter(
      session: ref.read(sessionProvider),
      analytics: ref.read(analyticsProvider),
      initialLocation: widget.initialLocation,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(captureServiceProvider).onResumed();
      _refreshWealth();
    }
  }

  /// In the background on open and resume: re-register reminders, fetch fresh
  /// prices and NAVs when a backend is configured (a no-op otherwise), store
  /// today's valuations. Never blocks the UI; failures keep the cache.
  Future<void> _refreshWealth() async {
    try {
      final svc = ref.read(wealthServiceProvider);
      await svc.rescheduleReminders();
      if (svc.prices.canFetch) {
        await svc.prices.refresh();
        await svc.refreshNavs();
      }
      await svc.recordValuations();
      if (mounted) invalidateWealth(ref);
    } on Object catch (e) {
      debugPrint('Wealth refresh skipped: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: Env.appName,
    debugShowCheckedModeBanner: false,
    theme: PulseTheme.light,
    darkTheme: PulseTheme.dark,
    themeMode: ref.watch(themeModeProvider),
    routerConfig: _router,
  );
}
