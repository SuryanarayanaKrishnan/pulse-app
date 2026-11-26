import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/analytics/analytics.dart';
import '../../core/engine/budget_file.dart';
import '../../core/engine/sheet_import.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/budget_import_service.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// A Google Sheets link that could not be read, with what to do about it.
class SheetLinkException implements Exception {
  const SheetLinkException(this.message);
  final String message;
}

/// Downloads a Google Sheet as a workbook. Works for sheets shared as
/// "anyone with the link", with no sign-in; replaced in tests.
final sheetFetcherProvider =
    Provider<Future<Uint8List> Function(String sheetId)>(
      (ref) => (id) async {
        try {
          final r = await Dio().get<List<int>>(
            'https://docs.google.com/spreadsheets/d/$id/export?format=xlsx',
            options: Options(
              responseType: ResponseType.bytes,
              receiveTimeout: const Duration(seconds: 30),
            ),
          );
          final bytes = Uint8List.fromList(r.data ?? const []);
          // A private sheet answers with Google's sign-in page, not a workbook.
          if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4B)
            throw const SheetLinkException(_privateSheet);
          return bytes;
        } on DioException catch (e) {
          final code = e.response?.statusCode;
          if (code == 401 || code == 403 || code == 404)
            throw const SheetLinkException(_privateSheet);
          throw const SheetLinkException(
            'Could not reach Google Sheets. Check your connection, or download the sheet as Excel '
            'and choose the file instead. Files work without a connection.',
          );
        }
      },
    );

const _privateSheet =
    'That sheet is private. Reading private sheets needs a Google sign-in, which is not available yet. '
    'Set sharing to "Anyone with the link can view", or download it as Excel and choose the file instead.';

String? sheetIdFromLink(String link) =>
    RegExp(r'/spreadsheets/d/([a-zA-Z0-9_-]{20,})').firstMatch(link)?.group(1);

/// Bring a budget kept in Excel, Google Sheets or a CSV into Pulse: pick the
/// file, check how each line maps, import. Free: it is what gets someone
/// from their old sheet to a working Pulse.
class BudgetImportScreen extends ConsumerStatefulWidget {
  const BudgetImportScreen({super.key});
  @override
  ConsumerState<BudgetImportScreen> createState() => _BudgetImportScreenState();
}

