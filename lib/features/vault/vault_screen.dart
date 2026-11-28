import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/vault/release.dart';
import '../../core/vault/suggestions.dart';
import '../../core/vault/vault_models.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../goals/goal_widgets.dart' show aedMinor;
import '../wealth/wealth_widgets.dart' show FieldLabel;
import 'entry_sheet.dart';
import 'nominee_sheet.dart';
import 'open_file_sheet.dart';
import 'suggestions_sheet.dart';
import 'vault_widgets.dart';
import '../coach/coach.dart';

/// Settings > Family vault: a calm list of where things are, for the people
/// who would need to find them. No passwords, ever.
class VaultScreen extends ConsumerWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries =
        ref.watch(vaultEntriesProvider).value ?? const <VaultEntry>[];
    final nominees =
        ref.watch(vaultNomineesProvider).value ?? const <Nominee>[];
    final score = ref.watch(vaultScoreProvider).value;
    final suggestions =
        ref.watch(vaultSuggestionsProvider).value ?? const <VaultSource>[];
    final status = ref.watch(vaultStatusProvider).value;
    final interval = status == null ? defaultCheckInDays : null;
    final c = context.pc;

    Future<void> addEntry([VaultType type = VaultType.bank]) =>
        showPulseSheet<bool>(
          context,
          full: true,
          builder: (_) => EntrySheet(type: type),
        );

    return CoachHost(
      screen: CoachScreen.vault,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Family vault'),
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.popOrHome(Routes.settings),
          ),
        ),
        body: ListView(
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
                  Text(
                    'A calm place for the things your family would need to find.',
                    style: context.tt.headlineSmall,
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    'Accounts, policies, loans, property and where the papers are. It says where to look, never passwords or card numbers. It stays on your phone and in your encrypted backup.',
                    style: context.tt.bodyMedium,
                  ),
                  const SizedBox(height: Space.lg),
                  if (score != null)
                    SurfaceCard(
                      key: const Key('vault_score'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            score.headline,
                            key: const Key('vault_score_text'),
                            style: context.tt.titleMedium,
                          ),
                          const SizedBox(height: Space.md),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(Radii.pill),
                            child: LinearProgressIndicator(
                              value: score.fraction.clamp(0, 1),
                              minHeight: 8,
                              backgroundColor: c.surfaceElevated,
                              color: c.accent,
                            ),
                          ),
                          if (score.missing.isNotEmpty) ...[
                            const SizedBox(height: Space.md),
                            Text(
                              'Next, maybe: ${_nextIdeas(score)}.',
                              key: const Key('vault_next'),
                              style: context.tt.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: Space.md),
                    SurfaceCard(
                      key: const Key('vault_suggestions'),
                      onTap: () => showPulseSheet<int>(
                        context,
                        full: true,
                        builder: (_) => SuggestionsSheet(suggestions),
                      ),
                      child: Row(
                        children: [
                          const IconWell(Icons.auto_awesome_outlined),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Add these ${suggestions.length} ${suggestions.length == 1 ? 'item' : 'items'} to your vault',
                                  style: context.tt.titleSmall,
                                ),
                                Text(
                                  'Already in Pulse: accounts, cards, loans, funds and subscriptions',
                                  style: context.tt.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            CoachTarget(
              id: 'add',
              child: SectionHeader(
                'What your family would need',
                action: 'Add',
                onAction: addEntry,
              ),
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Text(
                  'Nothing here yet. Start with one bank account, or let Pulse suggest a few.',
                  key: const Key('vault_empty'),
                  style: context.tt.bodyMedium,
                ),
              )
            else
              for (final type in VaultType.values)
                if (entries.any((e) => e.type == type)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      Space.md,
                      Space.gutter,
                      Space.xs,
                    ),
                    child: Text(type.label, style: context.tt.labelMedium),
                  ),
                  RowGroup(
                    indent: ListRow.leadingInset,
                    children: [
                      for (final e in entries.where((e) => e.type == type))
                        ListRow(
                          key: ValueKey('vault_entry_${e.id}'),
                          leading: IconWell(vaultIcon(e.type)),
                          title: e.displayName,
                          subtitle: _subtitle(e),
                          chevron: true,
                          onTap: () => showPulseSheet<bool>(
                            context,
                            full: true,
                            builder: (_) => EntrySheet(initial: e),
                          ),
                        ),
                    ],
                  ),
                ],
            const CoachTarget(
              id: 'nominee',
              child: SectionHeader('People you trust', top: Space.xl),
            ),
            if (nominees.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Text(
                  'Choose who should be able to find this: a spouse, a sibling, a lawyer.',
                  style: context.tt.bodyMedium,
                ),
              )
            else
              RowGroup(
                indent: ListRow.leadingInset,
                children: [
                  for (final n in nominees)
                    ListRow(
                      key: ValueKey('vault_nominee_${n.id}'),
                      leading: const IconWell(Icons.how_to_reg_outlined),
                      title: n.name,
                      subtitle: [
                        if (n.relationship.isNotEmpty) n.relationship,
                        n.seesAll
                            ? 'Sees everything'
                            : 'Sees ${n.entryIds!.length} ${n.entryIds!.length == 1 ? 'item' : 'items'}',
                      ].join(' · '),
                      chevron: true,
                      onTap: () => showPulseSheet<bool>(
                        context,
                        full: true,
                        builder: (_) => NomineeSheet(initial: n),
                      ),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.md,
                Space.gutter,
                0,
              ),
              child: PrimaryButton(
                key: const Key('vault_add_nominee'),
                label: 'Add a trusted person',
                secondary: true,
                icon: Icons.person_add_alt_1_outlined,
                onPressed: () => showPulseSheet<bool>(
                  context,
                  full: true,
                  builder: (_) => const NomineeSheet(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.sm,
                Space.gutter,
                0,
              ),
              child: PrimaryButton(
                key: const Key('vault_open_file'),
                label: 'Open a file someone left me',
                secondary: true,
                icon: Icons.lock_open_outlined,
                onPressed: () => showPulseSheet<void>(
                  context,
                  full: true,
                  builder: (_) => const OpenFileSheet(),
                ),
              ),
            ),
            const SectionHeader('Check-in', top: Space.xl),
            RowGroup(
              indent: ListRow.leadingInset,
              children: [
                ListRow(
                  key: const Key('vault_interval_row'),
                  leading: const IconWell(Icons.lock_clock_outlined),
                  title: 'Release window',
                  subtitle: _statusLine(status, interval),
                  chevron: true,
                  onTap: () => showPulseSheet<void>(
                    context,
                    builder: (_) => const _CheckInSheet(),
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
                ref.watch(inactivityRelayProvider).isAvailable
                    ? 'If you do not open Pulse for this long, the people you chose can ask for the sealed file.'
                    : 'Opening Pulse counts as checking in. Automatic release after a long silence needs a service that is not switched on yet, so for now you hand the sealed file over yourself.',
                key: const Key('vault_relay_note'),
                style: context.tt.bodySmall,
              ),
            ),
            if (status != null && status.phase != CheckInPhase.ok)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.sm,
                  Space.gutter,
                  0,
                ),
                child: Text(
                  status.phase == CheckInPhase.soon
                      ? 'It has been a while. Opening Pulse restarts the clock; there is nothing to do.'
                      : 'The window has passed. Opening Pulse restarts the clock.',
                  key: const Key('vault_reminder'),
                  style: context.tt.bodySmall!.copyWith(color: c.warning),
                ),
              ),
            const SectionHeader('Share', top: Space.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: PrimaryButton(
                key: const Key('vault_share_sheet'),
                label: 'Share emergency sheet',
                icon: Icons.ios_share_rounded,
                onPressed: entries.isEmpty
                    ? null
                    : () async {
                        final svc = ref.read(vaultServiceProvider);
                        final text = await svc.sheetText();
                        svc.noteExported('sheet');
                        await SharePlus.instance.share(
                          ShareParams(text: text, subject: 'Emergency sheet'),
                        );
                      },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.md,
                Space.gutter,
                0,
              ),
              child: Text(
                'A plain text list of where things are. It is an information aid, not a will. For who inherits what under UAE law, speak to a lawyer.',
                style: context.tt.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _nextIdeas(Completeness s) {
    final names = [
      for (final e in s.missing.entries.take(3)) e.key.label.toLowerCase(),
    ];
    return names.join(', ');
  }

  static String _subtitle(VaultEntry e) {
    final parts = <String>[
      if (e.whereToFind.trim().isNotEmpty)
        e.whereToFind.trim()
      else
        'Add where to find it',
      if (e.estimatedValueMinor != null) aedMinor(e.estimatedValueMinor!),
    ];
    return parts.join(' · ');
  }

  static String _statusLine(CheckInStatus? s, int? fallback) {
    if (s == null) return 'Every ${fallback ?? defaultCheckInDays} days';
    return switch (s.phase) {
      CheckInPhase.ok =>
        'About ${s.daysLeft} days left of silence before release',
      CheckInPhase.soon => '${s.daysLeft} days left. Opening Pulse restarts it',
      CheckInPhase.overdue => 'Window passed. Opening Pulse restarts it',
    };
  }
}

class _CheckInSheet extends ConsumerStatefulWidget {
  const _CheckInSheet();

  @override
  ConsumerState<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends ConsumerState<_CheckInSheet> {
  int? _days;
  final _name = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    () async {
      final svc = ref.read(vaultServiceProvider);
      final d = await svc.intervalDays();
      final n = await svc.ownerName();
      if (mounted)
        setState(() {
          _days = d;
          _name.text = n;
          _loaded = true;
        });
    }();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final svc = ref.read(vaultServiceProvider);
    await svc.setIntervalDays(_days ?? defaultCheckInDays);
    await svc.setOwnerName(_name.text);
    invalidateVault(ref);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Release window',
      subtitle: 'How long Pulse can go unopened before your trusted people may ask for the sealed file.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final d in checkInChoices)
                Pill(
                  d == 365 ? '1 year' : '$d days',
                  key: ValueKey('vault_interval_$d'),
                  selected: _days == d,
                  onTap: () => setState(() => _days = d),
                ),
            ],
          ),
          const FieldLabel('Your name on the emergency sheet'),
          TextField(
            key: const Key('vault_owner_name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Your name'),
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            key: const Key('vault_interval_save'),
            label: 'Save',
            onPressed: _loaded ? _save : null,
          ),
        ],
      ),
    );
  }
}
