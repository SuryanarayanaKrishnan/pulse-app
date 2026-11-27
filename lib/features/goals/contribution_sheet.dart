import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/goal_models.dart';
import '../../data/providers.dart';
import '../wealth/wealth_widgets.dart';
import 'goal_widgets.dart';

/// Put money into a goal, take some back, or log a payment on a pay down goal.
class ContributionSheet extends ConsumerStatefulWidget {
  const ContributionSheet({super.key, required this.goal, this.withdraw = false});
  final GoalView goal;
  final bool withdraw;

  @override
  ConsumerState<ContributionSheet> createState() => _ContributionSheetState();
}

class _ContributionSheetState extends ConsumerState<ContributionSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _v => parseMinor(_amount.text);

  /// You cannot take back more than the goal holds.
  bool get _valid {
    final v = _v;
    if (v == null || v <= 0) return false;
    return !widget.withdraw || v <= widget.goal.state.currentMinor;
  }

  Future<void> _go() async {
    if (!_valid || _busy) return;
    setState(() => _busy = true);
    await ref.read(goalServiceProvider).contribute(
      widget.goal.id,
      widget.withdraw ? -_v! : _v!,
      note: _note.text,
    );
    invalidateGoals(ref);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.goal;
    final title = widget.withdraw ? 'Withdraw' : (g.isPaydown ? 'Log a payment' : 'Add money');
    final tooMuch = widget.withdraw && (_v ?? 0) > g.state.currentMinor;
    return SheetScaffold(
      title: title,
      subtitle: g.record.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('contribution_amount'),
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Amount', prefixIcon: CurrencyPrefix('AED'),
 prefixIconConstraints: kCurrencyPrefixConstraints),
            onChanged: (_) => setState(() {}),
          ),
          if (tooMuch)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text(
                'This goal holds ${aedMinor(g.state.currentMinor)}, so that is the most you can take back.',
                style: context.tt.bodySmall!.copyWith(color: context.pc.warning),
              ),
            ),
          const SizedBox(height: Space.md),
          TextField(
            key: const Key('contribution_note'),
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Note (optional)'),
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            key: const Key('contribution_save'),
            label: title,
            loading: _busy,
            onPressed: _valid ? _go : null,
          ),
        ],
      ),
    );
  }
}
