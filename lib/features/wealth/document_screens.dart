import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/dates.dart';
import '../../core/engine/valuation.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/local/wealth_store.dart' show newWealthId;
import '../../data/providers.dart';
import '../../data/wealth_models.dart';
import 'wealth_widgets.dart';

IconData docIcon(DocCategory c) => switch (c) {
  DocCategory.titleDeed => Icons.home_work_outlined,
  DocCategory.fdCertificate => Icons.savings_outlined,
  DocCategory.insurance => Icons.health_and_safety_outlined,
  DocCategory.passport => Icons.menu_book_outlined,
  DocCategory.emiratesId => Icons.badge_outlined,
  DocCategory.visa => Icons.flight_takeoff_outlined,
  DocCategory.other => Icons.description_outlined,
};

Color statusColor(BuildContext context, DueStatus s) => switch (s) {
  DueStatus.overdue => context.pc.negative,
  DueStatus.dueSoon => context.pc.warning,
  DueStatus.upcoming => context.pc.textSecondary,
};

const _remindOptions = <int?, String>{
  null: 'None',
  7: '1 week',
  14: '2 weeks',
  30: '1 month',
  90: '3 months',
};

/// Add or edit a document: photo or scan, category, optional date + reminder.
/// Files stay in app-private storage; only metadata is stored in the database.
class AddDocumentSheet extends ConsumerStatefulWidget {
  const AddDocumentSheet({super.key, this.initial});
  final WealthDocument? initial;

  @override
  ConsumerState<AddDocumentSheet> createState() => _AddDocumentSheetState();
}

class _AddDocumentSheetState extends ConsumerState<AddDocumentSheet> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _notes = TextEditingController(text: widget.initial?.notes);
  late DocCategory _category =
      widget.initial?.category ?? DocCategory.titleDeed;
  late String _dueKind = widget.initial?.dueKind ?? _category.defaultDueKind;
  late CalDate? _due = widget.initial?.dueOn;
  late int? _remind = widget.initial == null
      ? 30
      : widget.initial!.remindDaysBefore;
  late List<String> _existing = [...?widget.initial?.filePaths];
  final _removed = <String>[];
  final _added = <String>[];
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _valid =>
      _title.text.trim().isNotEmpty ||
      widget.initial != null ||
      _category != DocCategory.other;

  String get _effectiveTitle =>
      _title.text.trim().isEmpty ? _category.label : _title.text.trim();

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final svc = ref.read(wealthServiceProvider);
      final old = widget.initial;
      final remind = _due == null ? null : _remind;
      if (remind != null) {
        final ok = await svc.requestReminderPermission();
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Notifications are off, so there will be no alert. The date still shows under Upcoming.',
              ),
            ),
          );
        }
      }
      final doc = WealthDocument(
        id: old?.id ?? newWealthId(),
        title: _effectiveTitle,
        category: _category,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        filePaths: _existing,
        dueOn: _due,
        dueKind: _dueKind,
        remindDaysBefore: remind,
        notificationId: old?.notificationId,
        createdAt: old?.createdAt ?? DateTime.now(),
      );
      await svc.saveDocument(
        doc,
        newFileSources: _added,
        removedFiles: _removed,
      );
      invalidateWealth(ref);
      if (mounted) Navigator.of(context).pop(doc.id);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That did not save. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return SheetScaffold(
      title: editing ? 'Edit document' : 'Add a document',
      subtitle: 'Photos stay on this phone. Only you can open them.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final k in DocCategory.values)
                Pill(
                  k.label,
                  icon: docIcon(k),
                  selected: _category == k,
                  onTap: () => setState(() {
                    _category = k;
                    _dueKind = k.defaultDueKind;
                  }),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
          PhotoPickerRow(
            document: true,
            cameraLabel: 'Scan',
            existing: _existing,
            added: _added,
            onAdd: (p) => setState(() => _added.add(p)),
            onRemoveExisting: (p) => setState(() {
              _existing = [..._existing]..remove(p);
              _removed.add(p);
            }),
            onRemoveAdded: (p) => setState(() => _added.remove(p)),
          ),
          const SizedBox(height: Space.lg),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: 'Title (${_category.label})'),
            onChanged: (_) => setState(() {}),
          ),
          const FieldLabel('Date'),
          Wrap(
            spacing: Space.sm,
            children: [
              for (final k in const ['expiry', 'maturity', 'renewal'])
                Pill(
                  k == 'expiry'
                      ? 'Expires'
                      : k == 'maturity'
                      ? 'Matures'
                      : 'Renews',
                  selected: _dueKind == k,
                  onTap: () => setState(() => _dueKind = k),
                ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: _due == null
                      ? 'Pick a date (optional)'
                      : formatDate(_due!),
                  icon: Icons.event_outlined,
                  secondary: true,
                  onPressed: () async {
                    final d = await pickDate(
                      context,
                      initial: _due,
                      future: true,
                    );
                    if (d != null) setState(() => _due = d);
                  },
                ),
              ),
              if (_due != null) ...[
                const SizedBox(width: Space.sm),
                IconButton(
                  tooltip: 'Clear date',
                  onPressed: () => setState(() => _due = null),
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.pc.textTertiary,
                  ),
                ),
              ],
            ],
          ),
          if (_due != null) ...[
            const FieldLabel('Remind me before'),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final e in _remindOptions.entries)
                  Pill(
                    e.value,
                    selected: _remind == e.key,
                    onTap: () => setState(() => _remind = e.key),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text(
                'A notification at 9:00, scheduled on this phone.',
                style: context.tt.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: Space.lg),
          TextField(
            controller: _notes,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Notes, like a policy or deposit number (optional)',
            ),
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            label: editing ? 'Save changes' : 'Save document',
            loading: _busy,
            onPressed: _valid ? _save : null,
          ),
        ],
      ),
    );
  }
}

