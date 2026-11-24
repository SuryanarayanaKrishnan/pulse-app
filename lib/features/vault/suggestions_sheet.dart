import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/vault/suggestions.dart';
import '../../core/vault/vault_models.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../goals/goal_widgets.dart' show aedMinor;
import 'vault_widgets.dart';

/// "Add these N items to your vault": what Pulse already knows about,
/// all ticked, nothing added until you confirm.
class SuggestionsSheet extends ConsumerStatefulWidget {
  const SuggestionsSheet(this.items, {super.key});
  final List<VaultSource> items;

  @override
  ConsumerState<SuggestionsSheet> createState() => _SuggestionsSheetState();
}

class _SuggestionsSheetState extends ConsumerState<SuggestionsSheet> {
  late final Set<String> _on = {for (final s in widget.items) s.ref};
  bool _busy = false;

  Future<void> _add() async {
    setState(() => _busy = true);
    final chosen = [
      for (final s in widget.items)
        if (_on.contains(s.ref)) s,
    ];
    final n = await ref.read(vaultServiceProvider).addSuggestions(chosen);
    invalidateVault(ref);
    if (mounted) {
      Navigator.of(context).pop(n);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title:
          'Add ${widget.items.length} ${widget.items.length == 1 ? 'item' : 'items'} to your vault',
      subtitle: 'From what Pulse already knows. Only names are copied, no account numbers. You can add where to find each one afterwards.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in widget.items)
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                key: ValueKey('vault_sugg_${s.ref}'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _on.contains(s.ref),
                onChanged: (v) => setState(
                  () => v == true ? _on.add(s.ref) : _on.remove(s.ref),
                ),
                secondary: Icon(vaultIcon(s.type), size: 20),
                title: Text(
                  s.institution,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    s.type.label,
                    if (s.title.isNotEmpty) s.title,
                    if (s.valueMinor != null && s.type != VaultType.loan)
                      aedMinor(s.valueMinor!),
                  ].join(' · '),
                ),
              ),
            ),
          const SizedBox(height: Space.lg),
          PrimaryButton(
            key: const Key('vault_sugg_add'),
            label: _on.isEmpty ? 'Nothing selected' : 'Add ${_on.length}',
            loading: _busy,
            onPressed: _on.isEmpty ? null : _add,
          ),
        ],
      ),
    );
  }
}
