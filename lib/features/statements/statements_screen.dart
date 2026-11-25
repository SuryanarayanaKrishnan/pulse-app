import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/router/router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/providers.dart';
import '../../data/statements.dart';
import 'statement_actions.dart';

String _period(Statement s) {
  final a = s.periodStart, b = s.periodEnd;
  if (a == null || b == null) return s.filename ?? 'Statement';
  if (a.month == b.month) {
    return '${a.day}–${DateFormat('d MMM').format(b)}';
  }
  return '${DateFormat('d MMM').format(a)} – ${DateFormat('d MMM').format(b)}';
}

String _via(Statement s) => s.source == 'gmail' ? 'Gmail' : 'Upload';

/// Monthly close: every statement reconciled against what Pulse captured.
class StatementsScreen extends ConsumerStatefulWidget {
  const StatementsScreen({super.key});
  @override
  ConsumerState<StatementsScreen> createState() => _StatementsScreenState();
}

class _StatementsScreenState extends ConsumerState<StatementsScreen> {
  bool _closed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final statements = ref.watch(statementsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly close'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.popOrHome(),
        ),
      ),
      body: AsyncView<List<Statement>>(
        value: statements,
        onRetry: () => ref.invalidate(statementsProvider),
        builder: (all) {
          // The month being closed: the latest statement period.
          final ends = [for (final s in all) ?s.periodEnd]..sort();
          final month = ends.isEmpty ? DateTime.now() : ends.last;
          bool inMonth(Statement s) =>
              s.periodEnd == null ||
              (s.periodEnd!.year == month.year &&
                  s.periodEnd!.month == month.month);
          final current = all.where(inMonth).toList();
          final earlier = all.where((s) => !inMonth(s)).toList();
          final needs = current.where((s) => s.needsAttention).toList();
          final rest = current.where((s) => !s.needsAttention).toList();
          final monthName = DateFormat('MMMM').format(month);
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$monthName close', style: context.tt.bodySmall),
                    const SizedBox(height: Space.xs),
                    Text(
                      current.isEmpty
                          ? 'No statements yet.'
                          : '${current.length} statements in. '
                                '${needs.isEmpty ? 'All match.' : '${needs.length} ${needs.length == 1 ? 'thing needs' : 'things need'} you.'}',
                      style: context.tt.headlineMedium,
                    ),
                  ],
                ),
              ),
              if (needs.isNotEmpty) ...[
                const SizedBox(height: Space.xl),
                for (final s in needs)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      0,
                      Space.gutter,
                      Space.md,
                    ),
                    child: _NeedsYou(s),
                  ),
              ],
              if (rest.isNotEmpty) ...[
                const SectionHeader('This month'),
                RowGroup(children: [for (final s in rest) _StatementRow(s)]),
              ],
              const SectionHeader('Sources'),
              const _Sources(),
              const SectionHeader('Statement passwords'),
              const _Passwords(),
              if (earlier.isNotEmpty) ...[
                const SectionHeader('Earlier'),
                RowGroup(children: [for (final s in earlier) _StatementRow(s)]),
              ],
              const SizedBox(height: Space.xxl),
              Padding(
                padding: screenPad,
                child: PrimaryButton(
                  label: _closed
                      ? '$monthName closed'
                      : (needs.isEmpty
                            ? 'Close $monthName'
                            : 'Close $monthName · ${needs.length} left'),
                  secondary: needs.isNotEmpty || _closed,
                  onPressed: needs.isEmpty && !_closed
                      ? () {
                          Haptics.success();
                          setState(() => _closed = true);
                        }
                      : null,
                ),
              ),
              if (needs.isEmpty && !_closed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.sm,
                    Space.gutter,
                    0,
                  ),
                  child: Text(
                    'Every statement matches what Pulse captured.',
                    style: context.tt.bodySmall!.copyWith(color: c.positive),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatementRow extends StatelessWidget {
  const _StatementRow(this.s);
  final Statement s;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final (label, color) = switch (s.state) {
      CloseState.matched => ('Matched', c.positive),
      CloseState.processing => ('Reading', c.textSecondary),
      CloseState.mismatch => ('Mismatch', c.warning),
      CloseState.needsPassword => ('Locked', c.warning),
      CloseState.needsAccount => ('Needs account', c.warning),
      CloseState.failed => ('Unreadable', c.negative),
    };
    return ListRow(
      leading: Dot(color),
      title: s.accountLabel,
      subtitle: '${_period(s)} · ${_via(s)}',
      trailing: Text(
        label,
        style: context.tt.bodyMedium!.copyWith(color: color),
      ),
      onTap: s.parse == ParseStatus.parsed
          ? () => showPulseSheet<void>(
              context,
              full: true,
              builder: (_) => ReconciliationSheet(statement: s),
            )
          : null,
    );
  }
}