class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({super.key, required this.docId});
  final String docId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final docs = ref.watch(documentsProvider);
    final d = docs.value?.where((x) => x.id == docId).firstOrNull;
    final svc = ref.watch(wealthServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(d?.title ?? ''),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => leave(context),
        ),
        actions: [
          if (d != null)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showPulseSheet<void>(
                context,
                full: true,
                builder: (_) => AddDocumentSheet(initial: d),
              ),
            ),
        ],
      ),
      body: d == null
          ? (docs.isLoading
                ? const SkeletonList(rows: 3)
                : const EmptyState(
                    icon: Icons.description_outlined,
                    title: 'Document not found',
                    message: 'It may have been deleted.',
                  ))
          : ListView(
              padding: const EdgeInsets.only(bottom: 60),
              children: [
                PhotoStrip(d.filePaths, size: 120, document: true),
                if (d.filePaths.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.gutter,
                    ),
                    child: Text(
                      'No photo attached. Edit to add one.',
                      style: context.tt.bodySmall,
                    ),
                  ),
                const SectionHeader('Details'),
                RowGroup(
                  children: [
                    ListRow(
                      dense: true,
                      title: 'Type',
                      trailing: Text(
                        d.category.label,
                        style: PulseTheme.amount(c.textPrimary, size: 15),
                      ),
                    ),
                    if (d.dueOn != null) ...[
                      ListRow(
                        dense: true,
                        title: d.dueLabel,
                        subtitle: dueText(d.dueOn!, svc.today),
                        subtitleColor: statusColor(
                          context,
                          dueStatus(d.dueOn!, svc.today),
                        ),
                        trailing: Text(
                          formatDate(d.dueOn!),
                          style: PulseTheme.amount(c.textPrimary, size: 15),
                        ),
                      ),
                      ListRow(
                        dense: true,
                        title: 'Reminder',
                        trailing: Text(
                          d.remindDaysBefore == null
                              ? 'Off'
                              : '${_remindOptions[d.remindDaysBefore] ?? '${d.remindDaysBefore} days'} before',
                          style: PulseTheme.amount(c.textPrimary, size: 15),
                        ),
                      ),
                    ],
                  ],
                ),
                if (d.notes != null) ...[
                  const SectionHeader('Notes'),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.gutter,
                    ),
                    child: Text(d.notes!, style: context.tt.bodyMedium),
                  ),
                ],
                const SizedBox(height: Space.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: PrimaryButton(
                    label: 'Delete document',
                    destructive: true,
                    secondary: true,
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Delete ${d.title}?'),
                          content: const Text(
                            'The photos and its reminder are removed from this phone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      await svc.deleteDocument(d.id);
                      invalidateWealth(ref);
                      if (context.mounted) leave(context);
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
