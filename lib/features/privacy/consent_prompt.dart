import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/analytics/privacy_controller.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

/// Asks, once and gently, whether to share anonymous usage. Any answer
/// (including closing the sheet) counts as asked; the default stays off.
Future<void> askForUsageSharingOnce(BuildContext context, WidgetRef ref) async {
  final privacy = ref.read(privacyControllerProvider);
  if (privacy.asked) return;
  final yes = await showPulseSheet<bool>(
    context,
    builder: (ctx) => SheetScaffold(
      title: 'Help improve Pulse?',
      subtitle:
          'You can share a few anonymous facts about how the app is used, '
          'like which screens people get stuck on.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Never your amounts, merchants, names, contacts or messages. '
            'It is off by default, you can see the full list in Settings > Privacy, '
            'and you can change your mind any time.',
            style: ctx.tt.bodyMedium,
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            label: 'Share anonymous usage',
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          const SizedBox(height: Space.sm),
          PrimaryButton(
            label: 'No thanks',
            secondary: true,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          const SizedBox(height: Space.sm),
          Center(
            child: TextAction(
              'See what would be shared',
              onTap: () {
                Navigator.of(ctx).pop(false);
                context.push(Routes.privacy);
              },
            ),
          ),
        ],
      ),
    ),
  );
  await privacy.setSharing(yes == true);
}