/// A statement that needs the user, styled after the Reconcile artboard.
class _NeedsYou extends ConsumerWidget {
  const _NeedsYou(this.s);
  final Statement s;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final bank = institutionName(s.institution);
    final (message, action, onAction) = switch (s.state) {
      CloseState.mismatch => (
        'Off by ${Money.aed(s.diff?.abs() ?? 0)} against what Pulse captured',
        'Review',
        () => showPulseSheet<void>(
          context,
          full: true,
          builder: (_) => ReconciliationSheet(statement: s),
        ),
      ),
      CloseState.needsPassword => (
        'The PDF is locked. Add your $bank statement password once.',
        'Add password',
        () => showPulseSheet<void>(
          context,
          builder: (_) => PasswordSheet(institution: s.institution),
        ),
      ),
      CloseState.needsAccount => (
        'Pulse could not tell which account this is.',
        'Try again',
        () => ref
            .read(repositoryProvider)
            .reprocessStatement(s.id)
            .then((_) => ref.invalidate(statementsProvider)),
      ),
      _ => (
        s.parseError ??
            'This file could not be read. Scanned PDFs are not supported yet.',
        'Upload another',
        () => uploadStatement(context, ref),
      ),
    };
    return SurfaceCard(
      borderColor: c.warning.withValues(alpha: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Dot(c.warning),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.accountLabel, style: context.tt.titleMedium),
                    const SizedBox(height: 2),
                    Text(message, style: context.tt.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          PrimaryButton(label: action, onPressed: onAction),
        ],
      ),
    );
  }
}

class _Sources extends ConsumerWidget {
  const _Sources();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final gmail = ref.watch(emailConnectionsProvider).value ?? const [];
    final active = gmail.where((g) => g.active).firstOrNull;
    final reauth = gmail.where((g) => !g.active).firstOrNull;
    return RowGroup(
      indent: ListRow.leadingInset,
      children: [
        ListRow(
          leading: const IconWell(Icons.mail_outline_rounded),
          title: 'Gmail',
          subtitle: active != null
              ? 'Connected · ${active.email}'
              : reauth != null
              ? 'Reconnect ${reauth.email} to keep importing'
              : 'Finds bank statements in your inbox. Read-only.',
          subtitleColor: reauth != null && active == null ? c.warning : null,
          trailing: active != null
              ? Icon(Icons.check_rounded, color: c.positive, size: 20)
              : TextAction(
                  reauth != null ? 'Reconnect' : 'Connect',
                  onTap: () => connectGmail(context, ref),
                ),
        ),
        ListRow(
          leading: const IconWell(Icons.upload_file_outlined),
          title: 'Upload a statement',
          subtitle: 'PDF or CSV from any UAE bank',
          trailing: TextAction(
            'Choose',
            onTap: () => uploadStatement(context, ref),
          ),
        ),
      ],
    );
  }
}

