import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../capture/capture_source.dart';
import '../../capture/providers.dart';
import '../../capture/shortcut_links.dart';
import '../../core/env/env.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

/// Sample text the user sends to themselves to prove the automation runs.
const bankSmsTestText = 'Purchase of AED 12.00 at TEST using card ending 0000';

/// One short step per screen for the Bank SMS automation, mirroring the real
/// iOS flow: Automation, +, Message, Message Contains, Next, Run Shortcut,
/// Next, Run Immediately, Done. iOS does not let an app create the automation,
/// so this is the minimum the user must tap. See docs/SHORTCUT_LINKS.md.
class BankSmsSetupScreen extends ConsumerStatefulWidget {
  const BankSmsSetupScreen({super.key});
  @override
  ConsumerState<BankSmsSetupScreen> createState() => _BankSmsSetupScreenState();
}

class _Step {
  const _Step(this.title, this.body, {this.action});
  final String title;
  final String body;
  final String? action; // 'install' | 'open' | 'test'
}

class _BankSmsSetupScreenState extends ConsumerState<BankSmsSetupScreen> {
  static const _src = CaptureSource.bankSms;
  int _i = 0;
  DateTime? _testStart;
  DateTime? _last;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final svc = ref.read(captureServiceProvider);
    await svc.drain();
    final last = await svc.sourceLastSeen(_src);
    if (mounted) setState(() => _last = last);
    ref.invalidate(captureProgressProvider);
  }

  List<_Step> _steps(bool hasLink) => [
    _Step(
      'Add the shortcut',
      hasLink
          ? 'Tap Add Shortcut, then Add Shortcut again. It is called '
                '"${_src.shortcutName}".'
          : 'The ready-made shortcut is not published yet. You will add the '
                'Record Bank SMS action from ${Env.appName} directly in step 4.',
      action: hasLink ? 'install' : null,
    ),
    const _Step(
      'Start an automation',
      'Open Shortcuts. Tap Automation at the bottom, then the + button.',
      action: 'open',
    ),
    const _Step(
      'Choose Message',
      'Tap Message. Next to Message Contains type AED. You can also tap '
          'Sender and choose your banks. Tap Next.',
    ),
    _Step(
      'Pick the action',
      hasLink
          ? 'Tap Add Action, search Run Shortcut and add it. Tap Shortcut and '
                'choose "${_src.shortcutName}". Tap Next.'
          : 'Tap Add Action, search Record Bank SMS and add the '
                '${Env.appName} one. It takes the message by itself. Tap Next.',
    ),
    const _Step(
      'Run Immediately',
      'The top row says "Run After Confirmation". Tap it and choose "Run '
          'Immediately". Turn off Notify When Run. Tap Done.',
    ),
    const _Step(
      'Send yourself a test',
      'Open Messages and text yourself:\n$bankSmsTestText',
      action: 'test',
    ),
  ];

  Future<void> _open(Uri u) async {
    Haptics.tap();
    final ok = await ref.read(urlOpenerProvider)(u);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Shortcuts.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final link = ref.watch(shortcutLinksProvider).linkFor(_src);
    final steps = _steps(link != null);
    final step = steps[_i];
    final last = _i == steps.length - 1;
    final state = evaluateTest(
      startedAt: _testStart,
      lastSeen: _last,
      now: ref.read(captureClockProvider)(),
      timeout: _src.testTimeout,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank SMS setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 40),
        children: [
          Text(
            'Step ${_i + 1} of ${steps.length}',
            key: const Key('bank_sms_step_count'),
            style: context.tt.labelLarge!.copyWith(color: c.accent),
          ),
          const SizedBox(height: Space.sm),
          Text(step.title, style: context.tt.headlineSmall),
          const SizedBox(height: Space.sm),
          Text(step.body, style: context.tt.bodyLarge),
          const SizedBox(height: Space.lg),
          if (step.action == 'install')
            PrimaryButton(
              key: const Key('bank_sms_install'),
              label: 'Add Shortcut',
              icon: Icons.open_in_new_rounded,
              onPressed: () => _open(link!),
            ),
          if (step.action == 'open')
            PrimaryButton(
              key: const Key('bank_sms_open'),
              label: 'Open Shortcuts',
              icon: Icons.open_in_new_rounded,
              onPressed: () => _open(ShortcutDeepLinks.open),
            ),
          if (step.action == 'test') ...[
            PrimaryButton(
              key: const Key('bank_sms_test'),
              label: state == TestState.failed ? 'Test again' : 'Start test',
              onPressed: () {
                setState(() => _testStart = ref.read(captureClockProvider)());
                unawaited(_check());
              },
            ),
            const SizedBox(height: Space.md),
            SurfaceCard(
              child: Row(
                children: [
                  Icon(
                    switch (state) {
                      TestState.passed => Icons.check_circle_rounded,
                      TestState.failed => Icons.error_outline_rounded,
                      _ => Icons.hourglass_empty_rounded,
                    },
                    color: switch (state) {
                      TestState.passed => c.positive,
                      TestState.failed => c.negative,
                      _ => c.textTertiary,
                    },
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text(
                      key: const Key('bank_sms_status'),
                      switch (state) {
                        TestState.idle =>
                          'Tap Start test, then send the text above.',
                        TestState.waiting =>
                          'Waiting for your text to arrive...',
                        TestState.passed => 'It works. Your bank texts will now appear on their own.',
                        TestState.failed =>
                          'Nothing arrived after 30 seconds. Check Message '
                              'Contains says AED, the automation says Run '
                              'Immediately, then test again. A text you send '
                              'to yourself may not trigger it; if so, have '
                              'someone else send it.',
                      },
                      style: context.tt.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Space.xl),
          Row(
            children: [
              if (_i > 0)
                Expanded(
                  child: PrimaryButton(
                    key: const Key('bank_sms_back'),
                    label: 'Back',
                    secondary: true,
                    onPressed: () => setState(() => _i--),
                  ),
                ),
              if (_i > 0) const SizedBox(width: Space.sm),
              Expanded(
                child: PrimaryButton(
                  key: const Key('bank_sms_next'),
                  label: last ? 'Done' : 'Next',
                  onPressed: last
                      ? () => context.pop(state == TestState.passed)
                      : () => setState(() => _i++),
                ),
              ),
            ],
          ),
          if (last && state != TestState.passed)
            Center(
              child: TextAction(
                'Skip for now',
                color: c.textSecondary,
                onTap: () => context.pop(false),
              ),
            ),
        ],
      ),
    );
  }
}
