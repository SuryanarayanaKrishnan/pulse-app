import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/router.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/insights.dart';
import '../../data/phone.dart';
import '../../data/providers.dart';

void _toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// A household: who is in it, what each person chooses to share, and what
/// you share with them.
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final house = ref.watch(householdProvider);
    void invite() =>
        showPulseSheet<void>(context, builder: (_) => const InviteSheet());
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
      body: AsyncView<Household>(
        value: house,
        onRetry: () => ref.invalidate(householdProvider),
        builder: (h) {
          final you = h.members.where((m) => m.isYou).firstOrNull;
          final others = h.members.where((m) => !m.isYou).toList();
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
                  '${h.name}. Each person decides what the others see.',
                  style: context.tt.bodyMedium,
                ),
              ),
              const SectionHeader('Members'),
              RowGroup(
                indent: ListRow.leadingInset,
                children: [
                  if (you != null) _MemberRow(you),
                  for (final m in others) _MemberRow(m),
                  ListRow(
                    leading: IconWell(
                      Icons.add_rounded,
                      color: context.pc.accent,
                    ),
                    title: 'Invite by phone',
                    titleStyle: context.tt.bodyLarge!.copyWith(
                      color: context.pc.accent,
                    ),
                    onTap: invite,
                  ),
                ],
              ),
              if (you != null) ...[
                const SectionHeader('What you share'),
                _SharingPicker(you),
              ],
              const SectionHeader('Planning ahead'),
              RowGroup(
                indent: ListRow.leadingInset,
                children: [
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
            ],
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.m);
  final FamilyMember m;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: m.isYou ? c.accent : c.surfaceElevated,
        shape: BoxShape.circle,
      ),
      child: Text(
        m.name.isEmpty ? '?' : m.name[0],
        style: context.tt.labelLarge!.copyWith(
          color: m.isYou ? c.onAccent : c.textPrimary,
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow(this.m);
  final FamilyMember m;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final shows = m.isYou || m.sharing != SharingLevel.nothing;
    final String subtitle;
    if (m.invited) {
      subtitle = '${m.relation} · invitation sent';
    } else if (m.isYou) {
      subtitle = 'Sharing ${m.sharing.label.toLowerCase()}';
    } else {
      subtitle = '${m.relation} · shares ${m.sharing.label.toLowerCase()}';
    }
    return ListRow(
      leading: _Avatar(m),
      title: m.isYou ? '${m.name} (you)' : m.name,
      subtitle: subtitle,
      subtitleColor: m.invited ? c.warning : null,
      trailing: m.invited || !shows
          ? Text(m.invited ? '' : 'Private', style: context.tt.bodySmall)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Money.aed(m.spent, decimals: false),
                  style: PulseTheme.amount(c.textPrimary),
                ),
                if (m.budget > 0)
                  Text(
                    'of ${Money.aed(m.budget, decimals: false)}',
                    style: context.tt.bodySmall,
                  ),
              ],
            ),
      chevron: !m.invited,
      onTap: m.invited
          ? null
          : () =>
                showPulseSheet<void>(context, builder: (_) => _MemberSheet(m)),
    );
  }
}

class _MemberSheet extends StatelessWidget {
  const _MemberSheet(this.m);
  final FamilyMember m;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final level = m.isYou ? SharingLevel.full : m.sharing;
    final cats = m.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final p = m.budget == 0 ? 0.0 : m.spent / m.budget;
    return SheetScaffold(
      title: m.isYou ? 'You' : m.name,
      subtitle: m.isYou
          ? 'What others see depends on what you share'
          : '${m.relation} · shares ${m.sharing.label.toLowerCase()}',
      child: level == SharingLevel.nothing
          ? Text(
              '${m.name} keeps their spending private. You can see that they are part of the household, nothing more.',
              style: context.tt.bodyMedium,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('This month', style: context.tt.bodyMedium),
                const SizedBox(height: Space.xs),
                AmountText(m.spent, size: 32, weight: FontWeight.w700),
                if (m.budget > 0) ...[
                  const SizedBox(height: Space.md),
                  Meter(value: p, color: c.forProgress(p)),
                  const SizedBox(height: 6),
                  Text(
                    '${PulseColors.statusLabel(p)} · budget ${Money.aed(m.budget, decimals: false)}',
                    style: context.tt.bodySmall,
                  ),
                ],
                if (level.index >= SharingLevel.categories.index &&
                    cats.isNotEmpty) ...[
                  const SizedBox(height: Space.xl),
                  RowGroup(
                    padding: EdgeInsets.zero,
                    indent: ListRow.leadingInset,
                    children: [
                      for (final e in cats)
                        ListRow(
                          dense: true,
                          leading: CategoryIcon.well(e.key),
                          title: e.key.label,
                          trailing: Text(
                            Money.aed(e.value, decimals: false),
                            style: PulseTheme.amount(c.textPrimary),
                          ),
                        ),
                    ],
                  ),
                ],
                if (level == SharingLevel.totals) ...[
                  const SizedBox(height: Space.lg),
                  Text(
                    '${m.name} shares totals only.',
                    style: context.tt.bodySmall,
                  ),
                ],
              ],
            ),
    );
  }
}

class _SharingPicker extends ConsumerWidget {
  const _SharingPicker(this.you);
  final FamilyMember you;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    return RowGroup(
      children: [
        for (final l in SharingLevel.values)
          ListRow(
            dense: true,
            title: l.label,
            subtitle: l.description,
            trailing: AnimatedOpacity(
              duration: Motion.fast,
              opacity: l == you.sharing ? 1 : 0,
              child: Icon(Icons.check_rounded, color: c.accent, size: 20),
            ),
            onTap: () async {
              Haptics.tap();
              try {
                await ref.read(repositoryProvider).setSharing(you.id, l);
                ref.invalidate(householdProvider);
              } on ApiException catch (e) {
                if (context.mounted) _toast(context, e.message);
              }
            },
          ),
      ],
    );
  }
}

/// Invite someone to the household by phone number.
class InviteSheet extends ConsumerStatefulWidget {
  const InviteSheet({super.key});
  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String _relation = 'Partner';
  bool _busy = false;
  static const _relations = ['Partner', 'Parent', 'Child', 'Sibling', 'Other'];

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && toE164(_phone.text) != null;

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(repositoryProvider)
          .inviteFamilyMember(
            name: _name.text.trim(),
            phone: _phone.text,
            relation: _relation,
          );
      ref.invalidate(householdProvider);
      Haptics.success();
      if (mounted) {
        Navigator.of(context).pop();
        _toast(context, 'Invitation sent to ${_name.text.trim()}');
      }
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Invite to household',
      subtitle: 'They choose what to share once they join',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            ],
            decoration: const InputDecoration(
              hintText: 'Mobile, e.g. 050 123 4567',
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
            label: 'Send invite',
            loading: _busy,
            onPressed: _valid ? _send : null,
          ),
        ],
      ),
    );
  }
}
