import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/router.dart';

import 'package:material_ui/material_ui.dart';

import '../../core/analytics/analytics.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'icon_picker.dart';
import '../coach/coach.dart';

/// Categories and their monthly budgets. Defaults plus your own.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesProvider);
    final budget = ref.watch(budgetProvider).value;
    final planned = {
      for (final l in budget?.lines ?? const <BudgetLine>[])
        if (l.planned > 0) l.category: l.planned,
    };
    return CoachHost(
      screen: CoachScreen.categories,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.popOrHome(),
          ),
          actions: [
            CoachTarget(
              id: 'new',
              child: IconButton(
                tooltip: 'New category',
                icon: const Icon(Icons.add_rounded),
                onPressed: () => showPulseSheet<void>(
                  context,
                  builder: (_) => const NewCategorySheet(),
                ),
              ),
            ),
          ],
        ),
        body: AsyncView<List<SpendCategory>>(
          value: cats,
          onRetry: () => ref.invalidate(categoriesProvider),
          builder: (list) {
            final total = planned.values.fold(0.0, (a, b) => a + b);
            Widget row(SpendCategory x, {bool budgetable = true}) => ListRow(
              leading: CategoryIcon.well(x),
              title: x.label,
              subtitle: [
                if (x.custom) 'Custom',
                if (budgetable)
                  planned[x] == null
                      ? 'No budget'
                      : '${Money.aed(planned[x]!, decimals: false)} a month',
              ].join(' · '),
              chevron: budgetable,
              onTap: budgetable
                  ? () => showPulseSheet<void>(
                      context,
                      builder: (_) =>
                          BudgetSheet(category: x, current: planned[x]),
                    )
                  : null,
            );
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
                    'Monthly budgets total ${Money.aed(total, decimals: false)}. '
                    'Tap a category to change its budget.',
                    style: context.tt.bodyMedium,
                  ),
                ),
                const SectionHeader('Spending'),
                CoachTarget(
                  id: 'list',
                  child: RowGroup(
                    indent: ListRow.leadingInset,
                    children: [
                      for (final x in list)
                        if (x.kind == CategoryKind.expense) row(x),
                      ListRow(
                        key: const Key('category_new_row'),
                        leading: const IconWell(Icons.add_rounded),
                        title: 'New category',
                        subtitle: 'Your own name, icon and monthly budget',
                        onTap: () => showPulseSheet<void>(
                          context,
                          builder: (_) => const NewCategorySheet(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionHeader('Income and transfers'),
                RowGroup(
                  indent: ListRow.leadingInset,
                  children: [
                    for (final x in list)
                      if (x.kind != CategoryKind.expense)
                        row(x, budgetable: false),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

double? _parseAed(String s) => double.tryParse(s.replaceAll(',', '').trim());

/// Set or clear the monthly budget of one category.
class BudgetSheet extends ConsumerStatefulWidget {
  const BudgetSheet({super.key, required this.category, this.current});
  final SpendCategory category;
  final double? current;
  @override
  ConsumerState<BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<BudgetSheet> {
  late final _amount = TextEditingController(
    text: widget.current == null ? '' : Money.number(widget.current!),
  );
  bool _busy = false;
  late String? _iconKey = widget.category.iconKey;

  Future<void> _pickIcon(String key) async {
    setState(() => _iconKey = key);
    await ref.read(repositoryProvider).setCategoryIcon(widget.category, key);
    ref.invalidate(categoriesProvider);
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save(double value) async {
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).setBudget(widget.category, value);
      ref.read(analyticsProvider).track(AnalyticsEvent.budgetCreated);
      ref.read(analyticsProvider).track(AnalyticsEvent.firstBudgetSet);
      ref.invalidate(budgetProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: widget.category.label,
    subtitle: 'Monthly budget, from this month on.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: '0',
            prefixIcon: CurrencyPrefix('AED'),
            prefixIconConstraints: kCurrencyPrefixConstraints,
          ),
        ),
        if (widget.category.custom) ...[
          const SizedBox(height: Space.lg),
          Text('Icon', style: context.tt.labelMedium),
          const SizedBox(height: Space.sm),
          CategoryIconPicker(selected: _iconKey, onChanged: _pickIcon),
        ],
        const SizedBox(height: Space.xl),
        PrimaryButton(
          label: 'Save',
          loading: _busy,
          onPressed: () {
            final v = _parseAed(_amount.text);
            if (v != null && v >= 0) _save(v);
          },
        ),
        if (widget.current != null) ...[
          const SizedBox(height: Space.sm),
          PrimaryButton(
            label: 'Remove budget',
            secondary: true,
            destructive: true,
            onPressed: () => _save(0),
          ),
        ],
      ],
    ),
  );
}

/// Create a custom category, optionally with a budget.
class NewCategorySheet extends ConsumerStatefulWidget {
  const NewCategorySheet({super.key});
  @override
  ConsumerState<NewCategorySheet> createState() => _NewCategorySheetState();
}

class _NewCategorySheetState extends ConsumerState<NewCategorySheet> {
  final _name = TextEditingController();
  final _budget = TextEditingController();
  CategoryKind _kind = CategoryKind.expense;
  String? _iconKey;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    final repo = ref.read(repositoryProvider);
    try {
      final cat = await repo.createCategory(
        name: name,
        kind: _kind,
        iconKey: _iconKey,
      );
      final b = _parseAed(_budget.text);
      if (_kind == CategoryKind.expense && b != null && b > 0) {
        await repo.setBudget(cat, b);
      }
      ref.invalidate(categoriesProvider);
      ref.invalidate(budgetProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: 'New category',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Segmented<CategoryKind>(
          segments: const {
            CategoryKind.expense: 'Spending',
            CategoryKind.income: 'Income',
          },
          value: _kind,
          onChanged: (k) => setState(() => _kind = k),
        ),
        const SizedBox(height: Space.lg),
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.curve,
          child: _kind == CategoryKind.expense
              ? Padding(
                  padding: const EdgeInsets.only(top: Space.md),
                  child: TextField(
                    controller: _budget,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Monthly budget (optional)',
                      prefixIcon: CurrencyPrefix('AED'),
                      prefixIconConstraints: kCurrencyPrefixConstraints,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: Space.lg),
        Text('Icon', style: context.tt.labelMedium),
        const SizedBox(height: Space.sm),
        CategoryIconPicker(
          selected: _iconKey,
          onChanged: (k) => setState(() => _iconKey = k),
        ),
        const SizedBox(height: Space.xl),
        PrimaryButton(label: 'Create', loading: _busy, onPressed: _save),
      ],
    ),
  );
}
