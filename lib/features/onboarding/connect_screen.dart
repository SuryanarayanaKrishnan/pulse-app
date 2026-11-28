import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../capture/capture_platform.dart';
import '../../core/router/router.dart';
import '../auth/session.dart';
import '../capture/capture_setup_sheet.dart';
import '../statements/statement_actions.dart';

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

  /// Tapping a source: Android capture and the Apple Pay guide open their own
  /// setup flows and only mark the source connected once it really is.
  Future<void> _onTap(String type) async {
    switch (type) {
      case 'sms' || 'wallet_notifications' when _isAndroid:
        final CaptureStatus? s = await showCaptureSetupSheet(context);
        if (s == null || !mounted) return;
        if (s.smsReceive) _connect('sms');
        if (s.notificationAccess) _connect('wallet_notifications');
      case 'apple_pay_shortcut':
        final done = await context.push<bool>(Routes.applePaySetup);
        if (done == true && mounted) _connect(type);
      case 'gmail':
        if (await connectGmail(context, ref) && mounted) _connect(type);
      case 'statement_upload':
        if (await uploadStatement(context, ref) && mounted) _connect(type);
      default:
        _connect(type);
    }
  }

  void _connect(String type) {
    if (_connected.contains(type)) return;
    Haptics.success();
    setState(() => _connected.add(type));
    // Gmail and uploads report their own events.
    if (type != 'gmail' && type != 'statement_upload') {
      ref.read(analyticsProvider).track(AnalyticsEvent.sourceConnected(type));
    }
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
          'Instant capture from bank alerts. Only bank senders are read; one-time codes are ignored.',
          _isAndroid ? 'Instant' : 'Android only',
        ),
      if (!_isIos)
        (
          'wallet_notifications',
          Icons.account_balance_wallet_rounded,
          'Wallet notifications (Android)',
          'Tap-to-pay alerts from Google Wallet, Samsung Wallet and bank apps.',
          _isAndroid ? 'Instant' : 'Android only',
        ),
      if (!_isAndroid)
        (
          'apple_pay_shortcut',
          Icons.apple,
          'iPhone capture (required)',
          'Four guided paths: Apple Pay, bank SMS, screenshots and Back Tap, and a nudge after shopping apps. You can skip and finish later.',
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
            const SizedBox(height: Space.xxl),
            Text('Connect your money', style: context.tt.displayMedium),
            const SizedBox(height: Space.sm),
            Text(
              'Automatic sources mean you never log a transaction by hand. Connect at least one.',
              style: context.tt.bodyLarge!.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: Space.xl),
            RowGroup(
              padding: EdgeInsets.zero,
              indent: ListRow.leadingInset,
              children: [
                for (final src in sources)
                  ListRow(
                    leading: IconWell(src.$2, color: c.calm),
                    title: src.$3,
                    subtitle: '${src.$5} · ${src.$4}',
                    onTap: () => _onTap(src.$1),
                    trailing: AnimatedSwitcher(
                      duration: Motion.base,
                      child: _connected.contains(src.$1)
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
                  ),
              ],
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
              child: TextAction(
                'Skip for now',
                color: c.textSecondary,
                onTap: () => ref.read(sessionProvider).finishConnect(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
