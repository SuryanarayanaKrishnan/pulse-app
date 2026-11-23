import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      Space.gutter,
      Space.xl,
      Space.gutter,
      Space.md,
    ),
    child: Row(
      children: [
        Expanded(child: Text(title, style: context.tt.titleLarge)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: context.tt.labelMedium!.copyWith(color: context.pc.accent),
            ),
          ),
      ],
    ),
  );
}
