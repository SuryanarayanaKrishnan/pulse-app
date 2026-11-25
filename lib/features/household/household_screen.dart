import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/engine/dates.dart';
import '../../core/household/household_engine.dart';
import '../../core/household/household_models.dart';
import '../../core/router/router.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/household_service.dart';
import '../../household/household_providers.dart';
import '../goals/goal_widgets.dart' show aedMinor;
import '../categories/category_picker.dart';
import 'household_common.dart';
import 'invite_scanner.dart';

void _toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

String _ordinal(int n) {
  if (n >= 11 && n <= 13) return '${n}th';
  return '$n${switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' }}';
}

/// Settings > Household: start or join one, invite, members, shared bills
/// and leaving.
class HouseholdScreen extends ConsumerWidget {
  const HouseholdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joint = ref.watch(jointDataProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.popOrHome(Routes.settings),
        ),
      ),
      body: AsyncView<JointData?>(
        value: joint,
        loading: const SkeletonList(rows: 4),
        onRetry: () => ref.invalidate(jointDataProvider),
        builder: (j) => j == null ? const _Intro() : _Home(j),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    Widget point(IconData icon, String title, String body) => ListRow(
      leading: IconWell(icon),
      title: title,
      subtitle: body,
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxxl),
      children: [
        const ScreenHeader('Household', subtitle: 'Plan money together'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Text(
            'Share a budget, goals, bills and net worth with your partner or family, and keep the rest to yourself.',
            style: context.tt.bodyLarge!.copyWith(color: c.textSecondary),
          ),
        ),
        const SizedBox(height: Space.xl),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [
            point(Icons.swap_horiz_rounded, 'Mine, theirs or shared', 'Mark any payment, account, asset or goal.'),
            point(Icons.lock_outline_rounded, 'Private stays private', 'A Private item is never shared with the household.'),
            point(Icons.enhanced_encryption_outlined, 'End-to-end encrypted', 'Only you and the people you invite can read what is shared. Not even Pulse can.'),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xxl, Space.gutter, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrimaryButton(
                key: const Key('household_start'),
                label: 'Start a household',
                onPressed: () => showPulseSheet<void>(context, builder: (_) => const CreateHouseholdSheet()),
              ),
              const SizedBox(height: Space.md),
              PrimaryButton(
                key: const Key('household_join'),
                label: 'Join with a code',
                secondary: true,
                onPressed: () => showPulseSheet<void>(context, full: true, builder: (_) => const JoinHouseholdSheet()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Home extends ConsumerWidget {
  const _Home(this.j);
  final JointData j;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final status = ref.watch(householdStatusProvider);
    final svc = ref.read(householdServiceProvider);
    final today = DateTime.now();
    final bills = upcomingBills(j.bills, CalDate(today.year, today.month, today.day), j.me);
    final keyMissing = status.keyMissing;
    final rot = ref.watch(householdRotationProvider).value;
    final removedMe = rot?.removed ?? false;
    final notice = removedMe ? null : rot?.notice;
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxxl),
      children: [
        ScreenHeader(j.config.name, subtitle: 'Household'),
        if (keyMissing)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
            child: SurfaceCard(
              child: Text(
                'This phone no longer has the household key (it is never part of a backup). Ask for a new invite, or leave and join again.',
                style: context.tt.bodyMedium,
              ),
            ),
          ),
        if (removedMe)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.lg,
            ),
            child: SurfaceCard(
              child: Text(
                'You were removed from this household. This phone has stopped sharing with it. Leave to clear it; everything of yours stays on this phone.',
                key: const Key('removed_notice'),
                style: context.tt.bodyMedium,
              ),
            ),
          ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.lg,
            ),
            child: SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${notice.name} changed the household code. Sharing continues once you enter the new one, which they give you in person or over a chat you trust.',
                    key: const Key('rotation_notice'),
                    style: context.tt.bodyMedium,
                  ),
                  const SizedBox(height: Space.md),
                  PrimaryButton(
                    key: const Key('adopt_open'),
                    label: 'Enter the new code',
                    onPressed: () => showPulseSheet<void>(
                      context,
                      full: true,
                      builder: (_) => const AdoptCodeSheet(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SectionHeader('Members', top: 0),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [
            for (final m in j.members)
              ListRow(
                key: Key('member_${m.name}'),
                leading: MemberAvatar(m.name, me: m.id == j.me),
                title: m.name,
                subtitle: m.id == j.me ? 'You' : 'In your household',
                trailing: m.id == j.me || keyMissing || removedMe
                    ? null
                    : TextAction(
                        'Remove',
                        key: Key('remove_${m.name}'),
                        onTap: () => _confirmRemove(context, ref, m),
                      ),
              ),
            if (!keyMissing && !removedMe)
              ListRow(
                key: const Key('household_invite'),
                leading: IconWell(Icons.add_rounded, color: c.accent),
                title: 'Invite someone',
                titleStyle: context.tt.bodyLarge!.copyWith(color: c.accent),
                onTap: () => showPulseSheet<void>(context, full: true, builder: (_) => const InviteSheet()),
              ),
            if (!keyMissing && !removedMe)
              ListRow(
                key: const Key('household_rotate'),
                leading: IconWell(Icons.key_rounded, color: c.accent),
                title: 'Change household code',
                subtitle: 'After someone left, or if a code may have leaked.',
                onTap: () => _confirmRotate(context, ref),
              ),
          ],
        ),
        const SectionHeader('What you share'),
        RowGroup(
          children: [
            ListRow(
              title: 'Share my items',
              subtitle: 'Items of yours not marked Private count in joint totals.',
              trailing: Switch(
                key: const Key('share_mine'),
                value: j.shareMine,
                onChanged: (v) async {
                  await svc.setShareMine(v);
                  ref.invalidate(jointDataProvider);
                },
              ),
            ),
          ],
        ),
        SectionHeader(
          'Shared bills',
          action: 'Add',
          onAction: () => showPulseSheet<void>(context, full: true, builder: (_) => BillSheet(j)),
        ),
        if (bills.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text(
              'Rent, internet, the helper: add what you split and see what each person owes.',
              style: context.tt.bodySmall,
            ),
          )
        else
          RowGroup(
            children: [
              for (final b in bills)
                ListRow(
                  key: Key('bill_${b.bill.id}'),
                  title: b.bill.name,
                  subtitle: 'Due ${_ordinal(b.bill.dueDay)} · your share ${aedMinor(b.myShareMinor)}',
                  trailing: Text(aedMinor(b.bill.amountMinor), style: PulseTheme.amount(c.textPrimary, size: 15)),
                  onTap: () => showPulseSheet<void>(context, full: true, builder: (_) => BillSheet(j, bill: b.bill)),
                ),
            ],
          ),
        const SectionHeader('Sharing status'),
        RowGroup(
          children: [
            ListRow(
              title: status.running ? 'Syncing…' : (status.error ?? _statusLine(status)),
              subtitle: 'End-to-end encrypted. Only ciphertext is stored on the server.',
              subtitleColor: c.textTertiary,
              trailing: TextAction('Sync now', onTap: () async {
                try {
                  await svc.sync();
                  ref.invalidate(jointDataProvider);
                } catch (_) {}
              }),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xxl, Space.gutter, 0),
          child: PrimaryButton(
            key: const Key('household_leave'),
            label: 'Leave household',
            secondary: true,
            destructive: true,
            onPressed: () => _confirmLeave(context, ref),
          ),
        ),
      ],
    );
  }

  String _statusLine(HouseholdStatus s) {
    final t = s.lastSuccess;
    if (t == null) return 'Not synced yet';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Synced just now';
    if (d.inMinutes < 60) return 'Synced ${d.inMinutes} min ago';
    if (d.inHours < 24) return 'Synced ${d.inHours} h ago';
    return 'Synced ${d.inDays} days ago';
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    HMember m,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${m.name}?'),
        content: const Text(
          'The household moves to a new code. Everyone else has to enter it (you give it to them in person or over a chat you trust), '
          'and the person you remove can no longer read anything new. They keep what they already saw.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('remove_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final code = await ref.read(householdServiceProvider).removeMember(m.id);
    invalidateHousehold(ref);
    if (context.mounted) {
      await showPulseSheet<void>(
        context,
        full: true,
        builder: (_) => NewCodeSheet(code: code, removed: m.name),
      );
    }
  }

  Future<void> _confirmRotate(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change the household code?'),
        content: const Text(
          'The household moves to a new code. Everyone has to enter it, and anyone holding the old code can no longer read anything new.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('rotate_confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final code = await ref.read(householdServiceProvider).rotateKey();
    invalidateHousehold(ref);
    if (context.mounted) {
      await showPulseSheet<void>(
        context,
        full: true,
        builder: (_) => NewCodeSheet(code: code),
      );
    }
  }

  Future<void> _confirmLeave(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave this household?'),
        content: const Text(
          'Your shared items are withdrawn from everyone else, and this phone forgets the household. '
          'Everything of yours stays here. What others already saw cannot be taken back.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(key: const Key('leave_confirm'), onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(householdServiceProvider).leave();
    invalidateHousehold(ref);
    if (context.mounted) _toast(context, 'You left the household');
  }
}

// ---- create ------------------------------------------------------------------------

class CreateHouseholdSheet extends ConsumerStatefulWidget {
  const CreateHouseholdSheet({super.key});
  @override
  ConsumerState<CreateHouseholdSheet> createState() => _CreateState();
}

class _CreateState extends ConsumerState<CreateHouseholdSheet> {
  final _house = TextEditingController(text: 'Our household');
  final _me = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _house.dispose();
    _me.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      await ref.read(householdServiceProvider).create(householdName: _house.text, myName: _me.text);
      invalidateHousehold(ref);
      Haptics.success();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: 'Start a household',
    subtitle: 'You can invite someone right after.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('household_name'),
          controller: _house,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Household name'),
        ),
        const SizedBox(height: Space.md),
        TextField(
          key: const Key('household_myname'),
          controller: _me,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Your first name'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Space.xl),
        PrimaryButton(
          key: const Key('household_create'),
          label: 'Create',
          loading: _busy,
          onPressed: _me.text.trim().isEmpty ? null : _create,
        ),
      ],
    ),
  );
}

// ---- join --------------------------------------------------------------------------

class JoinHouseholdSheet extends ConsumerStatefulWidget {
  const JoinHouseholdSheet({super.key});
  @override
  ConsumerState<JoinHouseholdSheet> createState() => _JoinState();
}

class _JoinState extends ConsumerState<JoinHouseholdSheet> {
  final _code = TextEditingController();
  final _me = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _me.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) setState(() => _code.text = d!.text!.trim());
  }

  Future<void> _scan() async {
    final code = await scanInviteCode(context);
    if (code != null && mounted) setState(() => _code.text = code);
  }

  Future<void> _join() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(householdServiceProvider).join(code: _code.text, myName: _me.text);
      invalidateHousehold(ref);
      Haptics.success();
      if (mounted) Navigator.of(context).pop();
    } on FormatException {
      if (mounted) setState(() => _error = "That code doesn't look right. Check it and try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return SheetScaffold(
      title: 'Join a household',
      subtitle: inviteScannerAvailable
          ? 'Scan the QR code on their phone, or paste the code they sent you.'
          : 'Paste the code from the person who invited you.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('join_code'),
            controller: _code,
            minLines: 3,
            maxLines: 4,
            autocorrect: false,
            style: PulseTheme.amount(c.textPrimary, size: 14),
            decoration: InputDecoration(hintText: 'PULSE-HH1-…', errorText: _error),
            onChanged: (_) => setState(() => _error = null),
          ),
          Wrap(
            spacing: Space.lg,
            children: [
              TextAction('Paste from clipboard', onTap: _paste),
              if (inviteScannerAvailable) ...[
                TextAction(
                  'Scan QR code',
                  key: const Key('join_scan'),
                  onTap: _scan,
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.sm),
          TextField(
            key: const Key('join_myname'),
            controller: _me,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Your first name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            key: const Key('join_go'),
            label: 'Join',
            loading: _busy,
            onPressed: _code.text.trim().isEmpty || _me.text.trim().isEmpty ? null : _join,
          ),
        ],
      ),
    );
  }
}

