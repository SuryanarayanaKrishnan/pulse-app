import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// Type your salary and payday by hand. It feeds cash flow straight away, and
/// a salary credit Pulse detects later confirms it (and updates the amount).
class SalarySheet extends ConsumerStatefulWidget {
  const SalarySheet({super.key, this.current});
  final ManualSalary? current;

  @override
  ConsumerState<SalarySheet> createState() => _SalarySheetState();
}

class _SalarySheetState extends ConsumerState<SalarySheet> {
  late final _amount = TextEditingController(
    text: widget.current == null
        ? ''
        : (widget.current!.amountMinor / 100).toStringAsFixed(
            widget.current!.amountMinor % 100 == 0 ? 0 : 2,
          ),
  );
  late final _day = TextEditingController(
    text: widget.current?.day.toString() ?? '25',
  );
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _day.dispose();
    super.dispose();
  }

  double? get _amt {
    final a = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    return (a == null || a <= 0 || !a.isFinite) ? null : a;
  }

  int? get _dayNum {
    final d = int.tryParse(_day.text.trim());
    return (d == null || d < 1 || d > 31) ? null : d;
  }

  Future<void> _save(ManualSalary? value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).setManualSalary(value);
      ref.invalidate(manualSalaryProvider);
      invalidateLedger(ref);
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Could not save your salary. Try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = _amt != null && _dayNum != null;
    return SheetScaffold(
      title: 'Your salary',
      subtitle: 'Used for cash flow until your bank\'s salary alert arrives. Then Pulse uses the real one.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('salary_amount'),
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Monthly salary',
              prefixIcon: CurrencyPrefix('AED'),
              prefixIconConstraints: kCurrencyPrefixConstraints,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            key: const Key('salary_day'),
            controller: _day,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Payday (day of month, 1 to 31)',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            label: 'Save',
            loading: _busy,
            onPressed: ok
                ? () => _save(
                    ManualSalary(
                      amountMinor: (_amt! * 100).round(),
                      day: _dayNum!,
                    ),
                  )
                : null,
          ),
          if (widget.current != null) ...[
            const SizedBox(height: Space.sm),
            Center(
              child: TextAction(
                'Remove',
                color: context.pc.negative,
                onTap: () => _save(null),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
