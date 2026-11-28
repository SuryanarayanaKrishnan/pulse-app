import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../backup/backup_providers.dart';
import '../../core/analytics/privacy_controller.dart';
import '../../core/entitlement/entitlement.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../auth/session.dart';
import '../discover/all_features_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final gmail = ref.watch(emailConnectionsProvider).value ?? const [];
    final onCount = gmail.where((g) => g.active).length;
    final backup = ref.watch(backupStateProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.popOrHome(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.xxxl),
        children: [
          RowGroup(
            children: [
              ListRow(
                leading: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surfaceElevated,
                    shape: BoxShape.circle,
                  ),
                  child: Text('S', style: context.tt.titleLarge),
                ),
                title: 'Sara Al Mansoori',
                subtitle: 'sara@example.ae',
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          RowGroup(
            children: [
              ListRow(
                key: const Key('settings_search'),
                leading: const IconWell(Icons.search_rounded),
                title: 'Search',
                subtitle: 'Find a setting, screen, card or payment',
                chevron: true,
                onTap: () => showAllFeaturesSheet(context),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          RowGroup(
            indent: ListRow.leadingInset,
            children: [
              ListRow(
                key: const Key('settings_connections'),
                leading: IconWell(Icons.power_outlined),
                title: 'Connections',
                subtitle: 'Gmail, bank texts, Apple Pay',
                trailing: onCount == 0
                    ? null
                    : Text('$onCount on', style: context.tt.bodySmall),
                chevron: true,
                onTap: () => context.push(Routes.connections),
              ),
              ListRow(
                leading: const IconWell(Icons.payments_outlined),
                title: 'Money',
                subtitle: 'Salary, categories, rules, monthly close',
                chevron: true,
                onTap: () => context.push(Routes.settingsSection('money')),
              ),
              ListRow(
                leading: const IconWell(Icons.people_outline_rounded),
                title: 'Family and household',
                subtitle: 'Shared budget, members, family vault',
                chevron: true,
                onTap: () => context.push(Routes.settingsSection('family')),
              ),
              ListRow(
                leading: const IconWell(Icons.cloud_done_outlined),
                title: 'Backup and devices',
                subtitle: backup.enabled ? 'Backup is on' : 'Backup is off',
                subtitleColor:
                    backup.cloud && backup.needsAttention(DateTime.now())
                    ? c.warning
                    : null,
                chevron: true,
                onTap: () => context.push(Routes.settingsSection('data')),
              ),
              ListRow(
                leading: const IconWell(Icons.privacy_tip_outlined),
                title: 'Privacy and security',
                subtitle: ref.watch(privacyControllerProvider).sharing
                    ? 'Sharing anonymous usage'
                    : 'Not sharing anything',
                chevron: true,
                onTap: () => context.push(Routes.privacy),
              ),
              ListRow(
                leading: const IconWell(Icons.palette_outlined),
                title: 'Look and notifications',
                subtitle: 'Theme, colour, currency',
                chevron: true,
                onTap: () => context.push(Routes.settingsSection('look')),
              ),
              ListRow(
                leading: const IconWell(Icons.help_outline_rounded),
                title: 'Help and about',
                subtitle: 'Tour, report a bug, version',
                chevron: true,
                onTap: () => context.push(Routes.settingsSection('help')),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          RowGroup(
            indent: ListRow.leadingInset,
            children: [
              ListRow(
                leading: IconWell(Icons.workspace_premium_outlined),
                title: 'Pulse Plus',
                subtitle: ref.watch(entitlementProvider).isPlus
                    ? 'On (test billing)'
                    : 'Niche card intel and AI summaries',
                chevron: true,
<<<<<<< HEAD
                onTap: () => context.push(Routes.household),
              ),
              ListRow(
                leading: const IconWell(Icons.people_outline_rounded),
                title: 'Family',
                subtitle: 'Members, invites and what each person shares',
                chevron: true,
                onTap: () => context.push(Routes.family),
              ),
              ListRow(
                leading: const IconWell(Icons.shield_outlined),
                title: 'Family vault',
                subtitle:
                    'Where things are, for the people who would need them',
                chevron: true,
                onTap: () => context.push(Routes.legacy),
              ),
            ],
          ),
          const SectionHeader('Automatic capture'),
          RowGroup(
            indent: ListRow.leadingInset,
            children: [
              ListRow(
                leading: const IconWell(Icons.mail_outline_rounded),
                title: 'Gmail statements',
                subtitle: !ref.watch(cloudAccessProvider).isReady
                    ? needsSignInTitle
                    : connected == null
                    ? 'Not connected'
                    : 'Connected · ${connected.email}',
                trailing: connected == null
                    ? TextAction(
                        'Connect',
                        onTap: () => connectGmail(context, ref),
                      )
                    : Icon(Icons.check_rounded, color: c.positive, size: 20),
              ),
              if (_android)
                ListRow(
                  leading: const IconWell(Icons.sms_outlined),
                  title: 'Bank SMS and wallet alerts',
                  subtitle: 'Permissions, status and what is read',
                  chevron: true,
                  onTap: () => showCaptureSetupSheet(context),
                )
              else
                ListRow(
                  leading: const IconWell(Icons.apple),
                  title: 'iPhone capture setup',
                  subtitle: ref
                      .watch(captureProgressProvider)
                      .maybeWhen(
                        data: (d) =>
                            '${d.length} of 4 working: Apple Pay, bank SMS, screenshots, shopping nudge',
                        orElse: () =>
                            'Apple Pay, bank SMS, screenshots, shopping nudge',
                      ),
                  chevron: true,
                  onTap: () => context.push(Routes.applePaySetup),
                ),
            ],
          ),
          const SectionHeader('Connected sources'),
          RowGroup(
            indent: ListRow.leadingInset,
            children: [
              ListRow(
                key: const Key('settings_email_receipts'),
                leading: const IconWell(Icons.receipt_long_outlined),
                title: 'Email receipts',
                subtitle: ref.watch(receiptSourceProvider).isConfigured
                    ? 'Off. Adds item details from noon, Talabat and Careem receipts, matched on this phone.'
                    : 'Off. Adds item details from noon, Talabat and Careem receipts. Not available yet.',
                trailing: Switch(
                  key: const Key('settings_email_receipts_switch'),
                  value: false,
                  // Disabled until a Gmail sign-in is configured.
                  onChanged: ref.watch(receiptSourceProvider).isConfigured
                      ? (_) {}
                      : null,
                ),
              ),
            ],
          ),
          const SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.md,
              Space.gutter,
              0,
            ),
            child: Segmented<ThemeMode>(
              segments: const {
                ThemeMode.system: 'System',
                ThemeMode.light: 'Light',
                ThemeMode.dark: 'Dark',
              },
              value: ref.watch(themeModeProvider),
              onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
            ),
          ),
          const SectionHeader('Explore'),
          RowGroup(
            indent: ListRow.leadingInset,
            children: [
              ListRow(
                key: const Key('settings_all_features'),
                leading: const IconWell(Icons.apps_rounded),
                title: 'All features',
                subtitle: 'Search everything the app can do',
                chevron: true,
                onTap: () => showAllFeaturesSheet(context),
              ),
              if (Env.sampleAllowed &&
                  ref.watch(startChoiceProvider) == StartChoice.sample)
                ListRow(
                  key: const Key('settings_sample_off'),
                  leading: const IconWell(Icons.auto_awesome_rounded),
                  title: 'Sample data is on',
                  subtitle: ref.watch(databaseHolderProvider) == null
                      ? 'Tap to switch to your own data'
                      : 'Your own data is showing',
                  onTap: () async {
                    final ok = await ref
                        .read(startChoiceProvider.notifier)
                        .choose(StartChoice.fresh);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Now showing your own data'
                              : 'Restart ${Env.appName} to use your own data',
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SectionHeader('Tour'),
          RowGroup(
            indent: ListRow.leadingInset,
            children: [
              ListRow(
                leading: const IconWell(Icons.play_circle_outline_rounded),
                title: 'Replay the tour',
                subtitle: 'Four short moments, about 20 seconds',
                chevron: true,
                onTap: () => context.push(Routes.tour),
              ),
              ListRow(
                key: const Key('replay_walkthroughs'),
                leading: const IconWell(Icons.tour_outlined),
                title: 'Replay walkthroughs',
                subtitle: 'Show the guide on every screen again',
                onTap: () async {
                  await ref.read(coachProgressProvider.notifier).resetAll();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Walkthroughs will show again on each screen',
                      ),
                    ),
                  );
                },
              ),
              ListRow(
                leading: const IconWell(Icons.lightbulb_outline_rounded),
                title: 'Reset tips',
                subtitle: 'Show the first-visit tip on each tab again',
                onTap: () async {
                  await ref.read(tourProgressProvider.notifier).resetTips();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tips will show again on each tab'),
                    ),
                  );
                },
              ),
            ],
          ),
          if (ref.watch(packTipsProvider).isNotEmpty) ...[
            const SectionHeader('Tips from Pulse'),
            RowGroup(
              children: [
                for (final t in ref.watch(packTipsProvider).take(5))
                  ListRow(
                    key: Key('pack_tip_${t.id}'),
                    leading: const IconWell(Icons.lightbulb_outline_rounded),
                    title: t.title,
                    subtitle: t.body,
                  ),
              ],
            ),
          ],
          const SectionHeader('Preferences'),
          RowGroup(
            children: [
              ListRow(
                dense: true,
                title: 'Currency',
                trailing: Text('AED', style: context.tt.bodyMedium),
              ),
              ListRow(
                dense: true,
                title: 'Notifications',
                trailing: Text(
                  'Due dates, budgets',
                  style: context.tt.bodyMedium,
                ),
              ),
              ListRow(
                dense: true,
                title: 'Face ID',
                trailing: Text('On', style: context.tt.bodyMedium),
              ),
            ],
          ),
          if (Env.demoData || !Env.useApi) ...[
            const SectionHeader('Demo'),
            RowGroup(
              indent: ListRow.leadingInset,
              children: [
                ListRow(
                  leading: IconWell(
                    Icons.contactless_outlined,
                    color: c.accent,
                  ),
                  title: 'Simulate a card tap',
                  subtitle: 'Shows the live rewards moment',
                  onTap: () => simulateCardTap(context, ref),
                ),
              ],
            ),
          ],
          const SectionHeader('Beta tools'),
          RowGroup(
            indent: ListRow.leadingInset,
            children: [
              ListRow(
                key: const Key('settings_shake_row'),
                leading: const IconWell(Icons.vibration_rounded),
                title: 'Shake to report a bug',
                subtitle: 'Shake your phone to send feedback with a screenshot',
                trailing: Switch(
                  key: const Key('settings_shake_switch'),
                  value: ref.watch(shakeEnabledProvider),
                  onChanged: (v) =>
                      ref.read(shakeEnabledProvider.notifier).set(v),
                ),
              ),
              ListRow(
                key: const Key('settings_report_bug'),
                leading: const IconWell(Icons.bug_report_outlined),
                title: 'Report a bug',
                subtitle: 'For when shaking is not an option',
                chevron: true,
                onTap: () =>
                    ref.read(bugReportLauncherProvider).launch('settings'),
              ),
            ],
          ),
          const SectionHeader('About'),
          RowGroup(
            children: [
              ListRow(
                dense: true,
                title: '${Env.appName} beta',
                trailing: Text(
                  'Friends & family',
                  style: context.tt.bodyMedium,
                ),
              ),
              ListRow(
                dense: true,
                title: 'Analytics',
                trailing: Text(
                  Env.hasPosthog && ref.watch(privacyControllerProvider).sharing
                      ? 'PostHog'
                      : 'Off',
                  style: context.tt.bodyMedium,
                ),
=======
                onTap: () => context.push(Routes.plus),
>>>>>>> origin/main
              ),
            ],
          ),
          const SizedBox(height: Space.xxl),
          Center(
            child: TextAction(
              'Sign out',
              color: c.negative,
              onTap: () => ref.read(sessionProvider).signOut(),
            ),
          ),
        ],
      ),
    );
  }
}
