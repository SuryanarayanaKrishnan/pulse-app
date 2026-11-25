import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/analytics/analytics.dart';
import '../../core/engine/cashflow.dart' show requiredMonthly;
import '../../core/engine/dates.dart';
import '../../core/engine/goals.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/goal_models.dart';
import '../../data/local/goal_store.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../wealth/wealth_widgets.dart';
import 'goal_widgets.dart';

/// Create or edit a goal. Everything stays on this phone (and in your
/// encrypted sync); only the goal's type is ever counted, never its name.
class GoalSheet extends ConsumerStatefulWidget {
  const GoalSheet({super.key, this.initial, this.kind = GoalKind.save});
  final GoalRecord? initial;
  final GoalKind kind;

  @override
  ConsumerState<GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends ConsumerState<GoalSheet> {
  late GoalKind _kind = widget.initial?.kind ?? widget.kind;
  late String? _icon = widget.initial?.iconKey;
  late CalDate? _date = widget.initial?.targetDate;
  late String? _link = widget.initial?.linkedRef;
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _target = TextEditingController(
    text: _fill(widget.initial?.targetMinor),
  );
  late final _start = TextEditingController(
    text: _fill(widget.initial?.startMinor),
  );
  late final _monthly = TextEditingController(
    text: _fill(widget.initial?.monthlyMinor),
  );
  bool _busy = false;

  bool get _editing => widget.initial != null;
  bool get _paydown => _kind == GoalKind.paydown;

  static String _fill(int? minor) => minor == null || minor == 0
      ? ''
      : (minor / 100).toStringAsFixed(minor % 100 == 0 ? 0 : 2);

  @override
  void dispose() {
    for (final c in [_name, _target, _start, _monthly]) {
      c.dispose();
    }
    super.dispose();
  }

  int? get _targetV => _paydown ? 0 : parseMinor(_target.text);
  int? get _startV => parseMinor(_start.text);

  bool get _valid {
    if (_name.text.trim().isEmpty) return false;
    if (_paydown) return (_startV ?? 0) > 0 || _link != null;
    return (_targetV ?? 0) > 0;
  }

  /// remaining / months left, for the hint under the monthly field.
  int? _suggestion(Map<String, Asset> assets) {
    final t = ref.read(goalServiceProvider).today;
    final linked = assets[_link];
    final int remaining;
    if (_paydown) {
      final owed = linked == null
          ? (_startV ?? 0)
          : (linked.value * 100).round();
      remaining = owed;
    } else {
      final have = linked == null
          ? (_startV ?? 0)
          : (linked.value * 100).round();
      remaining = (_targetV ?? 0) - have;
    }
    return requiredMonthly(remaining, t, _date);
  }

  Future<void> _save(Map<String, Asset> assets) async {
    if (!_valid || _busy) return;
    setState(() => _busy = true);
    try {
      final old = widget.initial;
      final linked = assets[_link];
      var start = _startV ?? 0;
      if (_paydown && linked != null && start == 0)
        start = (linked.value * 100).round();
      final g = GoalRecord(
        id: old?.id ?? newGoalId(),
        name: _name.text.trim(),
        kind: _kind,
        iconKey: _icon,
        targetMinor: _targetV ?? 0,
        startMinor: start,
        targetDate: _date,
        monthlyMinor: parseMinor(_monthly.text),
        linkedRef: _link,
        paused: old?.paused ?? false,
        completedAt: old?.completedAt,
        createdAt: old?.createdAt ?? DateTime.now(),
      );
      await ref.read(goalServiceProvider).save(g);
      if (old == null)
        ref
            .read(analyticsProvider)
            .track(AnalyticsEvent.goalCreated(_kind.key));
      invalidateGoals(ref);
      if (mounted) Navigator.of(context).pop(g.id);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That did not save. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final all = ref.watch(assetsProvider).value ?? const <Asset>[];
    final candidates = [
      for (final a in all)
        if (a.isLiability == _paydown) a,
    ];
    final byId = {for (final a in all) a.id: a};
    final hint = _suggestion(byId);
    return SheetScaffold(
      title: _editing ? 'Edit goal' : 'New goal',
      subtitle: _paydown
          ? 'Pay a balance down to zero.'
          : 'Save towards something that matters.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_editing)
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                Pill(
                  'Save up',
                  selected: !_paydown,
                  onTap: () => setState(() {
                    _kind = GoalKind.save;
                    _link = null;
                  }),
                ),
                Pill(
                  'Pay down',
                  selected: _paydown,
                  onTap: () => setState(() {
                    _kind = GoalKind.paydown;
                    _link = null;
                  }),
                ),
              ],
            ),
          const SizedBox(height: Space.lg),
          TextField(
            key: const Key('goal_name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: _paydown
                  ? 'Name, like "Clear the card"'
                  : 'Name, like "Trip to Japan"',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const FieldLabel('Icon'),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final k in goalIconKeys)
                Semantics(
                  button: true,
                  selected: (_icon ?? defaultGoalIcon(_kind)) == k,
                  label: glyphsByKeyLabel(k),
                  child: GestureDetector(
                    key: ValueKey('goal_icon_$k'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _icon = k),
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: (_icon ?? defaultGoalIcon(_kind)) == k
                            ? c.accent.withValues(alpha: 0.12)
                            : c.surfaceElevated,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(
                          color: (_icon ?? defaultGoalIcon(_kind)) == k
                              ? c.accent
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ExcludeSemantics(
                        child: GlyphKeyIcon(
                          k,
                          selected: (_icon ?? defaultGoalIcon(_kind)) == k,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
          if (!_paydown)
            TextField(
              key: const Key('goal_target'),
              controller: _target,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: 'Target amount',
                prefixText: 'AED  ',
              ),
              onChanged: (_) => setState(() {}),
            ),
          if (!_paydown) const SizedBox(height: Space.md),
          if (_link == null)
            TextField(
              key: const Key('goal_start'),
              controller: _start,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: _paydown
                    ? 'Amount owed now'
                    : 'Already saved (optional)',
                prefixText: 'AED  ',
              ),
              onChanged: (_) => setState(() {}),
            ),
          const FieldLabel('Target date (optional)'),
          Row(
            children: [
              Pill(
                _date == null ? 'Pick a date' : formatDate(_date!),
                icon: Icons.event_outlined,
                selected: _date != null,
                onTap: () async {
                  final d = await pickDate(
                    context,
                    initial: _date,
                    future: true,
                  );
                  if (d != null && mounted) setState(() => _date = d);
                },
              ),
              if (_date != null) ...[
                const SizedBox(width: Space.sm),
                TextAction('Clear', onTap: () => setState(() => _date = null)),
              ],
            ],
          ),
          if (candidates.isNotEmpty) ...[
            FieldLabel(
              _paydown
                  ? 'Follow a card or loan (optional)'
                  : 'Follow an account or asset (optional)',
            ),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                Pill(
                  'By hand',
                  selected: _link == null,
                  onTap: () => setState(() => _link = null),
                ),
                for (final a in candidates.take(8))
                  Pill(
                    a.name,
                    selected: _link == a.id,
                    onTap: () => setState(() => _link = a.id),
                  ),
              ],
            ),
            if (_link != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.sm),
                child: Text(
                  _paydown
                      ? 'Progress follows the balance, so you do not need to log payments.'
                      : 'Progress follows everything in it, so you do not need to log contributions.',
                  style: context.tt.bodySmall,
                ),
              ),
          ],
          const FieldLabel('Monthly amount (optional)'),
          TextField(
            key: const Key('goal_monthly'),
            controller: _monthly,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Your own figure',
              prefixText: 'AED  ',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Text(
              hint == null || hint == 0
                  ? 'This is set aside from Safe to spend each month. With a date, Pulse suggests an amount.'
                  : 'Suggested ${aedMinor(hint)} a month to reach it by your date. It is set aside from Safe to spend.',
              key: const Key('goal_suggestion'),
              style: context.tt.bodySmall,
            ),
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            key: const Key('goal_save'),
            label: _editing ? 'Save changes' : 'Create goal',
            loading: _busy,
            onPressed: _valid ? () => _save(byId) : null,
          ),
        ],
      ),
    );
  }
}
