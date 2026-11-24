import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/household/household_models.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../core/household/household_store.dart' show Ownership;
import '../../household/household_providers.dart';
import 'household_common.dart';

/// Opens the "who is this for" sheet for one item.
///
/// [table]: `transactions`, `lines` (a Wealth row's id) or `goals`.
Future<void> showOwnershipSheet(
  BuildContext context, {
  required String table,
  required String id,
  required String title,
}) => showPulseSheet<void>(
  context,
  builder: (_) => OwnershipSheet(table: table, id: id, title: title),
);

/// Mine / Omar's / Shared, and a Private switch. Changes apply at once.
class OwnershipSheet extends ConsumerWidget {
  const OwnershipSheet({super.key, required this.table, required this.id, required this.title});
  final String table, id, title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joint = ref.watch(jointDataProvider).value;
    final own = ref.watch(ownershipProvider((table, id))).value;
    final c = context.pc;
    if (joint == null || own == null) {
      return SheetScaffold(title: 'Who is this for?', subtitle: title, child: const SizedBox(height: 120));
    }
    final others = [for (final m in joint.members) if (m.id != joint.me) m];

    Future<void> set({String? owner, bool? isPrivate}) async {
      await ref.read(householdServiceProvider).setOwnership(table, id, owner: owner, isPrivate: isPrivate);
      ref.invalidate(ownershipProvider((table, id)));
      ref.invalidate(jointDataProvider);
      Haptics.tap();
    }

    Widget option(String key, String label, String? sub, Widget leading, String value) => ListRow(
      key: Key('owner_$key'),
      dense: true,
      leading: leading,
      title: label,
      subtitle: sub,
      trailing: own.owner == value
          ? Icon(Icons.check_rounded, color: c.accent, size: 22)
          : null,
      onTap: () => set(owner: value),
    );

    return SheetScaffold(
      title: 'Who is this for?',
      subtitle: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RowGroup(
            padding: EdgeInsets.zero,
            indent: 32 + Space.md,
            children: [
              option('me', 'Mine', null, MemberAvatar(joint.nameOf(joint.me), me: true), Owner.me),
              for (final m in others)
                option(m.id, "${m.name}'s", 'Recorded here on their behalf', MemberAvatar(m.name), m.id),
              option('shared', 'Shared', 'Counts in the household totals', const MemberAvatar('', shared: true), Owner.shared),
            ],
          ),
          const SizedBox(height: Space.lg),
          RowGroup(
            padding: EdgeInsets.zero,
            children: [
              ListRow(
                dense: true,
                title: 'Private',
                subtitle: 'Stays on your devices. Never shared, and left out of joint totals.',
                trailing: Switch(
                  key: const Key('owner_private'),
                  value: own.isPrivate,
                  onChanged: (v) => set(isPrivate: v),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Text(
            'Shared items are end-to-end encrypted: only the people in your household can read them.',
            style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(label: 'Done', secondary: true, onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }
}

/// A row for a detail sheet or screen: who the item is for. Hidden when
/// there is no household.
class OwnerRow extends ConsumerWidget {
  const OwnerRow({super.key, required this.table, required this.id, required this.title, this.dense = true});
  final String table, id, title;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final joint = ref.watch(jointDataProvider).value;
    if (joint == null) return const SizedBox.shrink();
    final own = ref.watch(ownershipProvider((table, id))).value ?? const Ownership();
    return ListRow(
      key: const Key('owner_row'),
      dense: dense,
      leading: const Icon(Icons.people_alt_outlined, size: 22),
      title: 'Household',
      trailing: Text(sharingCaption(joint, own.owner, own.isPrivate), style: context.tt.bodyMedium),
      chevron: true,
      onTap: () => showOwnershipSheet(context, table: table, id: id, title: title),
    );
  }
}