// ---- invite ------------------------------------------------------------------------

/// The invite: a QR code and the same code as text. It contains the
/// household key, so it is shown only on this phone and never sent through
/// Pulse's servers.
class InviteSheet extends ConsumerWidget {
  const InviteSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(_inviteCodeProvider).value;
    return SheetScaffold(
      title: 'Invite someone',
      subtitle: inviteScannerAvailable
          ? 'They choose Join with a code in Pulse and scan this QR code, or paste the text.'
          : 'They choose Join with a code in Pulse and paste this. Scanning the QR with a camera gives the same text.',
      child: code == null ? const SizedBox(height: 200) : _CodeBody(code),
    );
  }
}

/// Shown right after removing a member or changing the code: the new code
/// for everyone who stays. The old one no longer opens anything new.
class NewCodeSheet extends StatelessWidget {
  const NewCodeSheet({super.key, required this.code, this.removed});
  final String code;
  final String? removed;

  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: 'New household code',
    subtitle: removed == null
        ? 'Give this to everyone who stays, in person or over a chat you trust. They open Household and tap Enter the new code.'
        : '$removed is out. Give this to everyone who stays, in person or over a chat you trust. They open Household and tap Enter the new code.',
    child: _CodeBody(code),
  );
}

class _CodeBody extends StatelessWidget {
  const _CodeBody(this.code);
  final String code;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            key: const Key('invite_qr'),
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: QrImageView(
              data: code,
              size: 208,
              version: QrVersions.auto,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF111111),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF111111),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        SurfaceCard(
          child: SelectableText(
            code,
            key: const Key('invite_code'),
            style: PulseTheme.amount(c.textPrimary, size: 13),
          ),
        ),
        const SizedBox(height: Space.md),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                label: 'Copy code',
                secondary: true,
                icon: Icons.copy_rounded,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) _toast(context, 'Code copied');
                },
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: PrimaryButton(
                label: 'Share',
                secondary: true,
                icon: Icons.ios_share_rounded,
                onPressed: () => SharePlus.instance.share(
                  ShareParams(text: code, subject: 'Join my Pulse household'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        Text(
          'This code opens your household. Anyone who has it can read what you share, so pass it in person or in a chat you trust, and only to the people you mean.',
          style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
        ),
      ],
    );
  }
}

