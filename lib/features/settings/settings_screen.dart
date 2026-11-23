import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/env/env.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../core/router/router.dart';
import '../auth/session.dart';
import '../capture/capture_setup_sheet.dart';

bool get _android => !kIsWeb && Platform.isAndroid;

Widget _tap(VoidCallback onTap, Widget child) =>
    InkWell(onTap: onTap, child: child);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    Widget row(IconData icon, String title, String sub, {Widget? trailing}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: c.accent),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.tt.titleSmall),
                    Text(sub, style: context.tt.bodySmall),
                  ],
                ),
              ),
              trailing ??
                  Icon(Icons.chevron_right_rounded, color: c.textTertiary),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 40),
        children: [
          GlassCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: c.accent,
                  child: const Text(
                    'S',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sara Al Mansoori', style: context.tt.titleMedium),
                      Text('sara@example.ae', style: context.tt.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Automatic capture'),
          GlassCard(
            child: Column(
              children: [
                row(Icons.mail_rounded, 'Gmail statements', 'Connected'),
                if (_android) ...[
                  _tap(
                    () => showCaptureSetupSheet(context),
                    row(
                      Icons.sms_rounded,
                      'Bank SMS and wallet alerts',
                      'Permissions, status and what is read',
                    ),
                  ),
                ],
                if (!_android)
                  _tap(
                    () => context.push(Routes.applePaySetup),
                    row(
                      Icons.apple,
                      'Apple Pay Shortcut (iOS)',
                      'Set up automation',
                    ),
                  ),
              ],
            ),
          ),
          const SectionHeader('Preferences'),
          GlassCard(
            child: Column(
              children: [
                row(Icons.currency_exchange_rounded, 'Currency', 'AED'),
                row(
                  Icons.notifications_rounded,
                  'Notifications',
                  'Due dates, budget alerts',
                ),
                row(Icons.lock_rounded, 'Face ID / biometrics', 'Enabled'),
              ],
            ),
          ),
          const SectionHeader('About'),
          GlassCard(
            child: Column(
              children: [
                row(
                  Icons.info_outline_rounded,
                  '${Env.appName} beta',
                  'Friends & family build',
                ),
                row(
                  Icons.analytics_rounded,
                  'Analytics',
                  Env.hasPosthog ? 'PostHog enabled' : 'Console / off',
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            label: 'Sign out',
            secondary: true,
            onPressed: () => ref.read(sessionProvider).signOut(),
          ),
        ],
      ),
    );
  }
}
