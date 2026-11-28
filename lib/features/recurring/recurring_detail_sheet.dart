import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/recurring.dart';
import '../../core/engine/recurring_plan.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/recurring_providers.dart';
import 'recurring_screen.dart';

/// Opens the detail for any item: a detected series gets its history and the
/// confirm / not-recurring choice; a card due or a bill gets a short note.
Future<void> showRecurringItem(BuildContext context, RecItem item) {
  final s = item.series;
  if (s != null) return showRecurringDetail(context, s);
  return showPulseSheet<void>(context, builder: (_) => _PlainItemSheet(item));
}

Future<void> showRecurringDetail(BuildContext context, Series s) =>
    showPulseSheet<void>(context, builder: (_) => RecurringDetailSheet(s));

Future<void> showHiddenRecurring(BuildContext context) =>
    showPulseSheet<void>(context, builder: (_) => const _HiddenSheet());

class _PlainItemSheet extends StatelessWidget {
  const _PlainItemSheet(this.item);
  final RecItem item;

  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: item.title,
    subtitle: item.kind == RecKind.cardDue
        ? 'Card payment due ${dayLabel(item.dueOn)}'
        : 'Household bill, your share, due ${dayLabel(item.dueOn)}',
    child: Text(
      Money.aed(item.amountMinor / 100),
      style: PulseTheme.amount(context.pc.textPrimary, size: 28),
    ),
  );
}

class RecurringDetailSheet extends ConsumerWidget {
  const RecurringDetailSheet(this.series, {super.key});
  final Series series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final choice = ref.watch(recurringChoicesProvider).value?[series.key];
    final charges =
        ref.watch(recurringChargesProvider).value ?? const <Charge>[];
    final history = historyOf(series, charges);
    final s = series;
    Future<void> choose(RecChoice? v) async {
      await ref.read(recurringChoicesProvider.notifier).choose(s, v);
      if (context.mounted && v == RecChoice.ignored)
        Navigator.of(context).pop();
    }

    return SheetScaffold(
      title: s.merchant,
      subtitle:
          '${cadenceLabel(s.cadence)} · ${s.isSubscription ? 'subscription' : 'payment'}'
          '${choice == RecChoice.confirmed ? ' · confirmed' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${s.amountKind == 'variable' ? '~' : ''}${Money.aed(s.typicalAmountMinor / 100, decimals: false)}',
            style: PulseTheme.amount(c.textPrimary, size: 32),
          ),
          const SizedBox(height: Space.xs),
          Text(
            s.status == 'lapsed'
                ? 'No charge since ${dayLabel(s.lastChargeOn)}. It looks stopped.'
                : (s.status == 'due'
                      ? 'Expected ${dayLabel(s.nextExpectedOn)}, not seen yet.'
                      : 'Next expected ${dayLabel(s.nextExpectedOn)}.'),
            key: const Key('rec_next'),
            style: context.tt.bodyMedium,
          ),
          if (s.priceIncrease != null) ...[
            const SizedBox(height: Space.md),
            SurfaceCard(
              padding: const EdgeInsets.all(Space.md),
              child: Row(
                children: [
                  Icon(Icons.trending_up_rounded, size: 18, color: c.warning),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      'Up ${s.priceIncrease!.pct.toStringAsFixed(0)}% from ${Money.number(s.priceIncrease!.fromMinor / 100)} '
                      'to ${Money.number(s.priceIncrease!.toMinor / 100)}.',
                      style: context.tt.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Space.xl),
          if (choice == null) ...[
            PrimaryButton(
              label: 'Yes, this is recurring',
              onPressed: () => choose(RecChoice.confirmed),
            ),
            const SizedBox(height: Space.sm),
            PrimaryButton(
              secondary: true,
              label: 'Not recurring',
              onPressed: () => choose(RecChoice.ignored),
            ),
          ] else ...[
            if (choice == RecChoice.confirmed)
              PrimaryButton(
                secondary: true,
                label: 'Not recurring',
                onPressed: () => choose(RecChoice.ignored),
              ),
            if (choice == RecChoice.confirmed) const SizedBox(height: Space.sm),
            PrimaryButton(
              secondary: true,
              label: choice == RecChoice.ignored
                  ? 'Show it again'
                  : 'Clear my choice',
              onPressed: () => choose(null),
            ),
          ],
          const SizedBox(height: Space.lg),
          Text('History', style: context.tt.titleSmall),
          const SizedBox(height: Space.xs),
          RowGroup(
            key: const Key('rec_history'),
            children: [
              for (final h in history.take(6))
                ListRow(
                  dense: true,
                  title: dayLabel(h.postedOn),
                  subtitle: '${h.postedOn.year}',
                  trailing: Text(
                    Money.aed(h.amountMinor / 100, decimals: false),
                    style: PulseTheme.amount(c.textPrimary, size: 15),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HiddenSheet extends ConsumerWidget {
  const _HiddenSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choices = ref.watch(recurringChoicesProvider).value ?? const {};
    final series = ref.watch(recurringSeriesProvider).value ?? const <Series>[];
    final names = {for (final s in series) s.key: s.merchant};
    final hidden = [
      for (final e in choices.entries)
        if (e.value == RecChoice.ignored) e.key,
    ];
    return SheetScaffold(
      title: 'Not recurring',
      subtitle: 'Hidden from totals and the calendar.',
      child: RowGroup(
        children: [
          for (final k in hidden)
            ListRow(
              title: names[k] ?? k.split('#').first,
              trailing: TextAction(
                'Show',
                onTap: () {
                  final s = series.where((s) => s.key == k).firstOrNull;
                  if (s != null)
                    ref.read(recurringChoicesProvider.notifier).choose(s, null);
                },
              ),
            ),
        ],
      ),
    );
  }
}
