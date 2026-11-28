import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import 'feature_catalog.dart';

/// "All features": a searchable list of everything that is not a tab, so
/// nothing is hidden three taps deep.
Future<void> showAllFeaturesSheet(BuildContext context) => showPulseSheet<void>(
  context,
  full: true,
  builder: (_) => const AllFeaturesSheet(),
);

class AllFeaturesSheet extends StatefulWidget {
  const AllFeaturesSheet({super.key});
  @override
  State<AllFeaturesSheet> createState() => _AllFeaturesSheetState();
}

class _AllFeaturesSheetState extends State<AllFeaturesSheet> {
  String _q = '';

  void _open(PulseFeature f) {
    // The sheet sits on the root navigator; close it, then go.
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(f.route);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final hits = [
      for (final f in pulseFeatures)
        if (f.matches(_q)) f,
    ];
    final groups = <String>[];
    for (final f in hits) {
      if (!groups.contains(f.group)) groups.add(f.group);
    }
    return SheetScaffold(
      title: 'All features',
      subtitle: 'Everything in one place. Try "repeat" or "joint".',
      // SheetScaffold already scrolls; a nested ListView here fought it and
      // made the sheet bounce back up.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('features-search'),
            onChanged: (v) => setState(() => _q = v),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search features',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: Space.md),
          if (hits.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Text(
                'Nothing matches "$_q".',
                textAlign: TextAlign.center,
                style: context.tt.bodyMedium!.copyWith(color: c.textSecondary),
              ),
            ),
          for (final g in groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xs),
              child: Text(
                g.toUpperCase(),
                style: context.tt.labelSmall!.copyWith(
                  color: c.textTertiary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            RowGroup(
              padding: EdgeInsets.zero,
              indent: ListRow.leadingInset,
              children: [
                for (final f in hits.where((f) => f.group == g))
                  ListRow(
                    key: Key('feature-${f.id}'),
                    leading: IconWell(f.icon, color: c.calm),
                    title: f.title,
                    subtitle: f.subtitle,
                    chevron: true,
                    onTap: () => _open(f),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Space.lg),
        ],
      ),
    );
  }
}
