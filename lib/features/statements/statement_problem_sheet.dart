import 'package:material_ui/material_ui.dart';

import '../../core/engine/sheet_import.dart';
import '../../core/engine/statement_import.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

enum StatementProblemAction { chooseAnother, sendSample, mapColumns }

String statementProblemTitle(StatementProblem p) => switch (p) {
  StatementProblem.emptyFile => 'That file is empty',
  StatementProblem.wrongFormat => 'Not a statement file',
  StatementProblem.legacyExcel => 'Old Excel file',
  StatementProblem.passwordNeeded => 'Password needed',
  StatementProblem.wrongPassword => 'Password did not work',
  StatementProblem.scannedPdf => 'This PDF is a scan',
  StatementProblem.unsupportedBank => 'Bank not supported yet',
  StatementProblem.unrecognisedLayout => 'Columns not recognised',
  StatementProblem.damaged => 'Could not read this PDF',
  StatementProblem.couldNotOpen => 'Could not open the file',
};

/// A statement that could not be read: what is wrong, what to do next, and
/// the buttons that do it. Pops with the chosen [StatementProblemAction].
class StatementProblemSheet extends StatelessWidget {
  const StatementProblemSheet({super.key, required this.problem});
  final StatementImportException problem;

  @override
  Widget build(BuildContext context) {
    final p = problem;
    return SheetScaffold(
      title: statementProblemTitle(p.problem),
      subtitle: p.filename,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            p.message,
            key: const Key('problem_message'),
            style: context.tt.bodyLarge,
          ),
          if (p.nextStep.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Text(
              p.nextStep,
              key: const Key('problem_next_step'),
              style: context.tt.bodyMedium,
            ),
          ],
          const SizedBox(height: Space.xl),
          if (p.canMapColumns) ...[
            PrimaryButton(
              label: 'Choose the columns',
              onPressed: () =>
                  Navigator.of(context).pop(StatementProblemAction.mapColumns),
            ),
            const SizedBox(height: Space.sm),
          ],
          if (p.canSendSample) ...[
            PrimaryButton(
              label: 'Send us a sample',
              secondary: p.canMapColumns,
              onPressed: () =>
                  Navigator.of(context).pop(StatementProblemAction.sendSample),
            ),
            const SizedBox(height: Space.sm),
          ],
          PrimaryButton(
            label: 'Choose another file',
            secondary: p.canMapColumns || p.canSendSample,
            onPressed: () =>
                Navigator.of(context).pop(StatementProblemAction.chooseAnother),
          ),
        ],
      ),
    );
  }
}

/// The fallback for a CSV or Excel export whose columns Pulse does not know:
/// pick the date, description and amount columns once.
class ColumnMappingSheet extends StatefulWidget {
  const ColumnMappingSheet({super.key, required this.rows});
  final List<List<String>> rows;

  @override
  State<ColumnMappingSheet> createState() => _ColumnMappingSheetState();
}

class _ColumnMappingSheetState extends State<ColumnMappingSheet> {
  late final List<List<String>> _rows = [
    for (final r in widget.rows)
      if (r.any((c) => c.trim().isNotEmpty)) r,
  ];
  late final int _width = _rows.fold(0, (m, r) => r.length > m ? r.length : m);
  bool _header = true;
  bool _split = false; // separate debit and credit columns
  bool _positiveIsDebit = true;
  int? _date, _desc, _amount, _debit, _credit;

  @override
  void initState() {
    super.initState();
    _guess();
  }

  List<List<String>> get _data => _rows.skip(_header ? 1 : 0).take(40).toList();

  String _cell(List<String> r, int i) => i < r.length ? r[i].trim() : '';

