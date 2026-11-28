import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/splits_util.dart';
import 'create_group_sheet.dart';
import 'splits_screen.dart';

/// "Split this" on a payment, or where its split stands once there is one.
/// One tap from the payment: amount and merchant are already filled in.
class TxSplitRow extends ConsumerWidget {
  const TxSplitRow({super.key, required this.tx});
  final Transaction tx;

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    var groups = ref.read(splitGroupsProvider).value ?? const <SplitGroup>[];
    if (groups.isEmpty) {
      // First split: make a group, then carry on with this payment.
      final made = await showCreateGroupSheet(context);
      if (made == null || !context.mounted) return;
      groups = await ref.read(splitGroupsProvider.future);
    }
    if (groups.isEmpty || !context.mounted) return;
    await showPulseSheet<void>(
      context,
      full: true,
      builder: (_) => AddSplitSheet(groups: groups, fromTransaction: tx),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(splitGroupsProvider).value ?? const [];
    final link = splitForTransaction(groups, tx.id);
    if (link != null) {
      final (g, e) = link;
      final mine = shareOf(e, 'me');
      final text = e.paidBy == 'me'
          ? 'Owed ${Money.aed(e.amount - mine)}'
          : 'Your share ${Money.aed(mine)}';
      return ListRow(
        key: const Key('tx_split_linked'),
        dense: true,
        leading: Icon(
          Icons.call_split_rounded,
          size: 22,
          color: context.pc.textSecondary,
        ),
        title: 'Split in ${g.name}',
        trailing: Text(text, style: context.tt.bodyMedium),
      );
    }
    if (tx.isIncome) return const SizedBox.shrink();
    return ListRow(
      key: const Key('tx_split_start'),
      dense: true,
      leading: Icon(
        Icons.call_split_rounded,
        size: 22,
        color: context.pc.textSecondary,
      ),
      title: 'Split this',
      chevron: true,
      onTap: () => _start(context, ref),
    );
  }
}
