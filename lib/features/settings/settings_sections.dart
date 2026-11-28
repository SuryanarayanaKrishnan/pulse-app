import 'salary_sheet.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../backup/backup_providers.dart';
import '../../bugreport/launcher.dart';
import '../../bugreport/settings.dart';
import '../../backup/backup_state.dart';
import '../../household/household_providers.dart';
import '../../sync/sync_providers.dart';
import '../sync/sync_screen.dart';
import '../../core/analytics/privacy_controller.dart';
import '../../core/env/env.dart';
import '../../core/router/router.dart';
import '../../core/theme/mood.dart';
import '../../core/theme/theme_mode.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../cards/digit_widgets.dart';
import '../cards/upsell_widgets.dart';
import '../../data/card_upsell_providers.dart';
import '../rewards/reward_moment.dart';
import '../coach/coach_progress.dart';
import '../discover/all_features_sheet.dart';
import '../onboarding/start_choice.dart';
import '../tour/tour_progress.dart';

String _ordinal(int d) => (d % 100 >= 11 && d % 100 <= 13)
    ? 'th'
    : switch (d % 10) {
        1 => 'st',
        2 => 'nd',
        3 => 'rd',
        _ => 'th',
      };

/// A settings sub-page: a title and a few grouped rows.
class _Page extends StatelessWidget {
  const _Page(this.title, this.children);
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => context.popOrHome(Routes.settings),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.only(bottom: Space.xxxl),
      children: children,
    ),
  );
}

/// Opens one of the settings groups by name (`/settings/:section`).
class SettingsSectionScreen extends StatelessWidget {
  const SettingsSectionScreen(this.section, {super.key});
  final String section;
  @override
  Widget build(BuildContext context) => switch (section) {
    'money' => const MoneySettings(),
    'family' => const FamilySettings(),
    'data' => const DataSettings(),
    'look' => const LookSettings(),
    _ => const HelpSettings(),
  };
}

class MoneySettings extends ConsumerWidget {
  const MoneySettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final rules = ref.watch(rulesProvider).value;
    final statements = ref.watch(statementsProvider).value;
    final attention = statements?.where((s) => s.needsAttention).length ?? 0;
    return _Page('Money', [
      if (ref.watch(dismissedDigitsProvider).isNotEmpty) ...[
        const SectionHeader('Card digits you skipped'),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [
            for (final d in ref.watch(dismissedDigitsProvider).toList()..sort())
              ListRow(
                leading: const IconWell(Icons.undo_rounded),
                title: 'Ask again about ••$d',
                subtitle: 'You said these alerts are not yours',
                onTap: () {
                  ref.read(dismissedDigitsProvider.notifier).restore(d);
                  ref.invalidate(digitSuggestionsProvider);
                },
              ),
          ],
        ),
      ],
      if ((ref.watch(dismissedUpsellsProvider).value ?? const <String>{})
          .isNotEmpty) ...[
        const SectionHeader('Card suggestions'),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [
            ListRow(
              key: const Key('settings_hidden_suggestions'),
              leading: const IconWell(Icons.undo_rounded),
              title: 'Hidden card suggestions',
              subtitle:
                  '${ref.watch(dismissedUpsellsProvider).value!.length} hidden. Tap to show any again.',
              chevron: true,
              onTap: () => showHiddenSuggestions(context),
            ),
          ],
        ),
      ],
      const SectionHeader('Money'),
      RowGroup(
        indent: ListRow.leadingInset,
        children: [
          ListRow(
            leading: const IconWell(Icons.category_outlined),
            title: 'Categories & budgets',
            chevron: true,
            onTap: () => context.push(Routes.categories),
          ),
          ListRow(
            key: const Key('settings_salary'),
            leading: const IconWell(Icons.payments_outlined),
            title: 'Salary',
            subtitle: switch (ref.watch(manualSalaryProvider).value) {
              final s? =>
                '${Money.aed(s.amountMinor / 100, decimals: s.amountMinor % 100 != 0)} on the ${s.day}${_ordinal(s.day)}',
              null => 'Set it by hand, or we find it in your bank alerts',
            },
            chevron: true,
            onTap: () => showPulseSheet<void>(
              context,
              builder: (_) =>
                  SalarySheet(current: ref.read(manualSalaryProvider).value),
            ),
          ),
          ListRow(
            leading: const IconWell(Icons.auto_mode_rounded),
            title: 'Automations',
            subtitle: rules == null
                ? null
                : '${rules.length} ${rules.length == 1 ? 'rule' : 'rules'}',
            chevron: true,
            onTap: () => context.push(Routes.automations),
          ),
          ListRow(
            leading: const IconWell(Icons.fact_check_outlined),
            title: 'Monthly close',
            subtitle: statements == null
                ? null
                : (attention == 0
                      ? 'All statements match'
                      : '$attention need you'),
            subtitleColor: attention == 0 ? null : c.warning,
            chevron: true,
            onTap: () => context.push(Routes.statements),
          ),
        ],
      ),
    ]);
  }
}