  void _guess() {
    int share(int col, bool Function(String) test) =>
        _data.where((r) => test(_cell(r, col))).length;
    int? best(bool Function(String) test) {
      int? bi;
      var bs = 0;
      for (var i = 0; i < _width; i++) {
        final s = share(i, test);
        if (s > bs) {
          bs = s;
          bi = i;
        }
      }
      return bi;
    }

    _date = best(
      (c) =>
          c.isNotEmpty &&
          parseDateCell(c) != null &&
          RegExp(r'\d').hasMatch(c) &&
          c.length >= 6,
    );
    _amount = best(
      (c) =>
          c.isNotEmpty &&
          parseAmountMinor(c) != null &&
          c.contains(RegExp(r'[.,]\d{2}$')),
    );
    int? bd;
    var bl = 0.0;
    for (var i = 0; i < _width; i++) {
      if (i == _date || i == _amount) continue;
      final texts = _data
          .map((r) => _cell(r, i))
          .where((c) => c.isNotEmpty && parseAmountMinor(c) == null);
      if (texts.isEmpty) continue;
      final avg = texts.fold<int>(0, (m, c) => m + c.length) / texts.length;
      if (avg > bl) {
        bl = avg;
        bd = i;
      }
    }
    _desc = bd;
  }

  String _label(int i) {
    final letter = String.fromCharCode(65 + (i % 26));
    final head = _header && _rows.isNotEmpty ? _cell(_rows.first, i) : '';
    final sample = _data.isEmpty ? '' : _cell(_data.first, i);
    final hint = head.isNotEmpty ? head : sample;
    final clipped = hint.length > 18 ? '${hint.substring(0, 18)}…' : hint;
    return hint.isEmpty ? 'Column $letter' : 'Column $letter · $clipped';
  }

  bool get _ready =>
      _date != null &&
      _desc != null &&
      (_split ? (_debit != null || _credit != null) : _amount != null);

  Widget _toggle(
    Key key,
    String title,
    bool value,
    ValueChanged<bool> onChanged, {
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.tt.bodyLarge),
                if (subtitle != null)
                  Text(subtitle, style: context.tt.bodySmall),
              ],
            ),
          ),
          Switch.adaptive(key: key, value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _picker(
    String label,
    int? value,
    ValueChanged<int?> onChanged, {
    Key? key,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.tt.bodySmall),
          DropdownButton<int>(
            key: key,
            isExpanded: true,
            value: value,
            hint: const Text('Choose a column'),
            items: [
              for (var i = 0; i < _width; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(_label(i), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final preview = _rows.take(4).toList();
    return SheetScaffold(
      title: 'Choose the columns',
      subtitle: 'Pulse could not tell which column is which. Pick them once.',
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final r in preview)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          [
                            for (var i = 0; i < _width; i++)
                              _cell(r, i).padRight(14).substring(0, 14),
                          ].join(' │ '),
                          style: context.tt.bodySmall!.copyWith(
                            fontFamily: 'monospace',
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.md),
              _toggle(
                const Key('map_header'),
                'First row is a header',
                _header,
                (v) => setState(() {
                  _header = v;
                  _guess();
                }),
              ),
              _picker(
                'Date',
                _date,
                (v) => setState(() => _date = v),
                key: const Key('map_date'),
              ),
              _picker(
                'Description',
                _desc,
                (v) => setState(() => _desc = v),
                key: const Key('map_desc'),
              ),
              _toggle(
                const Key('map_split'),
                'Money in and out are separate columns',
                _split,
                (v) => setState(() => _split = v),
              ),
              if (_split) ...[
                _picker(
                  'Money out (debit)',
                  _debit,
                  (v) => setState(() => _debit = v),
                  key: const Key('map_debit'),
                ),
                _picker(
                  'Money in (credit)',
                  _credit,
                  (v) => setState(() => _credit = v),
                  key: const Key('map_credit'),
                ),
              ] else ...[
                _picker(
                  'Amount',
                  _amount,
                  (v) => setState(() => _amount = v),
                  key: const Key('map_amount'),
                ),
                _toggle(
                  const Key('map_positive'),
                  'Positive amounts are spending',
                  _positiveIsDebit,
                  (v) => setState(() => _positiveIsDebit = v),
                  subtitle:
                      'Turn off if money you spend shows as a negative number.',
                ),
              ],
              const SizedBox(height: Space.lg),
              PrimaryButton(
                label: 'Read the statement',
                onPressed: !_ready
                    ? null
                    : () => Navigator.of(context).pop(
                        StatementColumns(
                          date: _date!,
                          description: _desc!,
                          amount: _split ? null : _amount,
                          debit: _split ? _debit : null,
                          credit: _split ? _credit : null,
                          firstRow: _header ? 1 : 0,
                          positiveIsDebit: _split ? null : _positiveIsDebit,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
