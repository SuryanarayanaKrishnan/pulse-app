import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Space.xxl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: context.pc.textTertiary, size: 40),
        const SizedBox(height: Space.lg),
        Text(title, style: context.tt.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: Space.sm),
        Text(
          message,
          style: context.tt.bodyMedium,
          textAlign: TextAlign.center,
        ),
        if (action != null) ...[const SizedBox(height: Space.xl), action!],
      ],
    ),
  );
}
