import 'dart:math';

import '../../core/network/cloud_access.dart';
import '../../core/router/router.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../backup/backup_controller.dart';
import '../../backup/backup_crypto.dart';
import '../../backup/backup_providers.dart';
import '../../backup/backup_state.dart';
import '../../backup/recovery_phrase.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import 'backup_widgets.dart';

enum _Step {
  current,
  choose,
  phrase,
  confirmPhrase,
  passphrase,
  destination,
  working,
  done,
}

/// Turn backup on (or, with [change], replace the secret). The recovery
/// phrase is shown once and must be proven before it is accepted.
class BackupSetupScreen extends ConsumerStatefulWidget {
  const BackupSetupScreen({super.key, this.change = false, this.fixedPhrase});
  final bool change;

  /// Tests and screenshots: use these words instead of generating some.
  final List<String>? fixedPhrase;

  @override
  ConsumerState<BackupSetupScreen> createState() => _BackupSetupScreenState();
}

class _BackupSetupScreenState extends ConsumerState<BackupSetupScreen> {
  late _Step _step = widget.change ? _Step.current : _Step.choose;
  bool _usePhrase = true;
  List<String> _words = const [];
  late final List<int> _quiz;
  final _quizCtl = List.generate(3, (_) => TextEditingController());
  final _current = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _understood = false;
  bool _obscure = true;
  BackupDestination _dest = BackupDestination.cloud;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final r = Random.secure();
    final picks = <int>{};
    while (picks.length < 3) {
      picks.add(r.nextInt(12));
    }
    _quiz = picks.toList()..sort();
  }

  @override
  void dispose() {
    for (final c in [..._quizCtl, _current, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  BackupController get _ctl => ref.read(backupControllerProvider);

  void _go(_Step s) => setState(() {
    _step = s;
    _error = null;
  });

  void _back() {
    switch (_step) {
      case _Step.current || _Step.choose || _Step.done || _Step.working:
        context.popOrHome();
      case _Step.phrase || _Step.passphrase:
        _go(_Step.choose);
      case _Step.confirmPhrase:
        _go(_Step.phrase);
      case _Step.destination:
        _go(_usePhrase ? _Step.confirmPhrase : _Step.passphrase);
    }
  }

  void _chosen() {
    if (_usePhrase) {
      if (_words.isEmpty)
        _words = widget.fixedPhrase ?? RecoveryPhrase.generate();
      _go(_Step.phrase);
    } else {
      _go(_Step.passphrase);
    }
  }

  bool get _quizOk => [
    for (var i = 0; i < 3; i++)
      _quizCtl[i].text.trim().toLowerCase() == _words[_quiz[i]],
  ].every((x) => x);

  String get _secret => _usePhrase ? _words.join(' ') : _pass.text;

  Future<void> _finish({bool replace = false}) async {
    setState(() {
      _busy = true;
      _error = null;
      _step = _Step.working;
    });
    try {
      final kind = _usePhrase ? 'phrase' : 'passphrase';
      if (widget.change) {
        await _ctl.changePassphrase(
          current: _current.text,
          next: _secret,
          nextKind: kind,
        );
      } else {
        await _ctl.enable(
          secret: _secret,
          secretKind: kind,
          destination: _dest,
          replaceExisting: replace,
        );
      }
      if (mounted) _go(_Step.done);
    } on BackupAlreadyExists {
      if (!mounted) return;
      _go(_Step.destination);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('This account already has a backup'),
          content: const Text(
            'To use it on this phone, cancel and choose "Restore from backup" when setting up Pulse. '
            'Or replace it: the old cloud backup is permanently deleted and a new one starts from this phone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Replace it'),
            ),
          ],
        ),
      );
      if (ok == true && mounted) await _finish(replace: true);
    } on WrongPassphrase {
      if (mounted) {
        _go(_Step.current);
        setState(
          () => _error =
              'That is not your current passphrase or recovery phrase.',
        );
      }
    } catch (e) {
      if (mounted) {
        _go(widget.change ? _Step.passphrase : _Step.destination);
        setState(() => _error = describeBackupError(e).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final cloudOk = ref.watch(backupControllerProvider).cloudAvailable;
    switch (_step) {
      case _Step.current:
        return FlowPage(
          title: 'Enter your current key',
          subtitle: 'Your recovery phrase or passphrase, to prove it is you.',
          onBack: _back,
          actions: [
            PrimaryButton(
              label: 'Continue',
              onPressed: _current.text.trim().isEmpty
                  ? null
                  : () => _go(_Step.choose),
            ),
          ],
          children: [
            TextField(
              controller: _current,
              minLines: 1,
              maxLines: 3,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Recovery phrase or passphrase',
              ),
            ),
            if (_error != null) _errorText(context, _error!),
          ],
        );
      case _Step.choose:
        return FlowPage(
          title: widget.change ? 'Choose a new key' : 'Protect your backup',
          subtitle: 'Pick how you will unlock it on a new phone.',
          onBack: _back,
          actions: [PrimaryButton(label: 'Continue', onPressed: _chosen)],
          children: [
            ChoiceTile(
              icon: Icons.format_list_numbered_rounded,
              title: 'Recovery phrase',
              badge: 'Recommended',
              subtitle: '12 words we generate for you. Strong, and easy to write down.',
              selected: _usePhrase,
              onTap: () => setState(() => _usePhrase = true),
            ),
            const SizedBox(height: Space.md),
            ChoiceTile(
              icon: Icons.password_rounded,
              title: 'My own passphrase',
              subtitle: 'You choose it, at least 10 characters. Only as strong as what you pick.',
              selected: !_usePhrase,
              onTap: () => setState(() => _usePhrase = false),
            ),
            const SizedBox(height: Space.xl),
            const Callout(
              warning: true,
              icon: Icons.warning_amber_rounded,
              title: 'There is no reset',
              text: 'Pulse never sees your key. If you forget it and lose the recovery phrase, your backup cannot be recovered, by you or by us.',
            ),
          ],
        );
      case _Step.phrase:
        return FlowPage(
          title: 'Your recovery phrase',
          subtitle: 'Write these 12 words down, in order. This is the only time they are shown.',
          onBack: _back,
          actions: [
            PrimaryButton(
              label: 'I have written it down',
              onPressed: () => _go(_Step.confirmPhrase),
            ),
          ],
          children: [
            PhraseGrid(_words),
            const SizedBox(height: Space.lg),
            const Callout(
              icon: Icons.edit_note_rounded,
              text: 'Use paper, not a screenshot or a note in this phone. Keep it somewhere safe. Anyone who has these words can read your backup.',
            ),
          ],
        );
      case _Step.confirmPhrase:
        return FlowPage(
          title: 'Check your copy',
          subtitle: 'Type these words from what you wrote down.',
          onBack: _back,
          actions: [
            PrimaryButton(
              label: 'Continue',
              onPressed: _quizOk ? () => _go(_Step.destination) : null,
            ),
          ],
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: TextField(
                  controller: _quizCtl[i],
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(hintText: 'Word ${_quiz[i] + 1}'),
                ),
              ),
            TextAction('Show the words again', onTap: () => _go(_Step.phrase)),
          ],
        );
      case _Step.passphrase:
        final strength = passphraseStrength(_pass.text);
        final match = _pass.text == _pass2.text && _pass.text.isNotEmpty;
        final ok =
            strength != PassphraseStrength.tooShort && match && _understood;
        return FlowPage(
          title: 'Choose a passphrase',
          subtitle: 'Long beats clever. Four or more random words work well.',
          onBack: _back,
          actions: [
            PrimaryButton(
              label: widget.change ? 'Change passphrase' : 'Continue',
              onPressed: ok
                  ? (widget.change ? _finish : () => _go(_Step.destination))
                  : null,
            ),
          ],
          children: [
            TextField(
              controller: _pass,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Passphrase',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: Space.sm),
            Text(
              switch (strength) {
                PassphraseStrength.tooShort =>
                  _pass.text.isEmpty
                      ? 'At least 10 characters'
                      : 'Too short, 10 characters or more',
                PassphraseStrength.fair => 'Okay. Longer is better.',
                PassphraseStrength.good => 'Strong',
              },
              style: context.tt.bodySmall!.copyWith(
                color: strength == PassphraseStrength.good
                    ? c.positive
                    : c.textSecondary,
              ),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: _pass2,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Type it again',
                errorText: _pass2.text.isNotEmpty && !match
                    ? 'Does not match'
                    : null,
              ),
            ),
            const SizedBox(height: Space.lg),
            InkWell(
              onTap: () => setState(() => _understood = !_understood),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _understood,
                    onChanged: (v) => setState(() => _understood = v ?? false),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'I understand that if I forget this passphrase, my backup cannot be recovered by anyone.',
                        style: context.tt.bodyMedium!.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) _errorText(context, _error!),
          ],
        );
      case _Step.destination:
        return FlowPage(
          title: 'Where should it go?',
          subtitle: 'Either way it is encrypted before it leaves this phone.',
          onBack: _back,
          actions: [
            PrimaryButton(
              label: 'Turn on backup',
              icon: Icons.lock_rounded,
              onPressed: _busy ? null : _finish,
            ),
          ],
          children: [
            ChoiceTile(
              icon: Icons.cloud_outlined,
              title: 'Pulse cloud',
              badge: cloudOk ? 'Automatic' : null,
              subtitle: cloudOk
                  ? 'Backs up by itself on Wi-Fi and can be restored on any phone you sign in on.'
                  : needsSignInTitle,
              selected: _dest == BackupDestination.cloud && cloudOk,
              onTap: cloudOk
                  ? () => setState(() => _dest = BackupDestination.cloud)
                  : null,
            ),
            const SizedBox(height: Space.md),
            ChoiceTile(
              icon: Icons.insert_drive_file_outlined,
              title: 'A file I keep myself',
              subtitle: 'No upload. You export the encrypted file and store it wherever you like.',
              selected: _dest == BackupDestination.file || !cloudOk,
              onTap: () => setState(() => _dest = BackupDestination.file),
            ),
            if (_error != null) _errorText(context, _error!),
          ],
        );
      case _Step.working:
        return FlowPage(
          title: widget.change ? 'Changing your key' : 'Setting up your backup',
          subtitle: 'Deriving your key takes a few seconds on purpose.',
          children: const [
            Center(
              child: Padding(
                padding: EdgeInsets.all(Space.xl),
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        );
      case _Step.done:
        return FlowPage(
          title: widget.change ? 'Key changed' : 'Backup is on',
          subtitle: widget.change
              ? 'Your old passphrase no longer opens new or existing backups from this account.'
              : (_dest == BackupDestination.cloud
                    ? 'Your first backup is on its way. After this it happens by itself.'
                    : 'Use "Export encrypted file" in Backup whenever you want a copy.'),
          actions: [
            PrimaryButton(label: 'Done', onPressed: () => context.popOrHome()),
          ],
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: c.positive,
            ),
            if (!widget.change) ...[
              const SizedBox(height: Space.xl),
              const Callout(
                icon: Icons.phonelink_setup_rounded,
                text: 'On a new phone, choose "Restore from backup" when you first open Pulse, then enter your key.',
              ),
            ],
          ],
        );
    }
  }

  Widget _errorText(BuildContext context, String e) => Padding(
    padding: const EdgeInsets.only(top: Space.md),
    child: Text(e, style: TextStyle(color: context.pc.negative)),
  );
}
