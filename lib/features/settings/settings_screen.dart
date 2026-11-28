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
            indent: ListRow.leadingInset,
            children: [
              ListRow(
                key: const Key('settings_connections'),
                leading: IconWell(Icons.power_outlined, color: c.accent),
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
                leading: IconWell(
                  Icons.workspace_premium_outlined,
                  color: context.pc.accent,
                ),
                title: 'Pulse Plus',
                subtitle: ref.watch(entitlementProvider).isPlus
                    ? 'On (test billing)'
                    : 'Niche card intel and AI summaries',
                chevron: true,
                onTap: () => context.push(Routes.plus),
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
