import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// Pick a category from the default and custom set.
Future<SpendCategory?> pickCategory(
  BuildContext context, {
  SpendCategory? selected,
  bool includeIncome = true,
  String title = 'Category',
}) => showPulseSheet<SpendCategory>(
  context,
  full: true,
  builder: (_) => _CategoryPicker(
    selected: selected,
    includeIncome: includeIncome,
    title: title,
  ),
);

class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker({
    required this.selected,
    required this.includeIncome,
    required this.title,
  });
  final SpendCategory? selected;
  final bool includeIncome;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final cats = ref.watch(categoriesProvider).value ?? SpendCategory.defaults;
    final groups = <String, List<SpendCategory>>{
      'Spending': [
        for (final x in cats)
          if (x.kind == CategoryKind.expense) x,
      ],
      if (includeIncome)
        'Income': [
          for (final x in cats)
            if (x.isIncome) x,
        ],
      'Transfers': [
        for (final x in cats)
          if (x.isTransfer) x,
      ],
    };
    return SheetScaffold(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final g in groups.entries)
            if (g.value.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: Space.xs),
                child: Text(g.key, style: context.tt.bodySmall),
              ),
              RowGroup(
                padding: EdgeInsets.zero,
                indent: ListRow.leadingInset,
                children: [
                  for (final x in g.value)
                    ListRow(
                      dense: true,
                      leading: IconWell(x.icon),
                      title: x.label,
                      trailing: x == selected
                          ? Icon(Icons.check_rounded, color: c.accent, size: 20)
                          : null,
                      onTap: () => Navigator.of(context).pop(x),
                    ),
                ],
              ),
              const SizedBox(height: Space.xl),
            ],
        ],
      ),
    );
  }
}
