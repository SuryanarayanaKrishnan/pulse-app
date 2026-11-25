import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/digit_suggestion.dart';
import '../../data/providers.dart';

/// Digits the user said "not mine" to, for this run of the app.
final dismissedDigitsProvider = NotifierProvider<_Dismissed, Set<String>>(_Dismissed.new);

class _Dismissed extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};
  void add(String last4) => state = {...state, last4};
}

Future<void> _assign(BuildContext context, WidgetRef ref, String accountId, String last4) async {
  try {
    await ref.read(repositoryProvider).setCardLast4(accountId, last4);
    invalidateWallet(ref);
  } on Object catch (e) {
    if (context.mounted) {
      final msg = e is ApiException ? e.message : 'That did not work. Try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

/// One question at a time, answered with one tap, above the wallet.
class DigitSuggestionBanner extends ConsumerWidget {
  const DigitSuggestionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(dismissedDigitsProvider);
    final list = [
      for (final s in ref.watch(digitSuggestionsProvider).value ?? const <DigitSuggestion>[])
        if (!dismissed.contains(s.last4)) s,
    ];
    if (list.isEmpty) return const SizedBox.shrink();
    final s = list.first;
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
      child: Container(
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.question, style: context.tt.titleMedium),
            const SizedBox(height: Space.xs),
            Text(
              '${s.waiting} ${s.waiting == 1 ? 'alert is' : 'alerts are'} waiting. Say yes and they are added.',
              style: context.tt.bodySmall!.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'Yes',
                    onPressed: () {
                      if (s.candidates.length == 1) {
                        _assign(context, ref, s.candidates.single.id, s.last4);
                      } else {
                        showPulseSheet<void>(context, builder: (_) => _WhichCardSheet(s));
                      }
                    },
                  ),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: PrimaryButton(
                    label: 'Not mine',
                    secondary: true,
                    onPressed: () => ref.read(dismissedDigitsProvider.notifier).add(s.last4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WhichCardSheet extends ConsumerWidget {
  const _WhichCardSheet(this.s);
  final DigitSuggestion s;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SheetScaffold(
    title: 'Which card is ••${s.last4}?',
    child: RowGroup(
      children: [
        for (final cand in s.candidates)
          ListRow(
            title: cand.label,
            chevron: true,
            onTap: () {
              Navigator.of(context).pop();
              _assign(context, ref, cand.id, s.last4);
            },
          ),
      ],
    ),
  );
}

/// Add the last four digits to a card that was quick-added.
Future<void> showAddDigits(BuildContext context, String accountId) =>
    showPulseSheet<void>(context, builder: (_) => _AddDigitsSheet(accountId));

class _AddDigitsSheet extends ConsumerStatefulWidget {
  const _AddDigitsSheet(this.accountId);
  final String accountId;
  @override
  ConsumerState<_AddDigitsSheet> createState() => _AddDigitsSheetState();
}

class _AddDigitsSheetState extends ConsumerState<_AddDigitsSheet> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nav = Navigator.of(context);
    await _assign(context, ref, widget.accountId, _ctl.text.trim());
    if (mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: 'Last four digits',
    subtitle: 'So alerts from your bank land on the right card. Only these four are kept.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          decoration: const InputDecoration(hintText: '1234'),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _ctl.text.length == 4 ? _save() : null,
        ),
        const SizedBox(height: Space.lg),
        PrimaryButton(label: 'Save', onPressed: _ctl.text.trim().length == 4 ? _save : null),
      ],
    ),
  );
}