class _BudgetImportScreenState extends ConsumerState<BudgetImportScreen> {
  final _link = TextEditingController();
  bool _busy = false, _history = true, _keepNames = false;
  String? _error, _source;
  SheetAnalysis? _analysis;
  List<LabelMapping> _mappings = const [];
  List<SpendCategory> _targets = const [];

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final List<PlatformFile> files;
    try {
      files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'csv', 'tsv', 'txt'],
      );
    } on Object {
      if (mounted)
        setState(
          () => _error = 'Could not open Files. Check that Pulse is allowed to see it, then try again.',
        );
      return;
    }
    final f = files.firstOrNull;
    if (f == null) return;
    Uint8List bytes;
    try {
      bytes = await f.readAsBytes();
    } on Object {
      final path = f.path;
      try {
        bytes = await File(path!).readAsBytes();
      } on Object {
        if (mounted) {
          setState(
            () => _error =
                'Could not open that file from Files. If it is in iCloud Drive, open it in Files '
                'first so it downloads to this phone, then choose it again.',
          );
        }
        return;
      }
    }
    await _read(bytes, f.name, 'file');
  }

  Future<void> _fromLink() async {
    final id = sheetIdFromLink(_link.text);
    if (id == null) {
      setState(() => _error = 'That does not look like a Google Sheets link.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final bytes = await ref.read(sheetFetcherProvider)(id);
      await _read(bytes, 'sheet.xlsx', 'link');
    } on SheetLinkException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'We could not open that sheet. Download it as Excel and choose the file instead.';
        });
      }
    }
  }

  Future<void> _read(Uint8List bytes, String name, String source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final a = analyzeSheets(readBudgetFile(bytes, name));
      if (a.isEmpty) {
        setState(() {
          _busy = false;
          _error = a.warnings.isEmpty
              ? 'We could not find a budget in that file. It needs a category column and an amount or month columns.'
              : a.warnings.first;
        });
        return;
      }
      final svc = ref.read(budgetImportServiceProvider);
      final maps = await svc.proposeMappings(a, keepOwnNames: _keepNames);
      final custom = await ref.read(repositoryProvider).categories();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _analysis = a;
        _mappings = maps;
        _source = source;
        _targets = [
          ...SpendCategory.defaults,
          const SpendCategory(
            'other_income',
            'Other Income',
            kind: CategoryKind.income,
          ),
          ...custom,
        ];
      });
    } on FormatException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } on Object {
      setState(() {
        _busy = false;
        _error = 'We could not read that file. Export it as .xlsx or CSV and try again.';
      });
    }
  }

  Future<void> _remap() async {
    final a = _analysis;
    if (a == null) return;
    final maps = await ref
        .read(budgetImportServiceProvider)
        .proposeMappings(a, keepOwnNames: _keepNames);
    if (mounted) setState(() => _mappings = maps);
  }

  Future<void> _import() async {
    final a = _analysis!;
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(budgetImportServiceProvider)
          .apply(a, _mappings, importHistory: _history);
      final n = _mappings.length;
      ref
          .read(analyticsProvider)
          .track(
            AnalyticsEvent.budgetImported(
              source: _source ?? 'file',
              history: _history && r.transactionsAdded > 0,
              items: n < 8 ? 'few' : (n < 25 ? 'some' : 'many'),
            ),
          );
      invalidateBudgetPlan(ref);
      ref.invalidate(categoriesProvider);
      ref.invalidate(transactionsProvider);
      if (!mounted) return;
      final parts = [
        if (r.limitsSet > 0)
          '${r.limitsSet} budget ${r.limitsSet == 1 ? 'amount' : 'amounts'}',
        if (r.transactionsAdded > 0)
          '${r.transactionsAdded} ${r.transactionsAdded == 1 ? 'payment' : 'payments'}',
        if (r.categoriesCreated > 0)
          '${r.categoriesCreated} new ${r.categoriesCreated == 1 ? 'category' : 'categories'}',
      ];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            parts.isEmpty
                ? 'Nothing new to import.'
                : 'Imported ${parts.join(', ')}.',
          ),
        ),
      );
      context.pop();
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'The import did not finish. Nothing was lost; try again.';
      });
    }
  }

  String _targetLabel(ImportTarget t) => switch (t) {
    ExistingTarget(:final category) => category.label,
    NewTarget(:final name) => 'New: $name',
    SkipTarget() => 'Skip',
  };

  Future<void> _choose(LabelMapping m) async {
    final picked = await showPulseSheet<ImportTarget>(
      context,
      full: true,
      builder: (ctx) => SheetScaffold(
        title: m.label.label,
        subtitle: 'Where should this go?',
        child: Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListRow(
                leading: const IconWell(Icons.add_circle_outline_rounded),
                title: 'Keep as its own category',
                subtitle: m.label.label,
                onTap: () => Navigator.pop(ctx, NewTarget(m.label.label)),
              ),
              ListRow(
                leading: const IconWell(Icons.block_rounded),
                title: 'Skip it',
                onTap: () => Navigator.pop(ctx, const SkipTarget()),
              ),
              for (final c in _targets)
                ListRow(
                  leading: CategoryIcon.well(c),
                  title: c.label,
                  onTap: () => Navigator.pop(ctx, ExistingTarget(c)),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => m.target = picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final a = _analysis;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import my sheet'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: a == null ? _picker(c) : _review(c, a),
      bottomNavigationBar: a == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.sm,
                  Space.gutter,
                  Space.md,
                ),
                child: PrimaryButton(
                  key: const Key('import_apply'),
                  label: 'Import',
                  loading: _busy,
                  onPressed: _import,
                ),
              ),
            ),
    );
  }

  Widget _picker(PulseColors c) => ListView(
    padding: const EdgeInsets.fromLTRB(
      Space.gutter,
      Space.sm,
      Space.gutter,
      Space.xxxl,
    ),
    children: [
      Text(
        'Keep your progress. Bring in the budget you already track in Excel, Google Sheets or a CSV, '
        'with its categories and past months.',
        style: context.tt.bodyMedium!.copyWith(color: c.textSecondary),
      ),
      const SizedBox(height: Space.xl),
      PrimaryButton(
        key: const Key('import_pick'),
        label: 'Choose a file',
        icon: Icons.upload_file_outlined,
        loading: _busy,
        onPressed: _pickFile,
      ),
      const SizedBox(height: Space.xl),
      Text('Or paste a Google Sheets link', style: context.tt.titleSmall),
      const SizedBox(height: Space.sm),
      TextField(
        key: const Key('import_link'),
        controller: _link,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
          hintText: 'https://docs.google.com/spreadsheets/d/…',
        ),
        onSubmitted: (_) => _fromLink(),
      ),
      const SizedBox(height: Space.sm),
      PrimaryButton(
        label: 'Read the sheet',
        secondary: true,
        onPressed: _busy ? null : _fromLink,
      ),
      const SizedBox(height: Space.sm),
      Text(
        'Excel and CSV files from Files work on this phone with no sign-in. A link needs a connection and the sheet shared as '
        '"Anyone with the link can view"; Pulse reads it once and keeps no connection to it.',
        style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
      ),
      if (_error != null) ...[
        const SizedBox(height: Space.lg),
        Text(
          _error!,
          key: const Key('import_error'),
          style: context.tt.bodyMedium!.copyWith(color: c.negative),
        ),
      ],
    ],
  );

  Widget _review(PulseColors c, SheetAnalysis a) {
    final months = a.historyMonths;
    final bits = [
      '${_mappings.length} ${_mappings.length == 1 ? 'line' : 'lines'}',
      if (a.transactions.isNotEmpty) '${a.transactions.length} payments',
      if (months > 0) '$months ${months == 1 ? 'month' : 'months'} of history',
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            Space.md,
          ),
          child: Text(
            'We found ${bits.join(' · ')}. Check where each line goes.',
            style: context.tt.bodyMedium!.copyWith(color: c.textSecondary),
          ),
        ),
        for (final w in a.warnings)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.sm,
            ),
            child: Text(
              w,
              style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
            ),
          ),
        SwitchListTile.adaptive(
          key: const Key('import_keep_names'),
          contentPadding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          title: const Text('Keep my own category names'),
          subtitle: const Text('Only exact matches join Pulse categories.'),
          value: _keepNames,
          onChanged: (v) {
            setState(() => _keepNames = v);
            _remap();
          },
        ),
        if (a.transactions.isNotEmpty ||
            a.labels.values.any((l) => l.actual.isNotEmpty))
          SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Space.gutter,
            ),
            title: const Text('Bring in my history'),
            subtitle: const Text(
              'Past payments, so charts and rollovers carry on.',
            ),
            value: _history,
            onChanged: (v) => setState(() => _history = v),
          ),
        const SizedBox(height: Space.sm),
        RowGroup(
          indent: 0,
          children: [
            for (final m in _mappings)
              ListRow(
                key: Key('map_${m.label.label}'),
                title: m.label.label,
                subtitle: _sub(m),
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    _targetLabel(m.target),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.bodyMedium!.copyWith(
                      color: m.target is SkipTarget ? c.textTertiary : c.accent,
                    ),
                  ),
                ),
                chevron: true,
                onTap: () => _choose(m),
              ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(Space.gutter),
            child: Text(
              _error!,
              style: context.tt.bodyMedium!.copyWith(color: c.negative),
            ),
          ),
      ],
    );
  }

  String? _sub(LabelMapping m) {
    final l = m.label;
    final amounts = l.budget.values.where((v) => v > 0).toList();
    final parts = [
      if (l.group.isNotEmpty)
        l.group[0].toUpperCase() + l.group.substring(1).toLowerCase(),
      if (amounts.isNotEmpty)
        '${Money.aed(amounts.last / 100, decimals: false)} a month',
      if (l.txCount > 0) '${l.txCount} payments',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
