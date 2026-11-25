import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../capture/capture_source.dart';
import '../../capture/providers.dart';
import '../../capture/shortcut_links.dart';
import '../../core/analytics/analytics.dart';
import '../../core/env/env.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../coach/coach.dart';
import 'capture_paths.dart';

/// Guided setup of the four iPhone capture paths: Wallet payments, bank SMS,
/// screenshots (Back Tap) and the ask-after-shopping nudge. All four are part
/// of setup; the user may skip for now and is reminded on Home.
///
/// iOS does not let an app create a personal automation, flip Run Immediately
/// or bind Back Tap, so each path is: one tap to add the prebuilt shortcut (or
/// the shortest hand-built route while its iCloud link is not set), the few
/// taps iOS reserves for the user, then a "Test it" that waits for the first
/// event to arrive. See docs/SHORTCUT_LINKS.md.
class ApplePaySetupScreen extends ConsumerStatefulWidget {
  const ApplePaySetupScreen({super.key});
  @override
  ConsumerState<ApplePaySetupScreen> createState() =>
      _ApplePaySetupScreenState();
}

class _ApplePaySetupScreenState extends ConsumerState<ApplePaySetupScreen>
    with WidgetsBindingObserver {
  final _first = <CaptureSource, DateTime?>{};
  final _last = <CaptureSource, DateTime?>{};
  final _testStart = <CaptureSource, DateTime>{};
  final _expanded = <CaptureSource>{};
  bool _expandedInit = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final svc = ref.read(captureServiceProvider);
    await svc.drain();
    final first = <CaptureSource, DateTime?>{};
    final last = <CaptureSource, DateTime?>{};
    for (final s in CaptureSource.values) {
      first[s] = await svc.sourceFirstSeen(s);
      last[s] = await svc.sourceLastSeen(s);
    }
    if (!mounted) return;
    setState(() {
      _first
        ..clear()
        ..addAll(first);
      _last
        ..clear()
        ..addAll(last);
      if (!_expandedInit) {
        _expandedInit = true;
        // Open the first path that is not done yet.
        final next = CaptureSource.values
            .where((s) => first[s] == null)
            .firstOrNull;
        if (next != null) _expanded.add(next);
      }
    });
    ref.invalidate(captureProgressProvider);
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );

  Future<void> _open(Uri uri, String failMsg) async {
    Haptics.tap();
    final ok = await ref.read(urlOpenerProvider)(uri);
    if (!ok && mounted) _toast(failMsg);
  }

  /// The one-tap install: opens the iCloud share link, which shows iOS's own
  /// "Add Shortcut" sheet. Without a link it opens Shortcuts (or the new
  /// shortcut editor for the screenshot path) and the steps below say what to
  /// add.
  Future<void> _install(CapturePath p) async {
    final link = ref.read(shortcutLinksProvider).linkFor(p.source);
    if (link != null) {
      await _open(link, 'Could not open the shortcut link.');
    } else if (p.source == CaptureSource.screenshot) {
      await _open(ShortcutDeepLinks.create, 'Could not open Shortcuts.');
    } else {
      await _open(ShortcutDeepLinks.open, 'Could not open Shortcuts.');
    }
  }

  void _startTest(CaptureSource s) {
    Haptics.tap();
    setState(() => _testStart[s] = ref.read(captureClockProvider)());
    // Keep the state machine moving so a timeout shows without another event.
    unawaited(_check());
  }

  TestState _state(CaptureSource s) => evaluateTest(
    startedAt: _testStart[s],
    lastSeen: _last[s],
    now: ref.read(captureClockProvider)(),
    timeout: s.testTimeout,
  );

  void _finish() {
    final any = _first.values.any((v) => v != null);
    if (any) {
      ref
          .read(analyticsProvider)
          .track(AnalyticsEvent.sourceConnected('apple_pay_shortcut'));
    }
    context.pop(any ? true : null);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final done = CaptureSource.values.where((s) => _first[s] != null).length;
    final all = done == CaptureSource.values.length;
    return CoachHost(
      screen: CoachScreen.capture,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('iPhone capture setup'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.popOrHome(),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 40),
          children: [
            CoachTarget(
              id: 'steps',
              child: Text(
                'Four capture paths make ${Env.appName} automatic. The actions '
                'already live inside the app, so each path is one tap to add, '
                'a few taps iOS keeps for you, and a test. Everything stays on '
                'this phone.',
                style: context.tt.bodyLarge!.copyWith(color: c.textSecondary),
              ),
            ),
            const SizedBox(height: Space.md),
            Text(
              '$done of ${CaptureSource.values.length} working',
              key: const Key('capture_progress'),
              style: context.tt.titleMedium!.copyWith(color: c.accent),
            ),
            const SizedBox(height: Space.md),
            for (final p in CapturePath.all) _pathCard(context, p),
            const SizedBox(height: Space.lg),
            PrimaryButton(
              key: const Key('capture_done'),
              label: all ? 'Done' : 'Finish later',
              secondary: !all,
              onPressed: _finish,
            ),
            if (!all) ...[
              const SizedBox(height: Space.sm),
              Center(
                child: Text(
                  'Skipping is fine. Until all four work, ${Env.appName} will '
                  'miss payments on the paths you have not finished, and Home '
                  'will remind you.',
                  textAlign: TextAlign.center,
                  style: context.tt.bodySmall!.copyWith(color: c.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pathCard(BuildContext context, CapturePath p) {
    final c = context.pc;
    final s = p.source;
    final isDone = _first[s] != null;
    final open = _expanded.contains(s);
    final hasLink = ref.watch(shortcutLinksProvider).has(s);
    final steps = hasLink ? p.stepsWithLink : p.stepsWithoutLink;
    // Screenshot path has no automation; its first step is only the install.
    final installLabel = hasLink ? 'Add Shortcut' : 'Open Shortcuts';
    return Padding(
      key: Key('path_${s.name}'),
      padding: const EdgeInsets.only(bottom: Space.md),
      child: SurfaceCard(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              key: Key('path_header_${s.name}'),
              onTap: () => setState(() {
                open ? _expanded.remove(s) : _expanded.add(s);
              }),
              child: Row(
                children: [
                  Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isDone ? c.positive : c.textTertiary,
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title, style: context.tt.titleSmall),
                        Text(
                          isDone ? 'Working' : 'Needs setup',
                          style: context.tt.bodySmall!.copyWith(
                            color: isDone ? c.positive : c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: c.textTertiary,
                  ),
                ],
              ),
            ),
            if (open) ...[
              const SizedBox(height: Space.sm),
              Text(p.why, style: context.tt.bodyMedium),
              const SizedBox(height: Space.md),
              _step(context, 1, _installText(p, hasLink)),
              PrimaryButton(
                key: Key('install_${s.name}'),
                label: installLabel,
                icon: Icons.open_in_new_rounded,
                onPressed: () => _install(p),
              ),
              const SizedBox(height: Space.md),
              if (s == CaptureSource.bankSms) ...[
                PrimaryButton(
                  key: const Key('bank_sms_guide'),
                  label: 'Step-by-step guide',
                  icon: Icons.format_list_numbered_rounded,
                  secondary: true,
                  onPressed: () => context.push(Routes.bankSmsSetup),
                ),
                const SizedBox(height: Space.md),
              ],
              for (var i = 0; i < steps.length; i++)
                _step(context, i + 2, steps[i]),
              _testPanel(context, p),
            ],
          ],
        ),
      ),
    );
  }

  String _installText(CapturePath p, bool hasLink) {
    if (hasLink) {
      return 'Tap Add Shortcut, then Add Shortcut again in Shortcuts. '
          'Nothing to build.';
    }
    return p.source == CaptureSource.screenshot
        ? 'The ready-made shortcut is not published yet. Tap Open Shortcuts '
              'and follow the next step.'
        : 'The ready-made shortcut is not published yet, so there is one '
              'step less to add: tap Open Shortcuts.';
  }

  Widget _testPanel(BuildContext context, CapturePath p) {
    final c = context.pc;
    final s = p.source;
    final state = _state(s);
    final isDone = _first[s] != null;
    final (IconData icon, Color color, String text) = switch (state) {
      TestState.passed => (
        Icons.check_circle_rounded,
        c.positive,
        'It works. That ${_what(s)} reached ${Env.appName}.',
      ),
      TestState.failed => (Icons.error_outline_rounded, c.negative, p.failHint),
      TestState.waiting => (
        Icons.hourglass_empty_rounded,
        c.textTertiary,
        'Waiting for it to arrive. ${p.testHint}',
      ),
      TestState.idle =>
        isDone
            ? (
                Icons.check_circle_rounded,
                c.positive,
                'It has worked before. Test it again any time.',
              )
            : (Icons.hourglass_empty_rounded, c.textTertiary, p.testHint),
    };
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(
                  text,
                  key: Key('test_status_${s.name}'),
                  style: context.tt.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  key: Key('test_${s.name}'),
                  label: state == TestState.failed ? 'Test again' : 'Test it',
                  secondary: true,
                  onPressed: () => _startTest(s),
                ),
              ),
              if (p.canRunNow) ...[
                const SizedBox(width: Space.sm),
                Expanded(
                  child: PrimaryButton(
                    key: Key('run_${s.name}'),
                    label: 'Run it now',
                    secondary: true,
                    onPressed: () {
                      _startTest(s);
                      _open(
                        ShortcutDeepLinks.run(p.shortcutName),
                        'Could not open Shortcuts.',
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _what(CaptureSource s) => switch (s) {
    CaptureSource.wallet => 'payment',
    CaptureSource.bankSms => 'bank text',
    CaptureSource.screenshot => 'screenshot',
    CaptureSource.nudge => 'order',
  };

  Widget _step(BuildContext context, int n, String body) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$n',
              style: context.tt.labelMedium!.copyWith(color: c.accent),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(child: Text(body, style: context.tt.bodySmall)),
        ],
      ),
    );
  }
}
