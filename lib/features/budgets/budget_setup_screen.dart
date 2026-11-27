import 'dart:math' as math;

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Budget set for $n categories. Tap any to adjust.')));
      context.pop();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not save the budget. Try again.')));
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
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
            decoration: const InputDecoration(prefixIcon: CurrencyPrefix('AED'),
 prefixIconConstraints: kCurrencyPrefixConstraints, hintText: 'After tax and deductions'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.xl),
          _Stepper(label: 'Adults', value: _adults, min: 1, max: 4, onChanged: (v) => setState(() => _adults = v)),
          _Stepper(
            label: 'Children',
            value: _children,
            min: 0,
            max: 6,
            onChanged: (v) => setState(() => _children = v),
          ),
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
            _SummaryStrip(plan: plan),
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

/// Planned / Saved / Left over. Three columns while there is room; at large
/// Dynamic Type or very big amounts it becomes stacked label/value rows so no
/// figure is clipped or shrunk. A negative left-over is shown in the negative
/// colour and labelled "Over by", never silently as a small minus sign.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.plan});
  final SuggestedBudget plan;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final over = plan.isOverBudget;
    final left = Money.aed(plan.leftoverMinor.abs() / 100, decimals: false);
    final figures = [
      ('Planned', Money.aed(plan.spendMinor / 100, decimals: false), null),
      ('Saved', Money.aed(plan.savingsMinor / 100, decimals: false), null),
      (over ? 'Over by' : 'Left over', left, over ? c.negative : null),
    ];
    return SurfaceCard(
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final longest = figures.map((f) => f.$2.length).reduce((a, b) => a > b ? a : b);
          // Roughly 0.6em per glyph for titleMedium; stack when a column cannot hold it.
          final need = longest * 0.62 * 16 * scale;
          final stacked = scale > 1.3 || need > box.maxWidth / 3;
          if (stacked) {
            return Column(
              key: const Key('setup_summary_stacked'),
              children: [
                for (final f in figures)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text(f.$1, style: context.tt.bodySmall!.copyWith(color: c.textSecondary)),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(f.$2, maxLines: 1, style: context.tt.titleMedium!.copyWith(color: f.$3)),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }
          return Row(
            key: const Key('setup_summary_row'),
            children: [for (final f in figures) Expanded(child: _Figure(f.$1, f.$2, f.$3))],
          );
        },
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, this.color);
  final String label, value;
  final Color? color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value, style: context.tt.titleMedium!.copyWith(color: color), maxLines: 1),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: context.tt.bodySmall!.copyWith(color: context.pc.textSecondary),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
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
      SizedBox(
        width: 28,
        child: Text('$value', textAlign: TextAlign.center, style: context.tt.titleMedium),
      ),
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
  const _LineEditor({
    super.key,
    required this.category,
    required this.line,
    required this.max,
    required this.onChanged,
  });
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

  /// The field is as wide as "AED " plus its digits (and a little for the
  /// caret), never narrower than the old 104. When that is more than ~45% of the screen the field moves under the name,
  /// so a value like 125,000 is shown in full at any text scale.
  double _fieldWidth(BuildContext context) {
    final style = (Theme.of(context).textTheme.bodyLarge ?? const TextStyle()).merge(context.tt.bodyLarge);
    final tp = TextPainter(
      text: TextSpan(text: 'AED ${_ctl.text.isEmpty ? '0' : _ctl.text}', style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final w = tp.width + 4 * 2 + 12;
    tp.dispose();
    return math.max(104.0, w);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final value = widget.line.amountMinor.clamp(0, widget.max).toDouble();
    final screenW = MediaQuery.sizeOf(context).width;
    final fieldW = _fieldWidth(context);
    // Big figures or big text: the field gets its own line under the name
    // instead of squeezing the name or clipping its digits.
    final stacked = fieldW > screenW * 0.45;
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.category.label, style: context.tt.bodyLarge),
        Text(widget.line.basis.label, style: context.tt.bodySmall!.copyWith(color: c.textTertiary)),
      ],
    );
    final field = Focus(
      onFocusChange: (f) => _hasFocus = f,
      child: TextField(
        key: Key('amount_${widget.line.categoryId}'),
        controller: _ctl,
        textAlign: TextAlign.end,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          // Always holds a number, so (unlike an empty amount field) the
          // prefix text is never hidden here.
          prefixText: 'AED ',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        ),
        onChanged: (t) {
          setState(() {}); // re-measure so the field grows with the digits
          widget.onChanged((int.tryParse(t) ?? 0) * 100);
        },
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.sm),
      child: Column(
        children: [
          if (stacked)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    CategoryIcon.well(widget.category),
                    const SizedBox(width: Space.md),
                    Expanded(child: label),
                  ],
                ),
                const SizedBox(height: Space.xs),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(width: math.min(fieldW, screenW - 2 * Space.gutter), child: field),
                ),
              ],
            )
          else
            Row(
              children: [
                CategoryIcon.well(widget.category),
                const SizedBox(width: Space.md),
                Expanded(child: label),
                SizedBox(width: fieldW, child: field),
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
