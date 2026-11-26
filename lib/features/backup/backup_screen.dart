import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/cloud_access.dart';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../backup/backup_controller.dart';
import '../../backup/backup_providers.dart';
import '../../backup/backup_state.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import 'backup_widgets.dart';

/// Settings > Backup: status, destination, schedule, passphrase, export,
/// delete.
class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key, this.now});

  /// Fixed clock for tests and screenshots.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(backupStateProvider);
    final c = context.pc;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.popOrHome(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.xxxl),
        children: [
          s.enabled
              ? _Enabled(state: s, now: now ?? DateTime.now())
              : const _Intro(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.xl,
              Space.gutter,
              0,
            ),
            child: Text(
              'Only you can read your backup. Pulse stores scrambled data that it cannot open. '
              'If you forget your passphrase and lose your recovery phrase, nobody, including us, can recover it.',
              style: context.tt.bodySmall!.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, size: 40, color: c.accent),
              const SizedBox(height: Space.lg),
              Text(
                'Never lose your data when you change phones',
                style: context.tt.headlineSmall,
              ),
              const SizedBox(height: Space.sm),
              Text(
                'Your money data lives on this phone. Turn on encrypted backup and a new phone can bring everything back, photos included.',
                style: context.tt.bodyMedium,
              ),
              const SizedBox(height: Space.xl),
              Consumer(
                builder: (context, ref, _) => PrimaryButton(
                  label: 'Turn on encrypted backup',
                  icon: Icons.lock_rounded,
                  onPressed: () => context.push(Routes.backupSetup),
                ),
              ),
            ],
          ),
        ),
        const SectionHeader('How it works'),
        const RowGroup(
          indent: ListRow.leadingInset,
          children: [
            ListRow(
              leading: IconWell(Icons.key_rounded),
              title: 'You hold the key',
              subtitle: 'A recovery phrase or passphrase that only you know. It never leaves your control.',
            ),
            ListRow(
              leading: IconWell(Icons.enhanced_encryption_outlined),
              title: 'Encrypted on this phone',
              subtitle: 'Data is scrambled before it is uploaded. The server only ever holds ciphertext.',
            ),
            ListRow(
              leading: IconWell(Icons.phonelink_setup_rounded),
              title: 'Restore on any phone',
              subtitle: 'Choose "Restore from backup" when you set up Pulse, then enter your phrase.',
            ),
          ],
        ),
      ],
    );
  }
}

