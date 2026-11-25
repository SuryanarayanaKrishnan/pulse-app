import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'primary_button.dart';

/// Section title. 32pt above (the section rhythm), 4pt below.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.top = Space.section,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(Space.gutter, top, Space.gutter, Space.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: context.tt.titleLarge!.copyWith(
                color: context.tabInk(strength: 0.6),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (action != null) TextAction(action!, onTap: onAction),
      ],
    ),
  );
}
