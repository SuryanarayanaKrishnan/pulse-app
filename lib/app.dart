import 'dart:async';

import 'bugreport/shake_host.dart';
import 'core/learning/learning_controller.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'backup/backup_providers.dart';
import 'household/household_providers.dart';
import 'sync/sync_providers.dart';
import 'capture/capture_confirmation.dart';
import 'capture/providers.dart';
import 'core/analytics/analytics.dart';
import 'core/analytics/privacy_controller.dart';
import 'core/env/env.dart';
import 'core/router/router.dart';
import 'core/theme/mood.dart';
import 'core/theme/theme.dart';
import 'core/theme/theme_mode.dart';
import 'data/providers.dart';
import 'features/splits/auto_settle.dart';
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
  StreamSubscription<CaptureReply>? _confirmSub;

  Future<void> _onCaptureReply(CaptureReply r) async {
    final db = ref.read(localDatabaseProvider);
    if (r.action == CaptureAction.undo && db != null) {
      await undoCapturedTransaction(db, r.txId);
    }
    _router.go(Routes.activity);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // No-op off Android. Drains buffered SMS/notifications into the offline
    // queue and uploads them.
    ref.read(captureServiceProvider).start();
    _confirmSub = ref.read(captureConfirmerProvider).replies.listen(_onCaptureReply);
    _refreshWealth();
    _noteOpen();
    _vaultCheckIn();
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
      _noteOpen();
      _vaultCheckIn();
      ref.read(backupSchedulerProvider)?.onResumed();
      ref.read(syncServiceProvider)?.onResumed();
      ref.read(householdSchedulerProvider)?.onResume();
      unawaited(ref.read(learningControllerProvider).flushIfDue());
    }
  }

  /// Opening the app is the family vault's check-in (the inactivity timer
  /// restarts). Never blocks and never throws.
  void _vaultCheckIn() {
    try {
      unawaited(ref.read(vaultServiceProvider).checkIn().catchError((Object e) => debugPrint('Vault check-in skipped: $e')));
    } on Object catch (e) {
      debugPrint('Vault check-in skipped: $e');
    }
  }

  /// Day-1 / day-7 return buckets (only while sharing is on).
  void _noteOpen() {
    final b = ref.read(privacyControllerProvider).returnBucket();
    if (b != null) ref.read(analyticsProvider).track(AnalyticsEvent.appReturned(b));
  }

  /// In the background on open and resume: re-register reminders, fetch fresh
  /// prices and NAVs when a backend is configured (a no-op otherwise), store
  /// today's valuations. Never blocks the UI; failures keep the cache.
  Future<void> _refreshWealth() async {
    try {
      final svc = ref.read(wealthServiceProvider);
      await svc.rescheduleReminders();
      final inv = ref.read(investingServiceProvider);
      await inv.rescheduleBuyReminders();
      if (svc.prices.canFetch) {
        await inv.refreshPrices();
        await svc.prices.refresh();
        await svc.refreshNavs();
      }
      // Free public sources read on the phone (AMFI NAVs, end-of-day closes).
      // Throttled to every few hours, so repeated opens cost nothing.
      await ref.read(livePriceServiceProvider).refresh();
      await svc.recordValuations();
      if (mounted) invalidateWealth(ref);
    } on Object catch (e) {
      debugPrint('Wealth refresh skipped: $e');
    }
  }

  @override
  void dispose() {
    _confirmSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the backup change-watcher alive for the life of the app.
    ref.watch(backupSchedulerProvider);
    // Same for sync: the service watches local writes while it is alive.
    ref.watch(syncServiceProvider);
    ref.watch(householdSchedulerProvider);
    final mood = ref.watch(moodProvider);
    return MaterialApp.router(
      title: Env.appName,
      debugShowCheckedModeBanner: false,
      theme: PulseTheme.forMood(mood, dark: false),
      darkTheme: PulseTheme.forMood(mood, dark: true),
      themeMode: ref.watch(themeModeProvider),
      // A slow cross-fade so a change of mood is felt, not seen.
      themeAnimationDuration: const Duration(milliseconds: 700),
      themeAnimationCurve: Curves.easeInOut,
      routerConfig: _router,
      scaffoldMessengerKey: AutoSettleHost.messengerKey,
      builder: (context, child) => ShakeHost(
        child: AutoSettleHost(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
