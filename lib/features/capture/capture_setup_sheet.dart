import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../capture/capture_platform.dart';
import '../../capture/providers.dart';
import '../../core/env/env.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

/// Opens the Android capture setup. Returns the latest [CaptureStatus] so the
/// caller can mark sources connected.
Future<CaptureStatus?> showCaptureSetupSheet(BuildContext context) =>
    showPulseSheet<CaptureStatus>(
      context,
      builder: (_) => const CaptureSetupSheet(),
    );

class CaptureSetupSheet extends ConsumerStatefulWidget {
  const CaptureSetupSheet({super.key});
  @override
  ConsumerState<CaptureSetupSheet> createState() => _CaptureSetupSheetState();
}

class _CaptureSetupSheetState extends ConsumerState<CaptureSetupSheet> {
  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: 'Capture automatically',
    subtitle:
        '${Env.appName} reads only bank and wallet alerts. Nothing else on your phone is touched.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CapturePermissionList(onStatus: (_) {}),
        const SizedBox(height: Space.lg),
        const _Privacy(),
        const SizedBox(height: Space.lg),
        PrimaryButton(
          label: 'Done',
          onPressed: () async {
            final s = await ref.read(captureServiceProvider).status();
            if (context.mounted) Navigator.of(context).pop(s);
          },
        ),
      ],
    ),
  );
}

class _Privacy extends StatelessWidget {
  const _Privacy();
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, size: 18, color: c.textTertiary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Only messages from known UAE bank sender IDs are kept, and one-time codes are '
            'always discarded. You can turn either source off at any time in Android settings.',
            style: context.tt.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// SMS + wallet-notification permission rows with live status. Used in the
/// connect step sheet and in Settings.
class CapturePermissionList extends ConsumerStatefulWidget {
  const CapturePermissionList({super.key, this.onStatus});

  /// Called whenever the status is (re)loaded.
  final ValueChanged<CaptureStatus>? onStatus;

  @override
  ConsumerState<CapturePermissionList> createState() =>
      _CapturePermissionListState();
}

class _CapturePermissionListState extends ConsumerState<CapturePermissionList>
    with WidgetsBindingObserver {
  CaptureStatus _status = CaptureStatus.unsupported;
  bool _loaded = false;
  bool _busy = false;
  bool _awaitingNotificationSettings = false;
  CaptureStatus _beforeSettings = CaptureStatus.unsupported;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _set(CaptureStatus s) {
    if (!mounted) return;
    setState(() {
      _status = s;
      _loaded = true;
    });
    widget.onStatus?.call(s);
  }

  Future<void> _refresh() async =>
      _set(await ref.read(captureServiceProvider).status());

  /// Coming back from the system notification-access screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_awaitingNotificationSettings) {
      _awaitingNotificationSettings = false;
      ref
          .read(captureServiceProvider)
          .onReturnedFromNotificationSettings(_beforeSettings)
          .then(_set);
    } else {
      _refresh();
    }
  }

  Future<void> _requestSms() async {
    setState(() => _busy = true);
    try {
      _set(await ref.read(captureServiceProvider).requestSmsPermissions());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openNotificationSettings() async {
    _beforeSettings = _status;
    _awaitingNotificationSettings = true;
    await ref.read(captureServiceProvider).openNotificationAccessSettings();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: Space.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_status.supported) {
      return Text(
        'Automatic SMS and wallet capture is available on Android. '
        'On iPhone, use the Apple Pay Shortcut instead.',
        style: context.tt.bodyMedium,
      );
    }
    final s = _status;
    final smsLabel = s.smsGranted
        ? 'On'
        : s.smsReceive
        ? 'Live only'
        : s.smsPermanentlyDenied
        ? 'Blocked'
        : 'Off';
    return Column(
      children: [
        _PermissionRow(
          icon: Icons.sms_rounded,
          title: 'Bank SMS',
          why:
              'Instant capture of card and account alerts from banks like Emirates NBD, ADCB, '
              'FAB, Mashreq and RAKBANK. Also imports the last 90 days once so your history '
              'is not empty.',
          statusLabel: smsLabel,
          granted: s.smsGranted,
          actionLabel: s.smsPermanentlyDenied ? 'Open settings' : 'Allow',
          busy: _busy,
          onAction: s.smsGranted
              ? null
              : (s.smsPermanentlyDenied
                    ? () => ref.read(captureServiceProvider).openAppSettings()
                    : _requestSms),
        ),
        const SizedBox(height: Space.md),
        _PermissionRow(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Wallet notifications',
          why:
              'Picks up tap-to-pay alerts from Google Wallet, Google Pay, Samsung Wallet and '
              'bank apps. Android asks you to switch this on in system settings.',
          statusLabel: s.notificationAccess ? 'On' : 'Off',
          granted: s.notificationAccess,
          actionLabel: s.notificationAccess ? 'Manage' : 'Open settings',
          onAction: _openNotificationSettings,
          footnote: s.notificationAccess
              ? null
              : 'If the switch is greyed out, open App info for ${Env.appName}, tap the ⋮ menu '
                    'and choose "Allow restricted settings" (needed for apps installed outside Google Play).',
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.why,
    required this.statusLabel,
    required this.granted,
    required this.actionLabel,
    required this.onAction,
    this.busy = false,
    this.footnote,
  });
  final IconData icon;
  final String title;
  final String why;
  final String statusLabel;
  final bool granted;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool busy;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: c.accent),
              const SizedBox(width: Space.md),
              Expanded(child: Text(title, style: context.tt.titleSmall)),
              Pill(
                statusLabel,
                color: granted ? c.positive : c.warning,
                selected: true,
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(why, style: context.tt.bodySmall),
          if (footnote != null) ...[
            const SizedBox(height: Space.sm),
            Text(
              footnote!,
              style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
            ),
          ],
          if (onAction != null) ...[
            const SizedBox(height: Space.md),
            PrimaryButton(
              label: actionLabel,
              onPressed: onAction,
              loading: busy,
              secondary: granted,
            ),
          ],
        ],
      ),
    );
  }
}
