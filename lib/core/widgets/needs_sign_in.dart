import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/auth/session.dart';
import '../network/cloud_access.dart';
import '../theme/tokens.dart';
import 'primary_button.dart';
import 'surface_card.dart';

/// The one "Available once you're signed in" state, used by every feature
/// that needs a Pulse account (splitting, family sharing, Gmail, cloud
/// backup). Calm on purpose: nothing failed, it is just not switched on.
///
/// [feature] says what is waiting ("Gmail statements"); [detail] is an
/// optional second line. A Sign in button shows only when signing in would
/// help (a backend exists and nobody is signed in to it).
class NeedsSignIn extends ConsumerWidget {
  const NeedsSignIn({
    super.key,
    required this.feature,
    this.detail,
    this.compact = false,
    this.onSignIn,
  });

  final String feature;
  final String? detail;

  /// A single line for use inside a row group or sheet.
  final bool compact;

  /// Overrides the default (leave the app's signed-in state so the sign-in
  /// screen opens).
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final access = ref.watch(cloudAccessProvider);
    void signIn() {
      if (onSignIn != null) return onSignIn!();
      ref.read(sessionProvider).requestSignIn();
    }

    final button = access.canSignIn
        ? PrimaryButton(label: 'Sign in', expand: false, onPressed: signIn)
        : null;
    if (compact) {
      return Row(
        key: const Key('needs_sign_in'),
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: c.textTertiary),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(needsSignInTitle, style: context.tt.bodySmall)),
          if (access.canSignIn)
            TextButton(onPressed: signIn, child: const Text('Sign in')),
        ],
      );
    }
    return SurfaceCard(
      key: const Key('needs_sign_in'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: c.textSecondary,
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(needsSignInTitle, style: context.tt.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(feature, style: context.tt.bodyMedium),
          if (detail != null) ...[
            const SizedBox(height: Space.xs),
            Text(detail!, style: context.tt.bodySmall),
          ],
          if (button != null) ...[const SizedBox(height: Space.md), button],
        ],
      ),
    );
  }
}
