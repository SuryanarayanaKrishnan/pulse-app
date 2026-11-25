import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/analytics/analytics.dart';
import '../../core/engine/budget_suggest.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// "Build my budget": a few answers in, a full monthly budget out, to tweak.
/// Rules only; nothing leaves the phone.
class BudgetSetupScreen extends ConsumerStatefulWidget {
  const BudgetSetupScreen({super.key});
  @override
  ConsumerState<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends ConsumerState<BudgetSetupScreen> {
  final _income = TextEditingController();
  int _adults = 1, _children = 0;
  Housing _housing = Housing.rent;
  bool _car = false, _home = false, _useHistory = true, _saving = false;
  Map<String, int> _history = const {};

  /// Amounts the user changed by hand, and lines they removed.
  final Map<String, int> _edited = {};

  @override
  void initState() {
    super.initState();
    ref.read(budgetImportServiceProvider).historyByCategory().then((h) {
      if (mounted) setState(() => _history = h);
    });
  }

  @override
  void dispose() {
    _income.dispose();
    super.dispose();
  }

  int get _incomeMinor => ((double.tryParse(_income.text.replaceAll(',', '').trim()) ?? 0) * 100).round();

  SuggestedBudget get _plan {
    final base = suggestBudget(
      SuggestInput(
        incomeMinor: _incomeMinor,
        adults: _adults,
        children: _children,
        housing: _housing,
        hasCar: _car,
        sendsMoneyHome: _home,
        history: _useHistory ? _history : const {},
      ),
    );
    // Order stays as first suggested so a line does not jump under the thumb.
    final lines = [
      for (final l in base.lines)
        _edited.containsKey(l.categoryId) ? l.withAmount(_edited[l.categoryId]!, SuggestBasis.known) : l,
    ];
    return SuggestedBudget(lines: lines, savingsMinor: base.savingsMinor, incomeMinor: base.incomeMinor);
  }

  SpendCategory _cat(String id, List<SpendCategory> custom) =>
      [...SpendCategory.defaults, ...custom].where((c) => c.id == id).firstOrNull ?? SpendCategory(id, id);

  /// Slider ceiling per line: fixed from the first suggestion so the thumb
  /// does not jump while dragging.
  final Map<String, int> _max = {};
  int _maxFor(SuggestedLine l) {
    final v = _max[l.categoryId];
    if (v != null) return v;
    final m = (l.amountMinor * 2).clamp(100000, 100000000);
    return _max[l.categoryId] = m;
  }

  Future<void> _apply(SuggestedBudget plan) async {
    setState(() => _saving = true);
    try {
      final n = await ref.read(budgetImportServiceProvider).applySuggestion(plan, DateTime.now());
      ref.read(analyticsProvider).track(AnalyticsEvent.budgetSuggested(history: _useHistory && _history.isNotEmpty));
      invalidateBudgetPlan(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Budget set for $n categories. Tap any to adjust.')));
      context.pop();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the budget. Try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final custom = ref.watch(categoriesProvider).value ?? const <SpendCategory>[];
    final plan = _plan;
    final ready = _incomeMinor > 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Build my budget'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, 120),
        children: [
          Text(
            'A few answers and we draft the whole month for you. Change anything after.',
            style: context.tt.bodyMedium!.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.xl),
          Text('Monthly take-home', style: context.tt.titleSmall),
          const SizedBox(height: Space.sm),
          TextField(
            key: const Key('setup_income'),
            controller: _income,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
            decoration: const InputDecoration(prefixText: 'AED ', hintText: 'After tax and deductions'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.xl),
          _Stepper(label: 'Adults', value: _adults, min: 1, max: 4, onChanged: (v) => setState(() => _adults = v)),
          _Stepper(label: 'Children', value: _children, min: 0, max: 6, onChanged: (v) => setState(() => _children = v)),
          const SizedBox(height: Space.lg),
          Text('Home', style: context.tt.titleSmall),
          const SizedBox(height: Space.sm),
          Segmented<Housing>(
            segments: const {Housing.rent: 'Rent', Housing.owned: 'Mortgage', Housing.free: 'Provided'},
            value: _housing,
            onChanged: (v) => setState(() => _housing = v),
          ),
          const SizedBox(height: Space.sm),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('I run a car'),
            value: _car,
            onChanged: (v) => setState(() => _car = v),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('I send money home'),
            value: _home,
            onChanged: (v) => setState(() => _home = v),
          ),
          if (_history.isNotEmpty)
            SwitchListTile.adaptive(
              key: const Key('setup_history'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Use my past spending'),
              subtitle: const Text('Where we have it, it replaces the typical figure.'),
              value: _useHistory,
              onChanged: (v) => setState(() => _useHistory = v),
            ),
          const SizedBox(height: Space.xl),
          if (!ready)
            EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'Start with your take-home',
              message: 'Enter what lands in your account each month and your budget appears here.',
            )
          else ...[
            SurfaceCard(
              child: Row(
                children: [
                  Expanded(child: _Figure('Planned', Money.aed(plan.spendMinor / 100, decimals: false))),
                  Expanded(child: _Figure('Saved', Money.aed(plan.savingsMinor / 100, decimals: false))),
                  Expanded(child: _Figure('Left over', Money.aed(plan.leftoverMinor / 100, decimals: false))),
                ],
              ),
            ),
            const SizedBox(height: Space.lg),
            RowGroup(
              padding: EdgeInsets.zero,
              indent: ListRow.leadingInset,
              children: [
                for (final l in plan.lines)
                  _LineEditor(
                    key: Key('setup_${l.categoryId}'),
                    category: _cat(l.categoryId, custom),
                    line: l,
                    max: _maxFor(l),
                    onChanged: (minor) => setState(() => _edited[l.categoryId] = minor),
                  ),
              ],
            ),
            const SizedBox(height: Space.md),
            Text(
              'Estimates from typical UAE costs, not advice. Type an amount or drag a slider; set a line to 0 to leave it out.',
              style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.md),
          child: PrimaryButton(
            key: const Key('setup_apply'),
            label: 'Use this budget',
            loading: _saving,
            onPressed: ready && plan.spendMinor > 0 ? () => _apply(plan) : null,
          ),
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: context.tt.titleMedium, maxLines: 1),
      const SizedBox(height: 2),
      Text(label, style: context.tt.bodySmall!.copyWith(color: context.pc.textSecondary)),
    ],
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.min, required this.max, required this.onChanged});
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label, style: context.tt.bodyLarge)),
      IconButton(
        tooltip: 'Fewer ${label.toLowerCase()}',
        onPressed: value > min ? () => onChanged(value - 1) : null,
        icon: const Icon(Icons.remove_circle_outline_rounded),
      ),
      SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.center, style: context.tt.titleMedium)),
      IconButton(
        tooltip: 'More ${label.toLowerCase()}',
        onPressed: value < max ? () => onChanged(value + 1) : null,
        icon: const Icon(Icons.add_circle_outline_rounded),
      ),
    ],
  );
}

