import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/router.dart';

import 'package:material_ui/material_ui.dart';

import '../../core/learning/learning_controller.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../backup/backup_widgets.dart';

/// Settings > Privacy > See what would be shared. Built from the same queue
/// and filter the upload uses, so it cannot show less than is sent.
class LearningPreviewScreen extends ConsumerWidget {
  const LearningPreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learning = ref.watch(learningControllerProvider);
    final small = context.tt.bodySmall!.copyWith(
      color: context.pc.textSecondary,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('What would be shared'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.popOrHome(),
        ),
      ),
      body: ListenableBuilder(
        listenable: learning,
        builder: (context, _) {
          final p = learning.preview();
          return ListView(
            padding: const EdgeInsets.only(bottom: Space.xxxl),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.sm,
                  Space.gutter,
                  0,
                ),
                child: Text(
                  !learning.optIn
                      ? 'Help improve categories is off, so nothing is kept or '
                            'shared. Turn it on in Privacy; after you confirm '
                            'categories, what would be shared shows up here.'
                      : (learning.uploadsConfigured
                            ? 'This is everything that would be shared in the next '
                                  'weekly upload. Nothing else leaves your phone.'
                            : 'Sharing is not switched on in this version of Pulse, '
                                  'so nothing is being sent. This is what would be '
                                  'shared once it is.'),
                  style: context.tt.bodyMedium,
                ),
              ),
              const SectionHeader('Shop and category'),
              if (p.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: Text(
                    'Nothing yet. A shop is only included after you have '
                    'confirmed its category on at least two payments.',
                    key: const Key('learning-empty'),
                    style: small,
                  ),
                )
              else
                RowGroup(
                  children: [
                    for (final i in p.items)
                      ListRow(
                        title: i.key,
                        subtitle: '${i.category}, seen ${i.count}x',
                      ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.md,
                  Space.gutter,
                  0,
                ),
                child: Text(
                  '${p.waiting} more shop${p.waiting == 1 ? '' : 's'} waiting '
                  'for a second confirmation (not shared, and not shown). '
                  'About ${p.dropPercent}% of the list above is left out at '
                  'random each time, so nobody can be sure you confirmed any '
                  'one of them.',
                  style: small,
                ),
              ),
              const SectionHeader('Never included'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Callout(
                  icon: Icons.lock_outline_rounded,
                  title: 'Never',
                  text:
                      'Amounts, dates, accounts, your name or id, message text, '
                      'phone numbers, emails, or anything that looks like a person.',
                ),
              ),
              if (learning.optIn)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.xl,
                    Space.gutter,
                    0,
                  ),
                  child: TextAction(
                    'Delete everything waiting',
                    onTap: learning.clearQueue,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
