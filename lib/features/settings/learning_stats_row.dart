import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/engine/habit_model.dart';
import '../../core/learning/learning_controller.dart';
import '../../core/widgets/widgets.dart';

/// The text a person can send: counters only, never merchants, amounts or
/// dates, plus the rates worked out from them.
String learningStatsReport(HabitStats s) {
  double rate(int a, int b) => b == 0 ? 0 : (a / b * 100).roundToDouble();
  return const JsonEncoder.withIndent('  ').convert({
    'about': 'Pulse super-app category learning, counts only (on this phone)',
    ...s.toJson(),
    'chipTapRatePct': rate(s.chipTaps, s.chipsShown),
    'firstChipRightPct': rate(s.topChipTaps, s.chipTaps),
    'silentCorrectedPct': rate(s.autoCorrected, s.autoApplied),
  });
}

/// Settings > Beta tools: "Learning stats", shared through the share sheet.
class LearningStatsRow extends ConsumerWidget {
  const LearningStatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.read(merchantMemoryProvider).stats;
    return ListRow(
      key: const Key('settings_learning_stats'),
      leading: const IconWell(Icons.insights_outlined),
      title: 'Learning stats',
      subtitle:
          '${s.chipsShown} chips shown, ${s.chipTaps} tapped, '
          '${s.autoCorrected} corrected. Counts only; tap to send.',
      chevron: true,
      onTap: () async {
        try {
          await SharePlus.instance.share(
            ShareParams(
              text: learningStatsReport(s),
              subject: 'Pulse learning stats',
            ),
          );
        } on Object catch (e) {
          debugPrint('Learning stats share failed: $e');
        }
      },
    );
  }
}
