import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/tokens.dart';
import '../../core/vault/input_guard.dart';
import '../../core/vault/release.dart';
import '../../core/vault/vault_models.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../../data/vault_service.dart';
import '../wealth/wealth_widgets.dart' show FieldLabel;
import 'vault_widgets.dart';

/// Add or edit a trusted person and choose what they can see.
class NomineeSheet extends ConsumerStatefulWidget {
  const NomineeSheet({super.key, this.initial});
  final Nominee? initial;

  @override
  ConsumerState<NomineeSheet> createState() => _NomineeSheetState();
}

class _NomineeSheetState extends ConsumerState<NomineeSheet> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _relation = TextEditingController(
    text: widget.initial?.relationship,
  );
  late final _contact = TextEditingController(text: widget.initial?.contact);
  late bool _all = widget.initial?.seesAll ?? true;
  late final Set<String> _ids = {...?widget.initial?.entryIds};
  bool _busy = false;
  String? _error;

  bool get _editing => widget.initial != null;

  @override
  void dispose() {
    for (final c in [_name, _relation, _contact]) {
      c.dispose();
    }
    super.dispose();
  }

  List<GuardIssue> get _issues => [
    for (final c in [_name, _relation, _contact])
      ...InputGuard.blocking(c.text),
  ];
  bool get _valid => _name.text.trim().isNotEmpty && _issues.isEmpty;

  Future<void> _save() async {
    if (!_valid || _busy) return;
    setState(() => _busy = true);
    try {
      final svc = ref.read(vaultServiceProvider);
      final base = widget.initial ?? svc.blankNominee();
      await svc.saveNominee(
        base.copyWith(
          name: _name.text.trim(),
          relationship: _relation.text.trim(),
          contact: _contact.text.trim(),
          seeAll: _all,
          entryIds: _all ? null : {..._ids},
        ),
      );
      invalidateVault(ref);
      if (mounted) Navigator.of(context).pop(true);
    } on VaultGuardException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove ${widget.initial!.name}?'),
        content: const Text(
          'Their release codes stop working once you make a new emergency file. Anything already handed over cannot be taken back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            key: const Key('nominee_confirm_delete'),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(vaultServiceProvider).deleteNominee(widget.initial!.id);
    invalidateVault(ref);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final entries =
        ref.watch(vaultEntriesProvider).value ?? const <VaultEntry>[];
    return SheetScaffold(
      title: _editing ? 'Edit person' : 'Add a trusted person',
      subtitle: 'Someone you would want to find this, if you could not tell them yourself.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('nominee_name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            key: const Key('nominee_relationship'),
            controller: _relation,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Relationship, like "Wife" or "Brother"',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.md),
          TextField(
            key: const Key('nominee_contact'),
            controller: _contact,
            decoration: const InputDecoration(hintText: 'Phone or email'),
            onChanged: (_) => setState(() {}),
          ),
          const FieldLabel('What they can see'),
          Wrap(
            spacing: Space.sm,
            children: [
              Pill(
                'Everything',
                key: const Key('nominee_all'),
                selected: _all,
                onTap: () => setState(() => _all = true),
              ),
              Pill(
                'Only some things',
                key: const Key('nominee_some'),
                selected: !_all,
                onTap: () => setState(() => _all = false),
              ),
            ],
          ),
          if (!_all)
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Space.sm),
                child: Text(
                  'Add items to your vault first, then choose here.',
                  style: context.tt.bodySmall,
                ),
              )
            else
              for (final e in entries)
                Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    key: ValueKey('nominee_see_${e.id}'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _ids.contains(e.id),
                    onChanged: (v) => setState(
                      () => v == true ? _ids.add(e.id) : _ids.remove(e.id),
                    ),
                    title: Text(
                      e.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(e.type.label),
                  ),
                ),
          GuardNote(_issues),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.md),
              child: Text(
                _error!,
                style: context.tt.bodySmall!.copyWith(color: c.negative),
              ),
            ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            key: const Key('nominee_save'),
            label: _editing ? 'Save changes' : 'Add person',
            loading: _busy,
            onPressed: _valid ? _save : null,
          ),
          if (_editing) ...[
            const SizedBox(height: Space.sm),
            PrimaryButton(
              key: const Key('nominee_preview'),
              label: 'Preview what ${widget.initial!.name} would see',
              secondary: true,
              icon: Icons.visibility_outlined,
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PreviewScreen(nomineeId: widget.initial!.id),
                  ),
                );
              },
            ),
            const SizedBox(height: Space.sm),
            PrimaryButton(
              key: const Key('nominee_delete'),
              label: 'Remove',
              secondary: true,
              destructive: true,
              onPressed: _remove,
            ),
          ],
        ],
      ),
    );
  }
}

