import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/vault/input_guard.dart';
import '../../core/vault/vault_models.dart';
import '../../core/widgets/widgets.dart';
import '../../data/local/attachments.dart';
import '../../data/providers.dart';
import '../../data/vault_service.dart';
import '../wealth/wealth_widgets.dart' show FieldLabel, parseMinor;
import 'vault_file_viewer.dart';
import 'vault_widgets.dart';

/// Add or edit one vault item: where it is, never the secret.
class EntrySheet extends ConsumerStatefulWidget {
  const EntrySheet({super.key, this.initial, this.type = VaultType.bank});
  final VaultEntry? initial;
  final VaultType type;

  @override
  ConsumerState<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<EntrySheet> {
  late VaultType _type = widget.initial?.type ?? widget.type;
  late List<String> _photos = [...?widget.initial?.photoPaths];
  final _added = <String>[];
  final _removed = <String>[];
  late final _institution = TextEditingController(
    text: widget.initial?.institution,
  );
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _where = TextEditingController(text: widget.initial?.whereToFind);
  late final _nominee = TextEditingController(
    text: widget.initial?.nomineeName,
  );
  late final _contact = TextEditingController(
    text: widget.initial?.contactPerson,
  );
  late final _value = TextEditingController(
    text: widget.initial?.estimatedValueMinor == null
        ? ''
        : (widget.initial!.estimatedValueMinor! / 100).toStringAsFixed(
            widget.initial!.estimatedValueMinor! % 100 == 0 ? 0 : 2,
          ),
  );
  bool _busy = false;
  String? _error;

  bool get _editing => widget.initial != null;

  List<TextEditingController> get _texts => [
    _institution,
    _title,
    _where,
    _nominee,
    _contact,
  ];

  @override
  void dispose() {
    for (final c in [..._texts, _value]) {
      c.dispose();
    }
    super.dispose();
  }

  List<GuardIssue> get _issues {
    final seen = <GuardKind>{};
    return [
      for (final c in _texts)
        for (final i in InputGuard.check(c.text))
          if (seen.add(i.kind)) i,
    ];
  }

  bool get _blocked => _issues.any((i) => i.blocking);
  bool get _valid => _institution.text.trim().isNotEmpty && !_blocked;

  Future<void> _addStored(String? path) async {
    if (path == null) return;
    try {
      final stored = await ref.read(vaultServiceProvider).addPhoto(path);
      if (mounted) {
        setState(() {
          _photos = [..._photos, stored];
          _added.add(stored);
          _error = null;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _addPhoto(PhotoSource source) async =>
      _addStored(await ref.read(photoPickerProvider).pick(source));

  Future<void> _addPdf() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
      );
      await _addStored(files.firstOrNull?.path);
    } on Object {
      if (mounted) setState(() => _error = 'Could not open that file.');
    }
  }

  Future<void> _save() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final svc = ref.read(vaultServiceProvider);
    try {
      final base = widget.initial ?? svc.blank(_type);
      final value = parseMinor(_value.text);
      final e = base.copyWith(
        type: _type,
        institution: _institution.text.trim(),
        title: _title.text.trim(),
        whereToFind: _where.text.trim(),
        nomineeName: _nominee.text.trim(),
        contactPerson: _contact.text.trim(),
        estimatedValueMinor: value,
        clearValue: value == null,
        photoPaths: _photos,
      );
      await svc.saveEntry(e);
      await svc.removePhotos(_removed);
      invalidateVault(ref);
      if (mounted) Navigator.of(context).pop(true);
    } on VaultGuardException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object {
      if (mounted) setState(() => _error = 'That did not save. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove from the vault?'),
        content: const Text(
          'This only removes the note. Nothing changes at the bank or insurer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: const Key('vault_confirm_delete'),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(vaultServiceProvider).deleteEntry(widget.initial!.id);
    invalidateVault(ref);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final canPhoto = ref.watch(photoPickerProvider) is! NoPhotoPicker;
    return SheetScaffold(
      title: _editing ? 'Edit item' : 'Add to your vault',
      subtitle: 'Say where it is, not the secret. No passwords, PINs or full card numbers.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final t in VaultType.values)
                Pill(
                  t.label,
                  key: ValueKey('vault_type_${t.key}'),
                  icon: vaultIcon(t),
                  selected: _type == t,
                  onTap: () => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
          TextField(
            key: const Key('vault_institution'),
            controller: _institution,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Bank, insurer or company',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            key: const Key('vault_title'),
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'What it is (optional), like "Salary account"',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const FieldLabel('Where to find it'),
          TextField(
            key: const Key('vault_where'),
            controller: _where,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: _type.hint),
            onChanged: (_) => setState(() {}),
          ),
          const FieldLabel('People and value (optional)'),
          TextField(
            key: const Key('vault_nominee_name'),
            controller: _nominee,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Nominee named on it'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            key: const Key('vault_contact'),
            controller: _contact,
            decoration: const InputDecoration(
              hintText: 'Who to contact (name, branch, agent)',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            key: const Key('vault_value'),
            controller: _value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: 'Rough value',
              prefixIcon: CurrencyPrefix('AED'),
 prefixIconConstraints: kCurrencyPrefixConstraints,
            ),
          ),
          GuardNote(_issues),
          const FieldLabel('Photos and PDFs of the papers (optional)'),
          if (_photos.isEmpty && !canPhoto)
            Text(
              'Papers can be added on your phone.',
              style: context.tt.bodySmall,
            )
          else ...[
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  InputChip(
                    key: ValueKey('vault_photo_$i'),
                    avatar: const Icon(Icons.attach_file_rounded, size: 16),
                    label: Text('Paper ${i + 1}'),
                    onPressed: () => showVaultFile(context, _photos[i]),
                    onDeleted: () => setState(() {
                      final p = _photos[i];
                      _photos = [..._photos]..removeAt(i);
                      if (_added.remove(p)) {
                        ref.read(vaultServiceProvider).removePhotos([p]);
                      } else {
                        _removed.add(p);
                      }
                    }),
                  ),
                if (canPhoto) ...[
                  Pill(
                    'Take a photo',
                    icon: Icons.photo_camera_outlined,
                    onTap: () => _addPhoto(PhotoSource.camera),
                  ),
                  Pill(
                    'Choose',
                    icon: Icons.photo_library_outlined,
                    onTap: () => _addPhoto(PhotoSource.gallery),
                  ),
                  Pill(
                    'Add a PDF',
                    icon: Icons.picture_as_pdf_outlined,
                    onTap: _addPdf,
                  ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text(
                'Encrypted on your phone and in your encrypted backup. Never in a shared sheet. Tap a paper to open it.',
                style: context.tt.bodySmall,
              ),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.md),
              child: Text(
                _error!,
                key: const Key('vault_error'),
                style: context.tt.bodySmall!.copyWith(color: c.negative),
              ),
            ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            key: const Key('vault_save'),
            label: _editing ? 'Save changes' : 'Add to vault',
            loading: _busy,
            onPressed: _valid ? _save : null,
          ),
          if (_editing) ...[
            const SizedBox(height: Space.sm),
            PrimaryButton(
              key: const Key('vault_delete'),
              label: 'Remove',
              secondary: true,
              destructive: true,
              onPressed: _delete,
            ),
          ],
        ],
      ),
    );
  }
}
