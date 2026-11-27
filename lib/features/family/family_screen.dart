import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/household_service.dart';
import '../../data/phone.dart';
import '../../household/household_providers.dart';
import '../household/household_common.dart';
import 'pending_invites.dart';

void _toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// Invites still waiting for the person to join. Invites that the joined
/// members answer are dropped here, so the list never lies.
final pendingInviteListProvider = FutureProvider<List<PendingInvite>>((
  ref,
) async {
  final j = await ref.watch(jointDataProvider.future);
  final store = ref.watch(pendingInvitesProvider);
  if (j != null) {
    await store.dropJoined([
      for (final m in j.members)
        if (m.id != j.me) m.name,
    ]);
  }
  return store.all();
});

/// What goes into the message: the household code and how to use it. The
/// code is the key to the household, so it only ever travels through the app
/// you pick (WhatsApp, Messages), never through Pulse's servers.
String inviteMessage({required String name, required String code}) =>
    'Hi $name, I would like us to plan money together on Pulse. '
    'Install Pulse, open Settings > Household > Join with a code, and paste this:\n\n'
    '$code\n\n'
    'It opens what we share, so keep it between us.';

/// The code for this phone's household, creating the household first when
/// there is none. Null when this phone has no key (restored from a backup).
Future<String?> _codeFor(WidgetRef ref, {String? myName}) async {
  final svc = ref.read(householdServiceProvider);
  if (await svc.config() == null) {
    await svc.create(householdName: 'Our household', myName: myName ?? 'Me');
    invalidateHousehold(ref);
  }
  return svc.inviteCode();
}

Future<void> _shareInvite({
  required String name,
  required String code,
  String? phone,
  bool whatsapp = false,
}) async {
  final text = inviteMessage(name: name, code: code);
  if (whatsapp && phone != null) {
    final uri = Uri.parse(
      'https://wa.me/${phone.replaceFirst('+', '')}?text=${Uri.encodeComponent(text)}',
    );
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on Object {
      // fall through to the share sheet
    }
  }
  await SharePlus.instance.share(
    ShareParams(text: text, subject: 'Join my Pulse household'),
  );
}

