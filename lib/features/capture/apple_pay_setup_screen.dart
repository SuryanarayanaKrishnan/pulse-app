import 'dart:async';

import '../../core/router/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../capture/providers.dart';
import '../../core/analytics/analytics.dart';
import '../../core/env/env.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

/// Guided setup of the iOS Shortcuts "Transaction" automation.
/// Guided setup of the iOS Shortcuts "Transaction" automation.
///
/// iOS does not let an app create a personal automation, so this is as short
/// as it can be: the "Record Payment" action already ships inside the app (no
/// Shortcut to download), one button opens Shortcuts, and the screen confirms
/// the setup by watching for the first payment to arrive.
class ApplePaySetupScreen extends ConsumerStatefulWidget {
  const ApplePaySetupScreen({super.key});
  @override
  ConsumerState<ApplePaySetupScreen> createState() =>
      _ApplePaySetupScreenState();
}

class _ApplePaySetupScreenState extends ConsumerState<ApplePaySetupScreen>
    with WidgetsBindingObserver {
  DateTime? _seen;
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
    final seen = await svc.shortcutFirstSeen();
    if (mounted && seen != _seen) setState(() => _seen = seen);
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );

  Future<void> _openShortcuts() async {
    Haptics.tap();
    final ok = await launchUrl(
      Uri.parse('shortcuts://'),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) _toast('Could not open the Shortcuts app.');
  }

  void _done() {
    ref
        .read(analyticsProvider)
        .track(AnalyticsEvent.sourceConnected('apple_pay_shortcut'));
    context.pop(true);
  }

  Widget _step(BuildContext context, int n, String title, String body) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$n',
              style: context.tt.labelLarge!.copyWith(color: c.accent),
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.tt.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: context.tt.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final seen = _seen;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apple Pay setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.popOrHome(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 40),
        children: [
          Text(
            'Apple keeps Wallet private, but Shortcuts can run an action each '
            'time you pay with a card. ${Env.appName} already includes that '
            'action, so there is nothing to download. Payments stay on this '
            'phone. It takes about a minute, once.',
            style: context.tt.bodyLarge!.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.xl),
          _step(
            context,
            1,
            'Open Shortcuts',
            'Tap Automation at the bottom, then the + button, then Transaction.',
          ),
          PrimaryButton(
            label: 'Open Shortcuts',
            icon: Icons.open_in_new_rounded,
            onPressed: _openShortcuts,
          ),
          const SizedBox(height: Space.xl),
          _step(
            context,
            2,
            'Choose your cards',
            'Pick every card you pay with, including Tabby, and leave the '
                'merchant filter empty so it catches everything.',
          ),
          _step(
            context,
            3,
            'Run Immediately',
            'Select "Run Immediately" (not "Ask Before Running") and turn off '
                '"Notify When Run" so it stays out of your way.',
          ),
          _step(
            context,
            4,
            'Add the Record Payment action',
            'Search "Record Payment" and choose the ${Env.appName} one. Fill '
                'the three fields from the transaction: Amount, Merchant, and '
                'Card or Pass.',
          ),
          const SizedBox(height: Space.xl),
          Text(
            'Bank SMS too (optional, same place)',
            style: context.tt.titleMedium,
          ),
          const SizedBox(height: Space.sm),
          _step(
            context,
            5,
            'Add a Message automation',
            'In Automation tap +, then Message. Under Sender add your banks '
                '(ENBD, ADCB, FAB, Mashreq, SIB and so on) or set Message '
                'Contains to "AED". Choose Run Immediately.',
          ),
          _step(
            context,
            6,
            'Add Record Bank SMS',
            'Search "Record Bank SMS" and choose the ${Env.appName} one. Set '
                'Message to the Shortcut Input and Sender to its sender. '
                'One-time codes are dropped on the phone.',
          ),
          const SizedBox(height: Space.xl),
          Text(
            'Any app notification or order screen (optional)',
            style: context.tt.titleMedium,
          ),
          const SizedBox(height: Space.sm),
          _step(
            context,
            7,
            'Make a Capture shortcut',
            'In Shortcuts tap +, add Take Screenshot, then the "Capture to '
                '${Env.appName}" action. Turn on Show in Share Sheet so you '
                'can also send it an image.',
          ),
          _step(
            context,
            8,
            'Bind it to Back Tap',
            'Settings, Accessibility, Touch, Back Tap, Double Tap, then pick '
                'that shortcut. When a notification shows, or on a Tabby or '
                'Noon order, double-tap the back of the phone. The text is read '
                'on the phone and the image is thrown away.',
          ),
          const SizedBox(height: Space.xl),
          Text(
            'Nudge after shopping apps (optional)',
            style: context.tt.titleMedium,
          ),
          const SizedBox(height: Space.sm),
          _step(
            context,
            9,
            'Add an "App is closed" automation',
            'In Automation tap +, then App. Choose Noon, Talabat, Tabby and '
                'Careem, pick Is Closed, and Run Immediately.',
          ),
          _step(
            context,
            10,
            'Ask, then capture',
            'Add Show Alert with "Log that order?" (keep the Cancel button), '
                'then Get Latest Screenshots (1), then "Capture to '
                '${Env.appName}". Take a screenshot of the order confirmation '
                'before you close the app, and one tap on OK logs it.',
          ),
          const SizedBox(height: Space.md),
          SurfaceCard(
            padding: const EdgeInsets.all(Space.md),
            child: Row(
              children: [
                Icon(
                  seen == null
                      ? Icons.hourglass_empty_rounded
                      : Icons.check_circle_rounded,
                  color: seen == null ? c.textTertiary : c.accent,
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    seen == null
                        ? 'Waiting for your first payment. Pay with any card '
                              'and come back here.'
                        : 'It works. Your first payment arrived, and the next '
                              'ones will appear on their own.',
                    style: context.tt.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            label: seen == null ? 'I have set it up' : 'Done',
            onPressed: _done,
          ),
        ],
      ),
    );
  }
}
