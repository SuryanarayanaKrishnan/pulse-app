import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../router/router.dart';
import '../theme/tokens.dart';
import 'entitlement.dart';

/// Opens the paywall for [feature].
void showPaywall(BuildContext context, PlusFeature feature) =>
    context.push('${Routes.plus}?feature=${feature.name}');

/// Runs [onAllowed] when the user has Plus, otherwise opens the paywall.
/// Use this in front of any LLM call or niche-intel action.
bool requirePlus(
  BuildContext context,
  WidgetRef ref,
  PlusFeature feature, [
  VoidCallback? onAllowed,
]) {
  if (ref.read(canUseProvider(feature))) {
    onAllowed?.call();
    return true;
  }
  showPaywall(context, feature);
  return false;
}

/// Small "Plus" marker used on locked rows.
class PlusBadge extends StatelessWidget {
  const PlusBadge({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: c.isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        'PLUS',
        style: context.tt.labelSmall!.copyWith(
          color: c.accent,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
