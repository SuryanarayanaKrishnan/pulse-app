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
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.all(Space.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  c.accent.withValues(alpha: 0.3),
                  c.accentAlt.withValues(alpha: 0.15),
                ],
              ),
            ),
            child: Icon(icon, color: c.textPrimary, size: 32),
          ),
          const SizedBox(height: Space.lg),
          Text(
            title,
            style: context.tt.titleMedium,
            textAlign: TextAlign.center,
          ),
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
}
