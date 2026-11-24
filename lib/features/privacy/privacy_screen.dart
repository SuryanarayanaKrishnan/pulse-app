import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/analytics/event_schema.dart';
import '../../core/analytics/privacy_controller.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../backup/backup_widgets.dart';

/// Settings > Privacy. Plain words; the event list below is generated from
/// [AnalyticsSchema], the same list the code enforces.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = ref.watch(privacyControllerProvider);
    final c = context.pc;
    final small = context.tt.bodySmall!.copyWith(color: c.textSecondary);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListenableBuilder(
        listenable: privacy,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: Space.xxxl),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.sm, Space.gutter, 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your money stays yours', style: context.tt.headlineSmall),
                  const SizedBox(height: Space.sm),
                  Text(
                    'Pulse can share a few anonymous facts about how the app is used, '
                    'so we can fix what is confusing. It is off unless you turn it on, '
                    'and you can change your mind at any time.',
                    style: context.tt.bodyMedium,
                  ),
                ],
              ),
            ),
            const SectionHeader('Anonymous usage'),
            RowGroup(
              indent: ListRow.leadingInset,
              children: [
                ListRow(
                  leading: const IconWell(Icons.insights_outlined),
                  title: 'Share anonymous usage',
                  subtitle: privacy.sharing
                      ? 'On. Thank you.'
                      : (privacy.asked ? 'Off' : 'Off until you choose'),
                  trailing: Switch(
                    value: privacy.sharing,
                    onChanged: (v) => privacy.setSharing(v),
                  ),
                ),
                if (privacy.sharing)
                  ListRow(
                    leading: const IconWell(Icons.tag_rounded),
                    title: 'Your anonymous id',
                    subtitle:
                        'A random code starting ${_short(privacy.installId)}. '
                        'It changes on its own every few months.',
                    trailing: TextAction(
                      'Reset anonymous id',
                      onTap: () => privacy.resetId(),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.md, Space.gutter, 0,
              ),
              child: Text(
                'The id is made up at random. It is not linked to your account, '
                'your phone or your name, and it is deleted when you turn this off.',
                style: small,
              ),
            ),
            const SectionHeader('Never shared, whatever you choose'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Space.gutter),
              child: Callout(
                icon: Icons.lock_outline_rounded,
                title: 'Never',
                text:
                    'Amounts, merchants, names, contacts or message text. '
                    'Not even a rounded amount. Only fixed choices and rough buckets, '
                    'like "a small sync" or "wrong card".',
              ),
            ),
            const SectionHeader('Where your data lives'),
            RowGroup(
              indent: ListRow.leadingInset,
              children: const [
                ListRow(
                  leading: IconWell(Icons.phone_iphone_rounded),
                  title: 'On this phone',
                  subtitle:
                      'Your payments, cards, budgets and splits are kept in an encrypted database here. '
                      'Your choice on this page and the anonymous id are stored here too.',
                ),
                ListRow(
                  leading: IconWell(Icons.cloud_done_outlined),
                  title: 'Synced, encrypted',
                  subtitle:
                      'If you turn on backup or sync, your data is scrambled on the phone '
                      'with a key only you hold, before it is uploaded. We cannot read it.',
                ),
              ],
            ),
            const SectionHeader('Exactly what is shared when this is on'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: Text(
                'This list is built from the same rules the app enforces. '
                'Anything not on it is never sent.',
                style: small,
              ),
            ),
            for (final g in AnalyticsSchema.grouped.entries) ...[
              SectionHeader(g.key, top: Space.xl),
              RowGroup(
                children: [for (final e in g.value) _EventRow(e)],
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter, Space.xl, Space.gutter, 0,
              ),
              child: Text(
                'We also note which main screens are opened (for example Home or Cards), '
                'never a screen that carries a name or an id.',
                style: small,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _short(String? id) =>
      id == null || id.length < 6 ? '...' : '${id.substring(0, 6)}...';
}

class _EventRow extends StatelessWidget {
  const _EventRow(this.spec);
  final EventSpec spec;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final sub = context.tt.bodySmall!.copyWith(color: c.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.gutter, vertical: Space.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            spec.name,
            style: context.tt.titleSmall!.copyWith(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 2),
          Text(
            spec.oncePerInstall ? '${spec.what} Sent once.' : spec.what,
            style: context.tt.bodyMedium,
          ),
          const SizedBox(height: Space.xs),
          if (spec.props.isEmpty)
            Text('Contains: nothing else.', style: sub)
          else
            for (final p in spec.props.entries)
              Text('${p.key}: ${p.value.description}, ${p.value.shape}', style: sub),
        ],
      ),
    );
  }
}
