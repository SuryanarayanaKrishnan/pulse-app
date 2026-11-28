import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/router.dart';

import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/rules.dart';
import '../categories/category_picker.dart';

void _toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

IconData _iconFor(RuleAction a) => switch (a) {
  RuleAction.setCategory => Icons.category_outlined,
  RuleAction.rename => Icons.edit_outlined,
  RuleAction.exclude => Icons.visibility_off_outlined,
};

/// Rules that tidy every transaction as it arrives.
class AutomationsScreen extends ConsumerWidget {
  const AutomationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(rulesProvider);
    void newRule() => showPulseSheet<void>(
      context,
      full: true,
      builder: (_) => const RuleEditorSheet(),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automations'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.popOrHome(),
        ),
        actions: [
          IconButton(
            tooltip: 'New rule',
            icon: const Icon(Icons.add_rounded),
            onPressed: newRule,
          ),
        ],
      ),
      body: AsyncView<List<AutomationRule>>(
        value: rules,
        onRetry: () => ref.invalidate(rulesProvider),
        builder: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.auto_mode_rounded,
                title: 'No automations yet',
                message:
                    'Re-categorise a transaction and Pulse offers to remember it. '
                    'Or create a rule yourself.',
                action: PrimaryButton(
                  label: 'New rule',
                  expand: false,
                  onPressed: newRule,
                ),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: Space.xxxl),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      Space.sm,
                      Space.gutter,
                      Space.lg,
                    ),
                    child: Text(
                      'Rules run on every new transaction, top to bottom, '
                      'and once on your history when created.',
                      style: context.tt.bodyMedium,
                    ),
                  ),
                  RowGroup(
                    indent: ListRow.leadingInset,
                    children: [
                      for (final r in list)
                        ListRow(
                          leading:
                              r.action == RuleAction.setCategory &&
                                  r.category != null
                              ? CategoryIcon.well(r.category!)
                              : IconWell(_iconFor(r.action)),
                          title: r.condition,
                          subtitle: r.outcome,
                          chevron: true,
                          onTap: () => showPulseSheet<void>(
                            context,
                            builder: (_) => _RuleDetailSheet(r),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _RuleDetailSheet extends ConsumerWidget {
  const _RuleDetailSheet(this.rule);
  final AutomationRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SheetScaffold(
    title: 'Rule',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RowGroup(
          padding: EdgeInsets.zero,
          children: [
            ListRow(
              dense: true,
              title: 'When',
              trailing: Flexible(
                child: Text(
                  rule.condition,
                  style: context.tt.bodyMedium,
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            ListRow(
              dense: true,
              title: 'Then',
              trailing: Flexible(
                child: Text(
                  rule.outcome,
                  style: context.tt.bodyMedium,
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        PrimaryButton(
          label: 'Delete rule',
          secondary: true,
          destructive: true,
          onPressed: () async {
            try {
              await ref.read(repositoryProvider).deleteRule(rule.id);
              ref.invalidate(rulesProvider);
              if (context.mounted) Navigator.of(context).pop();
            } on ApiException catch (e) {
              if (context.mounted) _toast(context, e.message);
            }
          },
        ),
      ],
    ),
  );
}

/// "When [field] [operator] [value], [action]."
class RuleEditorSheet extends ConsumerStatefulWidget {
  const RuleEditorSheet({super.key, this.initial});
  final AutomationRule? initial;
  @override
  ConsumerState<RuleEditorSheet> createState() => _RuleEditorSheetState();
}

class _RuleEditorSheetState extends ConsumerState<RuleEditorSheet> {
  late RuleField _field = widget.initial?.field ?? RuleField.merchant;
  late RuleOperator _op = widget.initial?.op ?? RuleOperator.contains;
  late final _value = TextEditingController(text: widget.initial?.value);
  late RuleAction _action = widget.initial?.action ?? RuleAction.setCategory;
  late SpendCategory? _category = widget.initial?.category;
  late final _rename = TextEditingController(text: widget.initial?.renameTo);
  bool _busy = false;

  @override
  void dispose() {
    _value.dispose();
    _rename.dispose();
    super.dispose();
  }

  AutomationRule get _rule => AutomationRule(
    id: '',
    field: _field,
    op: _op,
    value: _value.text,
    action: _action,
    category: _category,
    renameTo: _rename.text,
  );

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).saveRule(_rule);
      Haptics.success();
      ref.invalidate(rulesProvider);
      invalidateLedger(ref);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) _toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Text(s, style: context.tt.bodySmall),
  );

  Widget _chips<T>(
    List<T> items,
    T value,
    String Function(T) label,
    ValueChanged<T> on,
  ) => Wrap(
    spacing: Space.sm,
    runSpacing: Space.sm,
    children: [
      for (final x in items)
        Pill(label(x), selected: x == value, onTap: () => on(x)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final valid = _rule.isValid;
    return SheetScaffold(
      title: 'New rule',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('When'),
          _chips(RuleField.values, _field, (f) => f.label, (f) {
            setState(() {
              _field = f;
              if (!f.operators.contains(_op)) _op = f.operators.first;
            });
          }),
          const SizedBox(height: Space.md),
          _chips(
            _field.operators,
            _op,
            (o) => o.label,
            (o) => setState(() => _op = o),
          ),
          const SizedBox(height: Space.md),
          TextField(
            controller: _value,
            onChanged: (_) => setState(() {}),
            keyboardType: _field.numeric
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            decoration: InputDecoration(
              hintText: switch (_field) {
                RuleField.merchant => 'e.g. Talabat',
                RuleField.description => 'e.g. ATM WDL',
                RuleField.amount => 'Amount',
                RuleField.account => 'e.g. Mashreq',
              },
              prefixIcon: _field.numeric ? const CurrencyPrefix('AED') : null,
              prefixIconConstraints: kCurrencyPrefixConstraints,
            ),
          ),
          const SizedBox(height: Space.xl),
          _label('Then'),
          _chips(
            RuleAction.values,
            _action,
            (a) => a.label,
            (a) => setState(() => _action = a),
          ),
          const SizedBox(height: Space.md),
          AnimatedSize(
            duration: Motion.base,
            curve: Motion.curve,
            alignment: Alignment.topCenter,
            child: switch (_action) {
              RuleAction.setCategory => RowGroup(
                padding: EdgeInsets.zero,
                children: [
                  ListRow(
                    dense: true,
                    leading: _category == null
                        ? null
                        : CategoryIcon(_category!, size: 22),
                    title: 'Category',
                    trailing: Text(
                      _category?.label ?? 'Choose',
                      style: context.tt.bodyLarge!.copyWith(
                        color: _category == null ? context.pc.accent : null,
                      ),
                    ),
                    chevron: true,
                    onTap: () async {
                      final c = await pickCategory(
                        context,
                        selected: _category,
                      );
                      if (c != null) setState(() => _category = c);
                    },
                  ),
                ],
              ),
              RuleAction.rename => TextField(
                controller: _rename,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'New name'),
              ),
              RuleAction.exclude => Text(
                'Matching transactions stay in Activity but are left out of '
                'budgets and totals.',
                style: context.tt.bodyMedium,
              ),
            },
          ),
          const SizedBox(height: Space.xl),
          if (valid)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: Text(
                '${_rule.condition} → ${_rule.outcome}',
                style: context.tt.bodySmall,
              ),
            ),
          PrimaryButton(
            label: 'Create rule',
            loading: _busy,
            onPressed: valid ? _save : null,
          ),
        ],
      ),
    );
  }
}