class _Enabled extends ConsumerWidget {
  const _Enabled({required this.state, required this.now});
  final BackupState state;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final ctl = ref.read(backupControllerProvider);
    final s = state;
    final failing = s.lastError != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (failing ? c.warning : c.positive).withValues(
                        alpha: 0.14,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      s.running
                          ? Icons.cloud_upload_outlined
                          : failing
                          ? Icons.cloud_off_outlined
                          : Icons.cloud_done_outlined,
                      color: failing ? c.warning : c.positive,
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.running
                              ? 'Backing up...'
                              : s.destination == BackupDestination.file
                              ? 'File backup'
                              : (failing ? 'Waiting to back up' : 'Backed up'),
                          style: context.tt.titleLarge,
                        ),
                        Text(
                          s.destination == BackupDestination.file &&
                                  s.lastSuccess == null
                              ? 'Export a file whenever you like'
                              : backedUpAgo(s.lastSuccess, now),
                          style: context.tt.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (s.running) ...[
                const SizedBox(height: Space.lg),
                Meter(value: s.progress, color: c.accent),
              ],
              if (failing && s.cloud) ...[
                const SizedBox(height: Space.lg),
                Callout(
                  warning: true,
                  icon: Icons.info_outline_rounded,
                  title: s.needsAttention(now)
                      ? 'Your backup is behind'
                      : 'Last attempt did not finish',
                  text:
                      '${s.lastError}${s.needsAttention(now) ? ' Your data is safe on this phone.' : ''}',
                ),
              ],
              if (s.cloud) ...[
                const SizedBox(height: Space.lg),
                PrimaryButton(
                  label: 'Back up now',
                  icon: Icons.backup_outlined,
                  loading: s.running,
                  onPressed: () async {
                    await ctl.backupNow();
                    if (context.mounted && ctl.state.lastError == null)
                      backupToast(context, 'Backed up');
                  },
                ),
              ],
            ],
          ),
        ),
        const SectionHeader('Where it goes'),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [
            _dest(
              context,
              icon: Icons.cloud_outlined,
              title: 'Pulse cloud',
              subtitle: ctl.cloudAvailable
                  ? 'Encrypted, in your private storage'
                  : needsSignInTitle,
              selected: s.destination == BackupDestination.cloud,
              onTap: ctl.cloudAvailable
                  ? () => _setDestination(context, ctl, BackupDestination.cloud)
                  : null,
            ),
            _dest(
              context,
              icon: Icons.insert_drive_file_outlined,
              title: 'Backup file only',
              subtitle: 'No upload. You export the encrypted file yourself.',
              selected: s.destination == BackupDestination.file,
              onTap: () =>
                  _setDestination(context, ctl, BackupDestination.file),
            ),
            const ListRow(
              leading: IconWell(Icons.add_to_drive_outlined),
              title: 'Google Drive',
              subtitle: 'Needs setup, not available in this build',
            ),
            const ListRow(
              leading: IconWell(Icons.cloud_circle_outlined),
              title: 'iCloud Drive',
              subtitle: 'Needs setup, not available in this build',
            ),
          ],
        ),
        if (s.destination == BackupDestination.cloud) ...[
          const SectionHeader('Automatic'),
          RowGroup(
            indent: ListRow.leadingInset,
            children: [
              ListRow(
                leading: const IconWell(Icons.autorenew_rounded),
                title: 'Back up automatically',
                subtitle: 'Shortly after changes, and once a day',
                trailing: Switch(value: s.auto, onChanged: ctl.setAuto),
              ),
              ListRow(
                leading: const IconWell(Icons.wifi_rounded),
                title: 'Wi-Fi only',
                subtitle: 'Saves your mobile data',
                trailing: Switch(value: s.wifiOnly, onChanged: ctl.setWifiOnly),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.md,
              Space.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep the last ${s.keep} versions',
                  style: context.tt.bodyMedium!.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: Space.sm),
                Segmented<int>(
                  segments: const {3: '3', 5: '5', 10: '10'},
                  value: const [3, 5, 10].contains(s.keep) ? s.keep : 5,
                  onChanged: ctl.setKeep,
                ),
              ],
            ),
          ),
        ],
        const SectionHeader('Your key'),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [
            ListRow(
              leading: const IconWell(Icons.key_rounded),
              title: 'Change passphrase',
              subtitle: s.secretKind == 'phrase'
                  ? 'Using a recovery phrase'
                  : 'Using your own passphrase',
              chevron: true,
              onTap: () => context.push('${Routes.backupSetup}?change=1'),
            ),
            ListRow(
              leading: const IconWell(Icons.ios_share_rounded),
              title: 'Export encrypted file',
              subtitle: 'Keep a copy anywhere: Files, email, another cloud',
              chevron: true,
              onTap: () => _export(context, ctl),
            ),
          ],
        ),
        const SectionHeader('Danger zone'),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [
            if (s.destination == BackupDestination.cloud)
              ListRow(
                leading: IconWell(
                  Icons.delete_outline_rounded,
                  color: c.negative,
                ),
                title: 'Delete cloud backup',
                titleStyle: context.tt.bodyLarge!.copyWith(color: c.negative),
                subtitle: 'Removes every stored version and turns backup off',
                onTap: () => _confirmDelete(context, ctl, cloud: true),
              ),
            ListRow(
              leading: const IconWell(Icons.power_settings_new_rounded),
              title: 'Turn off backup',
              subtitle:
                  'Stops backing up. Existing backups stay where they are.',
              onTap: () => _confirmDelete(context, ctl, cloud: false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dest(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    final c = context.pc;
    return ListRow(
      leading: IconWell(icon, color: selected ? c.accent : null),
      title: title,
      subtitle: subtitle,
      trailing: selected
          ? Icon(Icons.check_rounded, color: c.accent, size: 20)
          : null,
      onTap: onTap,
    );
  }

  Future<void> _setDestination(
    BuildContext context,
    BackupController ctl,
    BackupDestination d,
  ) async {
    try {
      await ctl.setDestination(d);
    } catch (e) {
      if (context.mounted) {
        backupToast(
          context,
          e.toString().contains('already has a backup')
              ? 'This account already has a different backup. Delete it first to use it with this one.'
              : 'Could not switch just now. Try again in a moment.',
        );
      }
    }
  }

  Future<void> _export(BuildContext context, BackupController ctl) async {
    try {
      final path = await ctl.exportArchive();
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], subject: 'Pulse encrypted backup'),
      );
    } on UnsupportedError {
      if (context.mounted)
        backupToast(context, 'Export needs the iOS or Android app.');
    } catch (_) {
      if (context.mounted)
        backupToast(
          context,
          'Could not create the file. Try again in a moment.',
        );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    BackupController ctl, {
    required bool cloud,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(cloud ? 'Delete your cloud backup?' : 'Turn off backup?'),
        content: Text(
          cloud
              ? 'Every stored version is permanently deleted and backup is turned off. Your data on this phone is not touched. This cannot be undone.'
              : 'Pulse stops backing up and forgets the key on this phone. Existing backups stay where they are, and you still need your passphrase to restore them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(cloud ? 'Delete' : 'Turn off'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      cloud ? await ctl.deleteCloudBackup() : await ctl.disable();
    } catch (_) {
      if (context.mounted)
        backupToast(
          context,
          'Could not finish just now. Try again in a moment.',
        );
    }
  }
}