/// Members of your household and the people you have invited.
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joint = ref.watch(jointDataProvider);
    final pending = ref.watch(pendingInviteListProvider).value ?? const [];
    void invite() => showPulseSheet<void>(
      context,
      builder: (_) => InviteSheet(hasHousehold: joint.value != null),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.popOrHome(),
        ),
        actions: [
          IconButton(
            tooltip: 'Invite',
            icon: const Icon(Icons.person_add_alt_rounded),
            onPressed: invite,
          ),
        ],
      ),
      body: AsyncView<JointData?>(
        value: joint,
        onRetry: () => ref.invalidate(jointDataProvider),
        builder: (j) => _Body(
          joint: j,
          pending: pending,
          onInvite: () => showPulseSheet<void>(
            context,
            builder: (_) => InviteSheet(hasHousehold: j != null),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.joint,
    required this.pending,
    required this.onInvite,
  });
  final JointData? joint;
  final List<PendingInvite> pending;
  final VoidCallback onInvite;

  Future<void> _again(
    BuildContext context,
    WidgetRef ref,
    PendingInvite p,
  ) async {
    final code = await ref.read(householdServiceProvider).inviteCode();
    if (!context.mounted) return;
    if (code == null) {
      _toast(context, 'This phone needs a new household code first.');
      return;
    }
    await _shareInvite(name: p.name, code: code, phone: p.phone);
  }

  Future<void> _cancel(WidgetRef ref, PendingInvite p) async {
    await ref.read(pendingInvitesProvider).cancel(p.id);
    ref.invalidate(pendingInviteListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final j = joint;
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxxl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            0,
          ),
          child: Text(
            'Invite someone by sending them a code yourself, on WhatsApp or '
            'Messages. Each person decides what they share.',
            style: context.tt.bodyMedium,
          ),
        ),
        const SectionHeader('Members'),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [
            if (j == null)
              ListRow(
                key: const Key('family_just_you'),
                leading: const MemberAvatar('You', me: true),
                title: 'Just you so far',
                subtitle: 'Invite someone to share a budget',
              )
            else
              for (final m in j.members)
                ListRow(
                  key: Key('family_member_${m.name}'),
                  leading: MemberAvatar(m.name, me: m.id == j.me),
                  title: m.id == j.me ? '${m.name} (you)' : m.name,
                  subtitle: m.id == j.me ? 'In your household' : 'Joined',
                ),
            ListRow(
              key: const Key('family_invite'),
              leading: IconWell(Icons.add_rounded, color: c.accent),
              title: 'Invite someone',
              titleStyle: context.tt.bodyLarge!.copyWith(color: c.accent),
              onTap: onInvite,
            ),
          ],
        ),
        if (pending.isNotEmpty) ...[
          const SectionHeader('Waiting to join'),
          RowGroup(
            indent: ListRow.leadingInset,
            children: [
              for (final p in pending)
                ListRow(
                  key: Key('pending_${p.id}'),
                  leading: MemberAvatar(p.name),
                  title: p.name,
                  subtitle: '${p.relation} · code shared, not joined yet',
                  subtitleColor: c.warning,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextAction(
                        'Share again',
                        key: Key('pending_again_${p.id}'),
                        onTap: () => unawaited(_again(context, ref, p)),
                      ),
                      const SizedBox(width: Space.md),
                      TextAction(
                        'Cancel',
                        key: Key('pending_cancel_${p.id}'),
                        color: c.textTertiary,
                        onTap: () => unawaited(_cancel(ref, p)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.gutter,
              0,
            ),
            child: Text(
              'Pulse cannot see who opened your message. Cancel removes the '
              'note here; to stop a code working, change the household code.',
              style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
            ),
          ),
        ],
        const SectionHeader('More'),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [
            ListRow(
              leading: const IconWell(Icons.home_outlined),
              title: 'Household',
              subtitle: 'What you share, shared bills, change the code',
              chevron: true,
              onTap: () => context.push(Routes.household),
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
      ],
    );
  }
}

/// Invite someone: pick the app to send it with, and Pulse notes who is
/// waiting. Sending the same person twice does not add a second row.
class InviteSheet extends ConsumerStatefulWidget {
  const InviteSheet({super.key, required this.hasHousehold});
  final bool hasHousehold;
  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _me = TextEditingController();
  String _relation = 'Partner';
  bool _busy = false;
  static const _relations = ['Partner', 'Parent', 'Child', 'Sibling', 'Other'];

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _me.dispose();
    super.dispose();
  }

  bool get _phoneOk => _phone.text.trim().isNotEmpty && toE164(_phone.text) != null;
  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (_phone.text.trim().isEmpty || _phoneOk) &&
      (widget.hasHousehold || _me.text.trim().isNotEmpty);

  Future<void> _send({required bool whatsapp}) async {
    setState(() => _busy = true);
    final name = _name.text.trim();
    try {
      final code = await _codeFor(ref, myName: _me.text.trim());
      if (!mounted) return;
      if (code == null) {
        _toast(context, 'This phone needs a new household code first. Open Household.');
        return;
      }
      final r = await ref
          .read(pendingInvitesProvider)
          .add(name: name, relation: _relation, phoneInput: _phone.text);
      ref.invalidate(pendingInviteListProvider);
      Haptics.success();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final phone = r.invite.phone;
      Navigator.of(context).pop();
      if (r.alreadyPending) {
        messenger.showSnackBar(
          SnackBar(content: Text('${r.invite.name} is already invited. Sharing the code again.')),
        );
      }
      await _shareInvite(name: r.invite.name, code: code, phone: phone, whatsapp: whatsapp);
    } on Object catch (e) {
      if (mounted) _toast(context, 'Could not prepare the invite. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Invite to household',
      subtitle: 'You send the code yourself. They choose what to share once they join.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.hasHousehold) ...[
            TextField(
              key: const Key('invite_myname'),
              controller: _me,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Your first name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Space.md),
          ],
          TextField(
            key: const Key('invite_name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Their name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            key: const Key('invite_phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            ],
            decoration: const InputDecoration(
              hintText: 'Mobile, to open WhatsApp (optional)',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.lg),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final r in _relations)
                Pill(
                  r,
                  selected: r == _relation,
                  onTap: () => setState(() => _relation = r),
                ),
            ],
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            key: const Key('invite_share'),
            label: 'Share invite',
            icon: Icons.ios_share_rounded,
            loading: _busy,
            onPressed: _valid ? () => _send(whatsapp: false) : null,
          ),
          if (_phoneOk) ...[
            const SizedBox(height: Space.sm),
            PrimaryButton(
              key: const Key('invite_whatsapp'),
              label: 'Send on WhatsApp',
              secondary: true,
              onPressed: _valid && !_busy ? () => _send(whatsapp: true) : null,
            ),
          ],
        ],
      ),
    );
  }
}