/// One budget line: name, an amount you can type, and a slider. Changes are
/// live; nothing to confirm per line.
class _LineEditor extends StatefulWidget {
  const _LineEditor({super.key, required this.category, required this.line, required this.max, required this.onChanged});
  final SpendCategory category;
  final SuggestedLine line;
  final int max;
  final ValueChanged<int> onChanged;
  @override
  State<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends State<_LineEditor> {
  late final _ctl = TextEditingController(text: _fmt(widget.line.amountMinor));
  static String _fmt(int minor) => (minor / 100).round().toString();

  @override
  void didUpdateWidget(_LineEditor old) {
    super.didUpdateWidget(old);
    // Keep the field in step when the plan itself changes (income, family).
    final typed = (int.tryParse(_ctl.text) ?? 0) * 100;
    if (typed != widget.line.amountMinor && !_hasFocus) _ctl.text = _fmt(widget.line.amountMinor);
  }

  bool _hasFocus = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final value = widget.line.amountMinor.clamp(0, widget.max).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Column(
        children: [
          Row(
            children: [
              CategoryIcon.well(widget.category),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.category.label, style: context.tt.bodyLarge),
                    Text(widget.line.basis.label, style: context.tt.bodySmall!.copyWith(color: c.textTertiary)),
                  ],
                ),
              ),
              SizedBox(
                width: 104,
                child: Focus(
                  onFocusChange: (f) => _hasFocus = f,
                  child: TextField(
                    key: Key('amount_${widget.line.categoryId}'),
                    controller: _ctl,
                    textAlign: TextAlign.end,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(prefixText: 'AED ', isDense: true),
                    onChanged: (t) => widget.onChanged((int.tryParse(t) ?? 0) * 100),
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            max: widget.max.toDouble(),
            divisions: (widget.max / 5000).round().clamp(1, 400),
            onChanged: (v) {
              final minor = (v / 100).round() * 100;
              _ctl.text = _fmt(minor);
              widget.onChanged(minor);
            },
          ),
        ],
      ),
    );
  }
}