/// A remaining member enters the new code after someone was removed or the
/// code was changed. Keeps their name and everything of theirs.
class AdoptCodeSheet extends ConsumerStatefulWidget {
  const AdoptCodeSheet({super.key});
  @override
  ConsumerState<AdoptCodeSheet> createState() => _AdoptState();
}

class _AdoptState extends ConsumerState<AdoptCodeSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) setState(() => _code.text = d!.text!.trim());
  }

  Future<void> _scan() async {
    final code = await scanInviteCode(context);
    if (code != null && mounted) setState(() => _code.text = code);
  }

  Future<void> _adopt() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(householdServiceProvider).adoptRotation(_code.text);
      invalidateHousehold(ref);
      Haptics.success();
      if (mounted) Navigator.of(context).pop();
    } on FormatException {
      if (mounted)
        setState(
          () =>
              _error = "That code doesn't look right. Check it and try again.",
        );
    } on StateError {
      if (mounted)
        setState(
          () => _error =
              'That is the code you already have. Ask for the new one.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return SheetScaffold(
      title: 'Enter the new code',
      subtitle: inviteScannerAvailable
          ? 'Scan the QR code on their phone, or paste the code they sent you.'
          : 'Paste the new code from the person who changed it.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('adopt_code'),
            controller: _code,
            minLines: 3,
            maxLines: 4,
            autocorrect: false,
            style: PulseTheme.amount(c.textPrimary, size: 14),
            decoration: InputDecoration(
              hintText: 'PULSE-HH1-…',
              errorText: _error,
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          Wrap(
            spacing: Space.lg,
            children: [
              TextAction('Paste from clipboard', onTap: _paste),
              if (inviteScannerAvailable) ...[
                TextAction(
                  'Scan QR code',
                  key: const Key('adopt_scan'),
                  onTap: _scan,
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            key: const Key('adopt_go'),
            label: 'Continue sharing',
            loading: _busy,
            onPressed: _code.text.trim().isEmpty ? null : _adopt,
          ),
        ],
      ),
    );
  }
}

final _inviteCodeProvider = FutureProvider.autoDispose<String?>(
  (ref) => ref.watch(householdServiceProvider).inviteCode(),
);

// ---- bills -------------------------------------------------------------------------

class BillSheet extends ConsumerStatefulWidget {
  const BillSheet(this.j, {super.key, this.bill});
  final JointData j;
  final HBill? bill;
  @override
  ConsumerState<BillSheet> createState() => _BillState();
}

class _BillState extends ConsumerState<BillSheet> {
  late final _name = TextEditingController(text: widget.bill?.name);
  late final _amount = TextEditingController(
    text: widget.bill == null ? '' : (widget.bill!.amountMinor / 100).toStringAsFixed(widget.bill!.amountMinor % 100 == 0 ? 0 : 2),
  );
  late int _day = widget.bill?.dueDay ?? 1;
  late double _mine = () {
    final b = widget.bill;
    if (b == null) return 50.0;
    return (b.split[widget.j.me] ?? 5000) / 100;
  }();

  bool get _two => widget.j.members.length == 2;
  int? get _amountMinor {
    final v = double.tryParse(_amount.text.replaceAll(',', ''));
    return v == null || v <= 0 ? null : (v * 100).round();
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Map<String, int> get _split {
    final j = widget.j;
    if (!_two) return equalSplit(j.memberIds);
    final other = j.members.firstWhere((m) => m.id != j.me).id;
    final mine = (_mine * 100).round();
    return {j.me: mine, other: 10000 - mine};
  }

  Future<void> _save() async {
    final svc = ref.read(householdServiceProvider);
    await svc.saveBill(
      HBill(
        id: widget.bill?.id ?? svc.newRowId(),
        name: _name.text.trim(),
        amountMinor: _amountMinor!,
        dueDay: _day,
        categoryId: widget.bill?.categoryId,
        split: _split,
      ),
    );
    ref.invalidate(jointDataProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final j = widget.j;
    final amount = _amountMinor ?? 0;
    final shares = billShares(HBill(id: 'x', name: 'x', amountMinor: amount, dueDay: _day, split: _split));
    return SheetScaffold(
      title: widget.bill == null ? 'Add a shared bill' : 'Edit bill',
      subtitle: 'Something you pay every month and split.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('bill_name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Name, e.g. Rent'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            key: const Key('bill_amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Amount each month', prefixText: 'AED  '),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              Expanded(child: Text('Due on the ${_ordinal(_day)}', style: context.tt.bodyLarge)),
              IconButton(
                tooltip: 'Earlier',
                onPressed: _day > 1 ? () => setState(() => _day--) : null,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              IconButton(
                tooltip: 'Later',
                onPressed: _day < 28 ? () => setState(() => _day++) : null,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          if (_two) ...[
            Text('Split', style: context.tt.titleSmall),
            Slider(
              key: const Key('bill_split'),
              value: _mine,
              min: 0,
              max: 100,
              divisions: 20,
              onChanged: (v) => setState(() => _mine = v),
            ),
          ] else
            Text('Split equally between ${j.members.length} people', style: context.tt.bodyMedium),
          RowGroup(
            padding: EdgeInsets.zero,
            children: [
              for (final m in j.members)
                ListRow(
                  dense: true,
                  leading: MemberAvatar(m.name, me: m.id == j.me, size: 28),
                  title: m.id == j.me ? 'You' : m.name,
                  trailing: Text(
                    aedMinor(shares[m.id] ?? 0),
                    style: PulseTheme.amount(c.textPrimary, size: 15),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            key: const Key('bill_save'),
            label: 'Save',
            onPressed: _name.text.trim().isEmpty || _amountMinor == null ? null : _save,
          ),
          if (widget.bill != null) ...[
            const SizedBox(height: Space.sm),
            TextAction('Remove bill', color: c.negative, onTap: () async {
              await ref.read(householdServiceProvider).deleteBill(widget.bill!.id);
              ref.invalidate(jointDataProvider);
              if (context.mounted) Navigator.of(context).pop();
            }),
          ],
        ],
      ),
    );
  }
}

// ---- joint limits (opened from the Budget screen) ------------------------------------

/// Pick a category and set a joint monthly limit on it.
Future<void> addJointLimit(BuildContext context, WidgetRef ref) async {
  final cat = await pickCategory(context, includeIncome: false, title: 'Category to share');
  if (cat == null || !context.mounted) return;
  await showPulseSheet<void>(context, builder: (_) => JointLimitSheet(categoryId: cat.id, categoryLabel: cat.label));
}

class JointLimitSheet extends ConsumerStatefulWidget {
  const JointLimitSheet({super.key, required this.categoryId, required this.categoryLabel, this.existing});
  final String categoryId, categoryLabel;
  final HLimit? existing;
  @override
  ConsumerState<JointLimitSheet> createState() => _LimitState();
}

class _LimitState extends ConsumerState<JointLimitSheet> {
  late final _amount = TextEditingController(
    text: widget.existing == null ? '' : (widget.existing!.limitMinor / 100).round().toString(),
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? get _minor {
    final v = double.tryParse(_amount.text.replaceAll(',', ''));
    return v == null || v <= 0 ? null : (v * 100).round();
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: '${widget.categoryLabel} limit',
    subtitle: 'A monthly limit for the whole household.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('limit_amount'),
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Amount per month', prefixText: 'AED  '),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Space.xl),
        PrimaryButton(
          key: const Key('limit_save'),
          label: 'Save',
          onPressed: _minor == null
              ? null
              : () async {
                  final svc = ref.read(householdServiceProvider);
                  await svc.saveLimit(
                    HLimit(id: widget.existing?.id ?? svc.newRowId(), categoryId: widget.categoryId, limitMinor: _minor!),
                  );
                  ref.invalidate(jointDataProvider);
                  if (context.mounted) Navigator.of(context).pop();
                },
        ),
        if (widget.existing != null) ...[
          const SizedBox(height: Space.sm),
          TextAction('Remove limit', color: context.pc.negative, onTap: () async {
            await ref.read(householdServiceProvider).deleteLimit(widget.existing!.id);
            ref.invalidate(jointDataProvider);
            if (context.mounted) Navigator.of(context).pop();
          }),
        ],
      ],
    ),
  );
}
