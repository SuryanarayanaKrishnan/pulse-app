import 'dart:async';

import '../../core/learning/learning_controller.dart';
import '../../data/learning_hooks.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/analytics/analytics.dart';
import '../../core/engine/recategorise.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/recategoriser.dart';

/// The calm question after a category change: how far should it reach?
/// Pops with the chosen [RecategoriseScope].
class RecategoriseSheet extends StatefulWidget {
  const RecategoriseSheet({
    super.key,
    required this.merchant,
    required this.category,
    required this.pastCount,
  });
  final String merchant;
  final SpendCategory category;

  /// Past transactions the third choice would change.
  final int pastCount;

  @override
  State<RecategoriseSheet> createState() => _RecategoriseSheetState();
}

class _RecategoriseSheetState extends State<RecategoriseSheet> {
  RecategoriseScope _scope = RecategoriseScope.once;

  String get _pastNote => switch (widget.pastCount) {
    0 => 'No earlier transactions to change',
    1 => '1 earlier transaction will change',
    final n => '$n earlier transactions will change',
  };

  @override
  Widget build(BuildContext context) {
    final m = widget.merchant;
    final options = <(RecategoriseScope, String, String?)>[
      (RecategoriseScope.once, 'Just this one', null),
      (RecategoriseScope.future, 'All future from $m', 'Creates a rule you can remove in Automations'),
      (RecategoriseScope.all, 'All past and future from $m', _pastNote),
    ];
    return SheetScaffold(
      title: 'Move to ${widget.category.label}',
      subtitle: 'Should Pulse remember this for $m?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RowGroup(
            padding: EdgeInsets.zero,
            children: [
              for (final (scope, title, note) in options)
                ListRow(
                  key: ValueKey('scope-${scope.name}'),
                  dense: true,
                  title: title,
                  subtitle: note,
                  trailing: Icon(
                    _scope == scope
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 22,
                    color: _scope == scope ? context.pc.accent : context.pc.textSecondary,
                  ),
                  onTap: () => setState(() => _scope = scope),
                ),
            ],
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            label: 'Apply',
            onPressed: () => Navigator.of(context).pop(_scope),
          ),
        ],
      ),
    );
  }
}

/// Asks the scope, applies it, and offers Undo. Returns false when the
/// repository cannot do scoped changes (the caller then does a plain change).
Future<bool> recategoriseWithScope(
  BuildContext context,
  WidgetRef ref, {
  required Transaction tx,
  required SpendCategory to,
}) async {
  final repo = ref.read(repositoryProvider);
  if (repo is! Recategoriser) return false;
  final recat = repo as Recategoriser;
  final preview = await recat.previewRecategorise(tx.id, to);
  if (preview == null) return false;
  if (!context.mounted) return true;
  final analytics = ref.read(analyticsProvider);
  final container = ProviderScope.containerOf(context);
  final messenger = ScaffoldMessenger.maybeOf(context);

  // Dismissing the sheet keeps the change to this one transaction.
  final scope = await showPulseSheet<RecategoriseScope>(
        context,
        builder: (_) => RecategoriseSheet(
          merchant: preview.merchant,
          category: to,
          pastCount: preview.pastCount,
        ),
      ) ??
      RecategoriseScope.once;

  final undo = await recat.recategoriseScoped(tx.id, to, scope);
  analytics.track(AnalyticsEvent.recategoriseScope(scope.analyticsValue));
  // "Just this payment" is an exception, not a statement about the merchant.
  if (scope != RecategoriseScope.once) {
    unawaited(recordConfirmedCategory(container.read(learningControllerProvider), tx, to));
  }
  analytics.track(
    AnalyticsEvent.transactionRecategorized(from: tx.category.name, to: to.name),
  );
  invalidateLedgerIn(container);
  container.invalidate(rulesProvider);
  if (scope == RecategoriseScope.once) return true;
  HapticFeedback.lightImpact();

  final moved = undo.pastCount;
  final text = scope == RecategoriseScope.all && moved > 0
      ? 'Moved to ${to.label}, plus $moved earlier from ${preview.merchant}'
      : 'Moved to ${to.label}. Future ${preview.merchant} follows';
  messenger?.showSnackBar(
    SnackBar(
      content: Text(text),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          await recat.undoRecategorise(undo);
          invalidateLedgerIn(container);
          container.invalidate(rulesProvider);
        },
      ),
    ),
  );
  return true;
}
