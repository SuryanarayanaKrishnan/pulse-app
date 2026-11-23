import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/analytics/analytics.dart';
import 'core/env/env.dart';
import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'features/auth/session.dart';

class PulseApp extends ConsumerStatefulWidget {
  const PulseApp({super.key, this.initialLocation});
  final String? initialLocation;
  @override
  ConsumerState<PulseApp> createState() => _PulseAppState();
}

class _PulseAppState extends ConsumerState<PulseApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(
      session: ref.read(sessionProvider),
      analytics: ref.read(analyticsProvider),
      initialLocation: widget.initialLocation,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: Env.appName,
    debugShowCheckedModeBanner: false,
    theme: PulseTheme.light,
    darkTheme: PulseTheme.dark,
    themeMode: ThemeMode.dark,
    routerConfig: _router,
  );
}
