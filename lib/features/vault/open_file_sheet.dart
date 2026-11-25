import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/vault/release.dart';
import '../../core/widgets/widgets.dart';
import 'vault_file_viewer.dart';

/// For a nominee: unseal an emergency file with two key codes, then read what
/// was left for them, papers included. Works with no account and nothing
/// stored: the file and codes are all it needs.
class OpenFileSheet extends ConsumerStatefulWidget {
  const OpenFileSheet({super.key});

  @override
  ConsumerState<OpenFileSheet> createState() => _OpenFileSheetState();
}

class _OpenFileSheetState extends ConsumerState<OpenFileSheet> {
  final _file = TextEditingController();
  final _a = TextEditingController();
  final _b = TextEditingController();
  OpenedVault? _opened;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _file.dispose();
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  bool get _ready =>
      _file.text.trim().isNotEmpty &&
      _a.text.trim().isNotEmpty &&
      _b.text.trim().isNotEmpty;

  Future<void> _pick() async {
    try {
      final r = await FilePicker.pickFiles();
      final path = r.firstOrNull?.path;
      if (path != null) {
        final text = await File(path).readAsString();
        setState(() {
          _file.text = text;
          _error = null;
        });
      }
    } on Object {
      if (mounted) setState(() => _error = 'Could not open that file.');
    }
  }

  Future<void> _open() async {
    if (!_ready || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final v = await VaultSeal.open(_file.text.trim(), [
        _a.text.trim(),
        _b.text.trim(),
      ]);
      if (mounted) setState(() => _opened = v);
    } on VaultOpenException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _opened;
    if (v != null) return _Opened(v);
    return SheetScaffold(
      title: 'Open an emergency file',
      subtitle: 'For someone who was given a file and two key codes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            key: const Key('open_pick_file'),
            label: 'Choose the file',
            secondary: true,
            icon: Icons.folder_open_outlined,
            onPressed: _pick,
          ),
          const SizedBox(height: Space.md),
          TextField(
            key: const Key('open_file_text'),
            controller: _file,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Or paste the whole file here',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            key: const Key('open_code_a'),
            controller: _a,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'First key code'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            key: const Key('open_code_b'),
            controller: _b,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'Second key code'),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: Space.md),
            Text(
              _error!,
              key: const Key('open_error'),
              style: context.tt.bodyMedium,
            ),
          ],
          const SizedBox(height: Space.xl),
          PrimaryButton(
            key: const Key('open_go'),
            label: 'Open',
            loading: _busy,
            onPressed: _ready ? _open : null,
          ),
        ],
      ),
    );
  }
}

class _Opened extends StatelessWidget {
  const _Opened(this.v);
  final OpenedVault v;

  @override
  Widget build(BuildContext context) => SheetScaffold(
    title: v.ownerName.isEmpty
        ? 'Left for you'
        : 'Left for you by ${v.ownerName}',
    subtitle: 'Opened on this phone. Nothing was sent anywhere.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (v.entries.isEmpty)
          Text('This file has no entries.', style: context.tt.bodyMedium),
        for (final e in v.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: SurfaceCard(
              key: ValueKey('opened_${e.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title.isEmpty ? e.type.label : e.title,
                    style: context.tt.titleMedium,
                  ),
                  if (e.institution.isNotEmpty)
                    Text(e.institution, style: context.tt.bodyMedium),
                  if (e.whereToFind.isNotEmpty)
                    Text(
                      'Where: ${e.whereToFind}',
                      style: context.tt.bodyMedium,
                    ),
                  if (e.contactPerson.isNotEmpty)
                    Text(
                      'Contact: ${e.contactPerson}',
                      style: context.tt.bodyMedium,
                    ),
                  if (v.papers[e.id]?.isNotEmpty ?? false) ...[
                    const SizedBox(height: Space.sm),
                    Wrap(
                      spacing: Space.sm,
                      children: [
                        for (var i = 0; i < v.papers[e.id]!.length; i++)
                          ActionChip(
                            key: ValueKey('opened_paper_${e.id}_$i'),
                            label: Text('Paper ${i + 1}'),
                            avatar: const Icon(
                              Icons.description_outlined,
                              size: 16,
                            ),
                            onPressed: () =>
                                showVaultBytes(context, v.papers[e.id]![i]),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
