import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/budget_moves.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../goals/goal_widgets.dart' show aedMinor;

/// A category the money can come from: what it has planned right now.
class MoveSource {
  const MoveSource(this.category, this.plannedMinor, this.spentMinor, {this.saved = false});
  final SpendCategory category;
  final int plannedMinor;
  final int spentMinor;

  /// Money set aside for something later (a sinking fund): offered last.
  final bool saved;
  int get spareMinor => plannedMinor - spentMinor;
}

/// Opens Move money. [scope] says whose budget it is: Mine, or the Joint
/// limits. [to] pre-selects the receiving category, [suggestMinor] the amount
/// (the overspend being covered). Shows an Undo bar when done.
Future<void> showMoveMoney(
  BuildContext context,
  WidgetRef ref, {
  required DateTime month,
  required MoveScope scope,
  required List<MoveSource> sources,
  required List<SpendCategory> targets,
  String? to,
  int? suggestMinor,
  VoidCallback? onChanged,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final svc = ref.read(budgetPlanServiceProvider);
  final move = await showPulseSheet<BudgetMove>(
    context,
    builder: (_) => MoveMoneySheet(
      month: month,
      scope: scope,
      sources: sources,
      targets: targets,
      to: to,
      suggestMinor: suggestMinor,
    ),
  );
  if (move == null) return;
  onChanged?.call();
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    SnackBar(
      content: Text('Moved ${aedMinor(move.amountMinor)}'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          await svc.undoMove(move.id);
          onChanged?.call();
        },
      ),
    ),
  );
}

class MoveMoneySheet extends ConsumerStatefulWidget {
  const MoveMoneySheet({
    super.key,
    required this.month,
    required this.scope,
    required this.sources,
    required this.targets,
    this.to,
    this.suggestMinor,
  });
  final DateTime month;
  final MoveScope scope;
  final List<MoveSource> sources;
  final List<SpendCategory> targets;
  final String? to;
  final int? suggestMinor;

  @override
  ConsumerState<MoveMoneySheet> createState() => _MoveState();
}

class _MoveState extends ConsumerState<MoveMoneySheet> {
  String? _from, _to;
  late final _amount = TextEditingController(
    text: widget.suggestMinor == null || widget.suggestMinor! <= 0 ? '' : _fmt(widget.suggestMinor!),
  );
  String? _error;

  static String _fmt(int minor) => minor % 100 == 0 ? '${minor ~/ 100}' : (minor / 100).toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _to = widget.to;
    // The category with the most to spare is the natural source.
    final spare = [...widget.sources.where((s) => s.category.id != _to && s.spareMinor > 0)]
      ..sort((a, b) => a.saved != b.saved ? (a.saved ? 1 : -1) : b.spareMinor.compareTo(a.spareMinor));
    _from = spare.isEmpty ? null : spare.first.category.id;
    _reveal();
  }

  @override
  void dispose() {
    for (final c in _rows.values) {
      c.dispose();
    }
    _amount.dispose();
    super.dispose();
  }

  MoveSource? get _source => widget.sources.where((s) => s.category.id == _from).firstOrNull;

  int? get _minor {
    final v = double.tryParse(_amount.text.replaceAll(',', ''));
    return v == null || v <= 0 ? null : (v * 100).round();
  }

  Future<void> _go() async {
    final svc = ref.read(budgetPlanServiceProvider);
    final (move, problem) = await svc.move(
      month: widget.month,
      fromId: _from!,
      toId: _to!,
      amountMinor: _minor!,
      scope: widget.scope,
      sourcePlannedMinor: _source?.plannedMinor ?? 0,
    );
    if (!mounted) return;
    if (move != null) {
      Navigator.of(context).pop(move);
      return;
    }
    setState(() {
      _error = switch (problem!) {
        MoveProblem.exceedsSource => 'That is more than ${_source?.category.label ?? 'it'} has planned.',
        MoveProblem.sameCategory => 'Pick two different categories.',
        _ => 'Enter an amount above zero.',
      };
    });
  }

  final _keys = <String, GlobalKey>{};
  final _rows = <String, ScrollController>{};
  Key _selKey(String label) => _keys.putIfAbsent(label, GlobalKey.new);
  ScrollController _rowController(String label) => _rows.putIfAbsent(label, ScrollController.new);

  /// The chosen pill can sit off the edge of its row: scroll that row (and
  /// only that row) so it shows.
  void _reveal() => WidgetsBinding.instance.addPostFrameCallback((_) {
    for (final e in _keys.entries) {
      final box = e.value.currentContext?.findRenderObject() as RenderBox?;
      final row = _rows[e.key];
      final viewport = row?.position.context.notificationContext?.findRenderObject() as RenderBox?;
      if (box == null || row == null || viewport == null || !row.hasClients) continue;
      final dx = box.localToGlobal(Offset.zero, ancestor: viewport).dx + row.offset;
      row.jumpTo((dx - 12).clamp(0, row.position.maxScrollExtent).toDouble());
    }
  });

  Widget _picker(String label, String? value, ValueChanged<String> onPick, Iterable<SpendCategory> options, {String? hide}) {
    final c = context.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.tt.labelMedium!.copyWith(color: c.textSecondary)),
        const SizedBox(height: Space.sm),
        // One scrolling row: twenty categories as a wrap would fill the sheet.
        SingleChildScrollView(
          controller: _rowController(label),
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final cat in options)
                if (cat.id != hide)
                  Padding(
                    padding: const EdgeInsets.only(right: Space.sm),
                    child: Pill(
                      cat.label,
                      key: cat.id == value ? _selKey(label) : Key('${label.toLowerCase()}_${cat.id}'),
                      leading: CategoryIcon(cat, size: 16),
                      selected: cat.id == value,
                      onTap: () => setState(() {
                        onPick(cat.id);
                        _error = null;
                      }),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final src = _source;
    final ready = _from != null && _to != null && _minor != null;
    return SheetScaffold(
      title: 'Move money',
      subtitle:
          '${DateFormat('MMMM').format(widget.month)} only · ${widget.scope == MoveScope.joint ? 'Joint limits' : 'Your budget'}. The total stays the same.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _picker('From', _from, (v) => _from = v, [for (final s in widget.sources) s.category], hide: _to),
          const SizedBox(height: Space.lg),
          _picker('To', _to, (v) => _to = v, widget.targets, hide: _from),
          const SizedBox(height: Space.lg),
          TextField(
            key: const Key('move_amount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Amount', prefixIcon: CurrencyPrefix('AED'),
 prefixIconConstraints: kCurrencyPrefixConstraints),
            onChanged: (_) => setState(() => _error = null),
          ),
          if (src != null) ...[
            const SizedBox(height: Space.sm),
            Text(
              '${src.category.label} has ${aedMinor(src.plannedMinor)} planned, ${aedMinor(src.spareMinor < 0 ? 0 : src.spareMinor)} unspent.',
              style: context.tt.bodySmall,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: Space.sm),
            Text(_error!, key: const Key('move_error'), style: context.tt.bodySmall!.copyWith(color: c.negative)),
          ],
          const SizedBox(height: Space.xl),
          PrimaryButton(key: const Key('move_go'), label: 'Move', onPressed: ready ? _go : null),
        ],
      ),
    );
  }
}
