import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

/// "‹ November 2026 ›": steps the month the plan and the cash flow show.
/// Never past the current month; back as far as [monthsBack].
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.onChanged, this.now, this.monthsBack = 24});
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final DateTime? now;
  final int monthsBack;

  @override
  Widget build(BuildContext context) {
    final n = now ?? DateTime.now();
    final cur = n.year * 12 + n.month - 1;
    final idx = month.year * 12 + month.month - 1;
    DateTime at(int i) => DateTime(i ~/ 12, i % 12 + 1, 1);
    final canBack = idx > cur - monthsBack, canFwd = idx < cur;
    final c = context.pc;
    Widget arrow(IconData icon, String label, bool on, int to) => Semantics(
      button: true,
      enabled: on,
      label: label,
      child: Pressable(
        onTap: on ? () => onChanged(at(to)) : null,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: on ? c.textPrimary : c.textTertiary.withValues(alpha: 0.4)),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter - 8),
      child: Row(
        key: const Key('month_switcher'),
        children: [
          arrow(Icons.chevron_left_rounded, 'Previous month', canBack, idx - 1),
          Expanded(
            child: Text(
              DateFormat('MMMM y').format(month),
              textAlign: TextAlign.center,
              style: context.tt.titleSmall,
            ),
          ),
          arrow(Icons.chevron_right_rounded, 'Next month', canFwd, idx + 1),
        ],
      ),
    );
  }
}