class DataSettings extends ConsumerWidget {
  const DataSettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final backup = ref.watch(backupStateProvider);
    final sync = ref.watch(syncStatusProvider);
    return _Page('Backup and devices', [
      const SectionHeader('Your data'),
      RowGroup(
        indent: ListRow.leadingInset,
        children: [
          ListRow(
            leading: const IconWell(Icons.cloud_done_outlined),
            title: 'Backup',
            subtitle: backup.enabled
                ? (backup.destination == BackupDestination.file
                      ? 'File only, encrypted'
                      : backedUpAgo(backup.lastSuccess, DateTime.now()))
                : 'Keep your data safe when you change phones',
            subtitleColor: backup.cloud && backup.needsAttention(DateTime.now())
                ? c.warning
                : null,
            chevron: true,
            onTap: () => context.push(Routes.backup),
          ),
          ListRow(
            leading: const IconWell(Icons.sync_rounded),
            title: 'Sync devices',
            subtitle: syncSubtitle(sync, DateTime.now()),
            subtitleColor: sync.lastError != null ? c.warning : null,
            chevron: true,
            onTap: () => context.push(Routes.sync),
          ),
        ],
      ),
    ]);
  }
}

class FamilySettings extends ConsumerWidget {
  const FamilySettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(jointDataProvider).value;
    return _Page('Family and household', [
      const SectionHeader('Household'),
      RowGroup(
        indent: ListRow.leadingInset,
        children: [
          ListRow(
            key: const Key('settings_household'),
            leading: const IconWell(Icons.home_outlined),
            title: 'Household',
            subtitle: household == null
                ? 'Plan money together, privately'
                : '${household.config.name} · ${household.members.length} ${household.members.length == 1 ? 'member' : 'members'}',
            chevron: true,
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
            subtitle: 'Where things are, for the people who would need them',
            chevron: true,
            onTap: () => context.push(Routes.legacy),
          ),
        ],
      ),
    ]);
  }
}

class LookSettings extends ConsumerWidget {
  const LookSettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Page('Look and notifications', [
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
      Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          Space.md,
          Space.gutter,
          0,
        ),
        child: Segmented<MoodPreference>(
          key: const Key('settings_mood'),
          segments: const {
            MoodPreference.auto: 'Auto',
            MoodPreference.sage: 'Sage',
            MoodPreference.stone: 'Stone',
          },
          value: ref.watch(moodPreferenceProvider),
          onChanged: (m) => ref.read(moodPreferenceProvider.notifier).set(m),
        ),
      ),
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
            trailing: Text('Due dates, budgets', style: context.tt.bodyMedium),
          ),
          ListRow(
            dense: true,
            title: 'Face ID',
            trailing: Text('On', style: context.tt.bodyMedium),
          ),
        ],
      ),
    ]);
  }
}

class HelpSettings extends ConsumerWidget {
  const HelpSettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Page('Help and about', [
      const SectionHeader('Explore'),
      RowGroup(
        indent: ListRow.leadingInset,
        children: [
          ListRow(
            key: const Key('settings_all_features'),
            leading: const IconWell(Icons.apps_rounded),
            title: 'Search',
            subtitle: 'Find any screen, setting, card or payment',
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
                  content: Text('Walkthroughs will show again on each screen'),
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
      if (Env.demoData || !Env.useApi) ...[
        const SectionHeader('Demo'),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [
            ListRow(
              leading: IconWell(Icons.contactless_outlined),
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
              onChanged: (v) => ref.read(shakeEnabledProvider.notifier).set(v),
            ),
          ),
          ListRow(
            key: const Key('settings_report_bug'),
            leading: const IconWell(Icons.bug_report_outlined),
            title: 'Report a bug',
            subtitle: 'For when shaking is not an option',
            chevron: true,
            onTap: () => ref.read(bugReportLauncherProvider).launch('settings'),
          ),
        ],
      ),
      const SectionHeader('About'),
      RowGroup(
        children: [
          ListRow(
            dense: true,
            title: '${Env.appName} beta',
            trailing: Text('Friends & family', style: context.tt.bodyMedium),
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
          ),
        ],
      ),
    ]);
  }
}
