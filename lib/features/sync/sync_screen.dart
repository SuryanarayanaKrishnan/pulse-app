import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../sync/sync_providers.dart';
import '../../sync/sync_service.dart';
import '../backup/backup_widgets.dart';

/// "Synced 3 min ago" style line shared by the screen and the Settings row.
String syncedAgo(DateTime? last, DateTime now) {
  if (last == null) return 'Not synced yet';
  final d = now.difference(last);
  if (d.inSeconds < 60) return 'Synced just now';
  if (d.inMinutes < 60) return 'Synced ${d.inMinutes} min ago';
  if (d.inHours < 24) return 'Synced ${d.inHours} h ago';
  return 'Synced ${d.inDays} d ago';
}

/// One-line status for the Settings row.
String syncSubtitle(SyncStatus s, DateTime now) {
  if (!s.available) return 'Turn on encrypted backup to sync your devices';
  if (s.running) return 'Syncing...';
  if (!s.enabled) return 'Off';
  if (s.lastError != null) return s.lastError!;
  return syncedAgo(s.lastSuccess, now);
}

/// Settings > Sync devices: switch, status, "Sync now".
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key, this.now});
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(syncStatusProvider);
    final svc = ref.read(syncServiceProvider);
    final c = context.pc;
    final failing = s.lastError != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync devices'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.xxxl),
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
                Text(
                  'Keep every phone up to date',
                  style: context.tt.headlineSmall,
                ),
                const SizedBox(height: Space.sm),
                Text(
                  'Changes you make here show up on your other devices, and theirs here. '
                  'Everything is scrambled on the phone before it is uploaded, with the same key as your backup.',
                  style: context.tt.bodyMedium,
                ),
                const SizedBox(height: Space.lg),
                if (!s.available)
                  const Callout(
                    icon: Icons.lock_outline_rounded,
                    title: 'Backup comes first',
                    text: 'Sync uses your backup recovery key. Turn on encrypted backup (signed in), then come back.',
                  )
                else ...[
                  Text(
                    s.running
                        ? 'Syncing...'
                        : syncedAgo(s.lastSuccess, now ?? DateTime.now()),
                    style: context.tt.titleLarge,
                  ),
                  if (s.lastSuccess != null && !failing && !s.running)
                    Text(
                      'Sent ${s.lastSent}, received ${s.lastReceived} change${s.lastReceived == 1 ? '' : 's'} last time',
                      style: context.tt.bodySmall!.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  if (failing) ...[
                    const SizedBox(height: Space.md),
                    Callout(
                      warning: true,
                      icon: Icons.info_outline_rounded,
                      title: 'Last attempt did not finish',
                      text: '${s.lastError}',
                    ),
                  ],
                  const SizedBox(height: Space.lg),
                  PrimaryButton(
                    label: 'Sync now',
                    icon: Icons.sync_rounded,
                    loading: s.running,
                    onPressed: () => svc?.syncNow(),
                  ),
                ],
              ],
            ),
          ),
          if (s.available) ...[
            const SectionHeader('Automatic'),
            RowGroup(
              indent: ListRow.leadingInset,
              children: [
                ListRow(
                  leading: const IconWell(Icons.devices_rounded),
                  title: 'Keep devices in sync',
                  subtitle: 'After changes and when you open Pulse',
                  trailing: Switch(
                    value: s.enabled,
                    onChanged: (v) => svc?.setEnabled(v),
                  ),
                ),
              ],
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.xl,
              Space.gutter,
              0,
            ),
            child: Text(
              'Not synced: photos and document files (they stay on the phone that added them), '
              'raw messages, and caches. If two devices change the same field, the later change wins.',
              style: context.tt.bodySmall!.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
