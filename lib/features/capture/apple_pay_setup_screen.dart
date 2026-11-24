import 'package:flutter/services.dart';
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
class ApplePaySetupScreen extends ConsumerStatefulWidget {
  const ApplePaySetupScreen({super.key});
  @override
  ConsumerState<ApplePaySetupScreen> createState() =>
      _ApplePaySetupScreenState();
}

class _ApplePaySetupScreenState extends ConsumerState<ApplePaySetupScreen> {
  String? _token;
  bool _reveal = false;

  static final linkTemplate =
      '${Env.urlScheme}://ingest?amount=[Amount]&merchant=[Merchant]&card=[Card or Pass]';

  bool get _shortcutPublished => !Env.appleShortcutUrl.contains('REPLACE_WITH');

  @override
  void initState() {
    super.initState();
    ref.read(ingestTokenStoreProvider).token().then((t) {
      if (mounted) setState(() => _token = t);
    });
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );

  Future<void> _openShortcut() async {
    if (!_shortcutPublished) {
      _toast('The shared Shortcut link is not published yet.');
      return;
    }
    final ok = await launchUrl(
      Uri.parse(Env.appleShortcutUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) _toast('Could not open the Shortcuts app.');
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    Haptics.tap();
    if (mounted) _toast('$what copied');
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
    final token = _token;
    final shown = token == null
        ? '...'
        : (_reveal ? token : '${token.substring(0, 8)}••••••••••••••••');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apple Pay setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 40),
        children: [
          Text(
            'Apple does not share Wallet data with apps, but the Shortcuts app can run '
            'an automation every time you pay with a card. We send each payment to '
            '${Env.appName} the moment it happens.',
            style: context.tt.bodyLarge!.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.xl),
          _step(
            context,
            1,
            'Add the Shortcut',
            'Open the shared Shortcut and tap "Add Shortcut". It already knows how to hand a payment to ${Env.appName}.',
          ),
          PrimaryButton(
            label: 'Open Shortcut',
            icon: Icons.open_in_new_rounded,
            onPressed: _openShortcut,
          ),
          const SizedBox(height: Space.xl),
          _step(
            context,
            2,
            'Create the automation',
            'In Shortcuts: Automation, New Automation, Transaction. Choose your cards, set "Run Immediately", and pick the ${Env.appName} Shortcut.',
          ),
          _step(
            context,
            3,
            'Pass the payment details',
            'The Shortcut opens the link below with the Amount, Merchant and Card from the transaction. ${Env.appName} then records it.',
          ),
          SurfaceCard(
            padding: const EdgeInsets.all(Space.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    linkTemplate,
                    style: context.tt.bodySmall!.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy link template',
                  icon: Icon(Icons.copy_rounded, color: c.accent, size: 20),
                  onPressed: () => _copy(linkTemplate, 'Link template'),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          _step(
            context,
            4,
            'Check it works',
            'Make a purchase with Apple Pay. It appears in Activity within seconds with an Apple Pay badge.',
          ),
          const SectionHeader('Ingest token'),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shown,
                        style: context.tt.bodyMedium!.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _reveal ? 'Hide token' : 'Show token',
                      icon: Icon(
                        _reveal
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: c.textTertiary,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _reveal = !_reveal),
                    ),
                    IconButton(
                      tooltip: 'Copy token',
                      icon: Icon(Icons.copy_rounded, color: c.accent, size: 20),
                      onPressed: token == null
                          ? null
                          : () => _copy(token, 'Token'),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                Text(
                  'Only needed if you prefer the Shortcut to upload straight to the server '
                  '(Get Contents of URL, header "Authorization: Bearer <token>"). '
                  'Direct token uploads are not enabled on the server yet; the link above '
                  'works today.',
                  style: context.tt.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(label: 'I have set it up', onPressed: _done),
        ],
      ),
    );
  }
}
