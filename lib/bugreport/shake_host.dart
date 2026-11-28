import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'launcher.dart';
import 'settings.dart';
import 'shake_detector.dart';

/// Where shake samples come from. Tests override this with a fake stream.
final shakeSourceProvider = Provider<Stream<Accel> Function()>((ref) {
  return () {
    try {
      return accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).map<Accel>((e) => (x: e.x, y: e.y, z: e.z)).handleError((Object _) {});
    } on Object {
      return const Stream<Accel>.empty();
    }
  };
});

/// Sits at the root of the app: provides the screenshot boundary and, while
/// the app is in the foreground and shake-to-report is on, listens for a shake.
class ShakeHost extends ConsumerStatefulWidget {
  const ShakeHost({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ShakeHost> createState() => _ShakeHostState();
}

class _ShakeHostState extends ConsumerState<ShakeHost>
    with WidgetsBindingObserver {
  late final ShakeListener _listener;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listener = ShakeListener(
      source: ref.read(shakeSourceProvider),
      onShake: () =>
          unawaited(ref.read(bugReportLauncherProvider).launch('shake')),
    );
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    if (!mounted) return;
    final want = _foreground && ref.read(shakeEnabledProvider);
    want ? _listener.start() : _listener.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listener.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(shakeEnabledProvider, (_, _) => _sync());
    return RepaintBoundary(
      key: ref.watch(captureKeyProvider),
      child: widget.child,
    );
  }
}