class _Passwords extends ConsumerWidget {
  const _Passwords();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final saved = ref.watch(statementPasswordsProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RowGroup(
          children: [
            for (final p in saved)
              ListRow(
                dense: true,
                title: institutionName(p.institution),
                trailing: Text(
                  'Saved',
                  style: context.tt.bodyMedium!.copyWith(color: c.positive),
                ),
                onTap: () => showPulseSheet<void>(
                  context,
                  builder: (_) => PasswordSheet(institution: p.institution),
                ),
              ),
            ListRow(
              dense: true,
              title: 'Add a bank',
              titleStyle: context.tt.bodyLarge!.copyWith(color: c.accent),
              onTap: () => showPulseSheet<void>(
                context,
                builder: (_) => const PasswordSheet(),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            0,
          ),
          child: Text(
            "Kept in this phone's secure storage, one per bank. Never synced or shown again.",
            style: context.tt.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// Set a statement password for one bank. Write-only.
class PasswordSheet extends ConsumerStatefulWidget {
  const PasswordSheet({super.key, this.institution});
  final String? institution;
  @override
  ConsumerState<PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<PasswordSheet> {
  late String? _inst = widget.institution;
  final _pw = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_inst == null || _pw.text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(statementPasswordStoreProvider).save(_inst!, _pw.text);
      _pw.clear();
      // Locked statements waiting for this password open now.
      await ref.read(localStatementServiceProvider)?.retryLocked();
      Haptics.success();
      ref.invalidate(statementPasswordsProvider);
      ref.invalidate(statementsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the password on this device.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return SheetScaffold(
      title: _inst == null
          ? 'Statement password'
          : '${institutionName(_inst)} password',
      subtitle:
          'Banks lock statement PDFs. Enter it once; it stays on this phone '
          'and locked statements are read again automatically.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.institution == null) ...[
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final e in institutions.entries)
                  Pill(
                    e.value,
                    selected: e.key == _inst,
                    onTap: () => setState(() => _inst = e.key),
                  ),
              ],
            ),
            const SizedBox(height: Space.lg),
          ],
          if (_inst != null) ...[
            Text(statementPasswordHint(_inst), style: context.tt.bodyMedium),
            const SizedBox(height: Space.md),
          ],
          TextField(
            controller: _pw,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'PDF password',
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show' : 'Hide',
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: c.textTertiary,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: c.textTertiary),
              const SizedBox(width: Space.xs),
              Expanded(
                child: Text(
                  "Kept in this phone's secure storage. Never synced, backed "
                  'up or shown again.',
                  style: context.tt.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            label: 'Save password',
            loading: _busy,
            onPressed: _inst != null && _pw.text.isNotEmpty ? _save : null,
          ),
        ],
      ),
    );
  }
}

/// Balances and differences for one statement.
class ReconciliationSheet extends ConsumerWidget {
  const ReconciliationSheet({super.key, required this.statement});
  final Statement statement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final recon = ref.watch(_reconProvider(statement.id));
    TextStyle num([Color? col]) => PulseTheme.amount(col ?? c.textPrimary);
    Widget money(double? v, [Color? col]) =>
        Text(v == null ? '–' : Money.aed(v), style: num(col));
    return SheetScaffold(
      title: statement.accountLabel,
      subtitle: '${_period(statement)} · ${_via(statement)}',
      child: recon.when(
        loading: () => const SkeletonList(rows: 4, height: 44),
        error: (e, _) => Text(
          'Could not load the reconciliation.',
          style: context.tt.bodyMedium,
        ),
        data: (r) {
          final mismatch = r.status == ReconStatus.mismatch;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Dot(mismatch ? c.warning : c.positive),
                  const SizedBox(width: Space.sm),
                  Text(
                    mismatch
                        ? 'Off by ${Money.aed(r.diff?.abs() ?? 0)}'
                        : 'Matches what Pulse captured',
                    style: context.tt.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: Space.lg),
              RowGroup(
                padding: EdgeInsets.zero,
                children: [
                  ListRow(
                    dense: true,
                    title: 'Opening balance',
                    trailing: money(r.opening),
                  ),
                  ListRow(
                    dense: true,
                    title: 'Closing on statement',
                    trailing: money(r.closing),
                  ),
                  ListRow(
                    dense: true,
                    title: 'Closing from transactions',
                    trailing: money(r.computedClosing),
                  ),
                  ListRow(
                    dense: true,
                    title: 'Matched to captured',
                    trailing: Text('${r.linked}', style: num()),
                  ),
                ],
              ),
              if (r.statementOnly.isNotEmpty) ...[
                const SizedBox(height: Space.xl),
                Text(
                  'On the statement, never captured',
                  style: context.tt.bodySmall,
                ),
                RowGroup(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final l in r.statementOnly)
                      ListRow(
                        title: l.description,
                        subtitle:
                            '${DateFormat('d MMM').format(l.date)} · added to your ledger',
                        trailing: money(l.credit ? l.amount : -l.amount),
                      ),
                  ],
                ),
              ],
              if (r.capturedOnly.isNotEmpty) ...[
                const SizedBox(height: Space.xl),
                Text(
                  'Captured, not on the statement',
                  style: context.tt.bodySmall,
                ),
                RowGroup(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final l in r.capturedOnly)
                      ListRow(
                        title: l.description,
                        subtitle: DateFormat('d MMM').format(l.date),
                        trailing: money(l.credit ? l.amount : -l.amount),
                      ),
                  ],
                ),
              ],
              for (final w in r.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: Space.md),
                  child: Text(w, style: context.tt.bodySmall),
                ),
              const SizedBox(height: Space.xl),
              if (mismatch)
                PrimaryButton(
                  label: 'Read statement again',
                  onPressed: () async {
                    try {
                      await ref
                          .read(repositoryProvider)
                          .reprocessStatement(statement.id);
                      ref.invalidate(statementsProvider);
                      ref.invalidate(_reconProvider(statement.id));
                      if (context.mounted) Navigator.of(context).pop();
                    } on ApiException catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(e.message)));
                      }
                    }
                  },
                )
              else
                PrimaryButton(
                  label: 'Done',
                  secondary: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
            ],
          );
        },
      ),
    );
  }
}

final _reconProvider = FutureProvider.family<Reconciliation, String>(
  (ref, id) => ref.watch(repositoryProvider).reconciliation(id),
);
