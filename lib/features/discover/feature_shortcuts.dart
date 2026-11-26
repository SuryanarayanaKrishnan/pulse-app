import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import 'all_features_sheet.dart';
import 'feature_catalog.dart';

/// A calm row of quick links under a tab header: the two or three features
/// that belong to this tab but are easy to miss, and "All features".
class FeatureShortcuts extends StatelessWidget {
  const FeatureShortcuts({super.key, required this.ids});
  final List<String> ids;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    Widget chip(Key key, IconData icon, String label, VoidCallback onTap) =>
        Semantics(
          button: true,
          label: label,
          child: Pressable(
            onTap: onTap,
            child: Container(
              key: key,
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: c.accent),
                  const SizedBox(width: Space.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.labelLarge!.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.lg,
      ),
      child: Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          for (final id in ids)
            chip(
              Key('shortcut-$id'),
              featureById(id).icon,
              featureById(id).title,
              () {
                context.push(featureById(id).route);
              },
            ),
          chip(
            const Key('shortcut-all'),
            Icons.apps_rounded,
            'All features',
            () => showAllFeaturesSheet(context),
          ),
        ],
      ),
    );
  }
}