/// "Preview what [name] would see": the exact sheet they would be handed.
class PreviewScreen extends ConsumerWidget {
  const PreviewScreen({super.key, required this.nomineeId});
  final String nomineeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nominees =
        ref.watch(vaultNomineesProvider).value ?? const <Nominee>[];
    final entries = ref.watch(vaultEntriesProvider).value;
    final n = nominees.where((x) => x.id == nomineeId).firstOrNull;
    final svc = ref.watch(vaultServiceProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(n == null ? 'Preview' : 'What ${n.name} would see'),
      ),
      body: n == null || entries == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<String>(
              future: svc.sheetText(forNominee: n),
              builder: (context, snap) => ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.md,
                  Space.gutter,
                  Space.xxxl,
                ),
                children: [
                  Text(
                    '${visibleTo(n, entries).length} of ${entries.length} ${entries.length == 1 ? 'item' : 'items'} are visible to ${n.name}. Photos are never included.',
                    key: const Key('preview_count'),
                    style: context.tt.bodyMedium,
                  ),
                  const SizedBox(height: Space.lg),
                  SurfaceCard(
                    child: SelectableText(
                      snap.data ?? '',
                      key: const Key('preview_text'),
                      style: context.tt.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: Space.lg),
                  PrimaryButton(
                    key: const Key('preview_share'),
                    label: 'Share this sheet',
                    icon: Icons.ios_share_rounded,
                    onPressed: snap.data == null
                        ? null
                        : () async {
                            svc.noteExported('sheet');
                            await SharePlus.instance.share(
                              ShareParams(
                                text: snap.data!,
                                subject: 'Emergency sheet for ${n.name}',
                              ),
                            );
                          },
                  ),
                  const SizedBox(height: Space.sm),
                  PrimaryButton(
                    key: const Key('preview_kit'),
                    label: 'Make a sealed emergency file',
                    secondary: true,
                    icon: Icons.lock_outline_rounded,
                    onPressed: () => showPulseSheet<void>(
                      context,
                      full: true,
                      builder: (_) => KitSheet(nominee: n),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Seals the export for one person and shows the three key shares once.
class KitSheet extends ConsumerStatefulWidget {
  const KitSheet({super.key, required this.nominee});
  final Nominee nominee;

  @override
  ConsumerState<KitSheet> createState() => _KitSheetState();
}

class _KitSheetState extends ConsumerState<KitSheet> {
  ReleaseKit? _kit;
  bool _busy = false;

  Future<void> _make() async {
    setState(() => _busy = true);
    final kit = await ref.read(vaultServiceProvider).createKit(widget.nominee);
    if (mounted)
      setState(() {
        _kit = kit;
        _busy = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.nominee;
    final kit = _kit;
    final relay = ref.watch(inactivityRelayProvider);
    return SheetScaffold(
      title: 'Emergency file for ${n.name}',
      subtitle: kit == null
          ? 'Sealed so nobody can open it alone.'
          : 'Shown once. Hand the codes over now.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kit == null) ...[
            Text(
              'Pulse seals what ${n.name} may see into a file. It opens only with two of three key codes: one stays on your phone, one goes to ${n.name}, and one is held by someone else you trust (for example your spouse, or kept with your backup).',
              style: context.tt.bodyMedium,
            ),
            const SizedBox(height: Space.md),
            Text(
              'Making a new file replaces any earlier one: older codes stop working.',
              style: context.tt.bodySmall,
            ),
            const SizedBox(height: Space.xl),
            PrimaryButton(
              key: const Key('kit_make'),
              label: 'Seal the file',
              loading: _busy,
              onPressed: _make,
            ),
          ] else ...[
            _Code(
              label: 'Code for ${n.name} (give them)',
              value: kit.nomineeShare,
              keyName: 'kit_nominee_share',
            ),
            _Code(
              label: 'Code for your backup holder (give them)',
              value: kit.escrowShare,
              keyName: 'kit_escrow_share',
            ),
            _Code(
              label: 'Release code (give ${n.name})',
              value: kit.claimCode,
              keyName: 'kit_claim_code',
            ),
            Text(
              'Your own code is already kept on this phone and in your encrypted backup.',
              style: context.tt.bodySmall,
            ),
            const SizedBox(height: Space.lg),
            PrimaryButton(
              key: const Key('kit_share_file'),
              label: 'Share the sealed file',
              icon: Icons.ios_share_rounded,
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text: kit.sealedFile,
                  subject: 'Pulse emergency file',
                ),
              ),
            ),
            if (!relay.isAvailable)
              Padding(
                padding: const EdgeInsets.only(top: Space.md),
                child: Text(
                  'Automatic release after a long silence needs a service that is not switched on yet, so hand the file over yourself for now.',
                  key: const Key('kit_relay_note'),
                  style: context.tt.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Code extends StatelessWidget {
  const _Code({
    required this.label,
    required this.value,
    required this.keyName,
  });
  final String label, value, keyName;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.md),
    child: SurfaceCard(
      onTap: () => copyText(context, value, 'Code'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.tt.labelMedium),
          const SizedBox(height: Space.xs),
          SelectableText(
            value,
            key: Key(keyName),
            style: context.tt.bodyMedium!.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ),
  );
}
