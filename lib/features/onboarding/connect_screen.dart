import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics.dart';
import '../../core/env/env.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../auth/session.dart';

/// "Connect your money": pushes users to automatic sources first.
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});
  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final _connected = <String>{};

  bool get _isIos => !kIsWeb && Platform.isIOS;
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  void _connect(String type) {
    Haptics.success();
    setState(() => _connected.add(type));
    ref.read(analyticsProvider).track(AnalyticsEvent.sourceConnected(type));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final sources = [
      (
        'gmail',
        Icons.mail_rounded,
        'Gmail statements',
        'We find bank and card statement emails and read them securely. Best coverage.',
        'Recommended',
      ),
      if (!_isIos)
        (
          'sms',
          Icons.sms_rounded,
          'Bank SMS (Android)',
          'Instant capture from bank alerts. Messages stay on your device.',
          _isAndroid ? 'Instant' : 'Android only',
        ),
      if (!_isAndroid)
        (
          'apple_pay_shortcut',
          Icons.apple,
          'Apple Pay Shortcut (iOS)',
          'A one-time Shortcuts automation sends each tap-to-pay to ${Env.appName} instantly.',
          _isIos ? 'Instant' : 'iOS only',
        ),
      (
        'statement_upload',
        Icons.upload_file_rounded,
        'Upload a PDF statement',
        'Backfill history in seconds.',
        'Backfill',
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Space.gutter),
          children: [
            const SizedBox(height: Space.xl),
            Text('Connect your money', style: context.tt.displayMedium),
            const SizedBox(height: Space.sm),
            Text(
              'Automatic sources mean you never log a transaction by hand. Connect at least one.',
              style: context.tt.bodyLarge!.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: Space.xl),
            for (var i = 0; i < sources.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child:
                    GlassCard(
                          onTap: () {
                            final t = sources[i].$1;
                            _connect(t);
                            if (t == 'statement_upload')
                              ref
                                  .read(analyticsProvider)
                                  .track(AnalyticsEvent.statementUploaded);
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: c.accent.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(sources[i].$2, color: c.accent),
                              ),
                              const SizedBox(width: Space.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            sources[i].$3,
                                            style: context.tt.titleSmall,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Pill(
                                          sources[i].$5,
                                          color: c.accentAlt,
                                          selected: true,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      sources[i].$4,
                                      style: context.tt.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: Space.sm),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: _connected.contains(sources[i].$1)
                                    ? Icon(
                                        Icons.check_circle_rounded,
                                        key: const ValueKey('ok'),
                                        color: c.positive,
                                      )
                                    : Icon(
                                        Icons.add_circle_outline_rounded,
                                        key: const ValueKey('add'),
                                        color: c.textTertiary,
                                      ),
                              ),
                            ],
                          ),
                        )
                        .animate(delay: stagger(i))
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1),
              ),
            const SizedBox(height: Space.lg),
            PrimaryButton(
              label: _connected.isEmpty
                  ? 'Connect a source to continue'
                  : 'Continue',
              onPressed: _connected.isEmpty
                  ? null
                  : () {
                      ref
                          .read(analyticsProvider)
                          .track(
                            AnalyticsEvent.onboardingStepCompleted(
                              'connect_sources',
                            ),
                          );
                      ref.read(sessionProvider).finishConnect();
                    },
            ),
            const SizedBox(height: Space.md),
            Center(
              child: TextButton(
                onPressed: () => ref.read(sessionProvider).finishConnect(),
                child: Text(
                  'I will do this later',
                  style: context.tt.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
