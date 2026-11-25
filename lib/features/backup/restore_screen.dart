import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../backup/backup_providers.dart';
import '../../backup/recovery_phrase.dart';
import '../../backup/restore_flow.dart';
import '../../backup/restore_service.dart';
import '../../core/analytics/analytics.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../auth/session.dart';
import 'backup_widgets.dart';

enum _Step { source, signIn, secret, pick, working, done }

/// "Restore from backup" during onboarding on a new phone: choose where the
/// backup is, sign in (cloud), enter the key, pick a version, restore.
class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({super.key, this.now, this.startAt});
  final DateTime? now;

  /// Screenshots and tests: open on a later step of the scripted demo flow.
  final String? startAt;

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  _Step _step = _Step.source;
  RestoreSource _source = RestoreSource.cloud;
  String? _filePath;
  String? _fileName;
  final _secret = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  UnlockResult? _found;
  String? _choice;
  double _progress = 0;
  RestoreFlow? _flow;

  @override
  void initState() {
    super.initState();
    if (widget.startAt == 'secret') _step = _Step.secret;
    if (widget.startAt == 'pick') {
      _step = _Step.pick;
      final n = widget.now ?? DateTime.now();
      _found = UnlockResult([
        BackupChoice(
          id: 'v3',
          createdAt: n.subtract(const Duration(hours: 5)),
          rows: 1342,
          photos: 14,
        ),
        BackupChoice(
          id: 'v2',
          createdAt: n.subtract(const Duration(days: 2)),
          rows: 1318,
          photos: 14,
        ),
        BackupChoice(
          id: 'v1',
          createdAt: n.subtract(const Duration(days: 9)),
          rows: 1204,
          photos: 11,
        ),
      ]);
      _choice = 'v3';
    }
  }

  @override
  void dispose() {
    for (final c in [_secret, _email, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<RestoreFlow> _getFlow() async {
    final existing = _flow;
    if (existing != null) return existing;
    final fresh = await ref.read(restoreFlowProvider.future);
    _flow = fresh;
    return fresh;
  }

  void _go(_Step s) => setState(() {
    _step = s;
    _error = null;
  });

  String get _sourceName => _source == RestoreSource.cloud ? 'cloud' : 'file';

  Future<void> _chooseSource(RestoreSource s) async {
    _source = s;
    ref
        .read(analyticsProvider)
        .track(AnalyticsEvent.onboardingStepCompleted('restore_${s.name}'));
    if (s == RestoreSource.file) {
      final picked = await FilePicker.pickFiles(type: FileType.any);
      if (picked.isEmpty || picked.first.path == null) return;
      setState(() {
        _filePath = picked.first.path;
        _fileName = picked.first.name;
      });
      _go(_Step.secret);
      return;
    }
    final flow = await _getFlow();
    _go(flow.needsSignIn ? _Step.signIn : _Step.secret);
  }

  Future<void> _signIn() async {
    final s = ref.read(sessionProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_codeSent) {
        if (!_email.text.contains('@')) throw 'Enter a valid email';
        await s.requestEmailOtp(_email.text.trim());
        setState(() => _codeSent = true);
      } else {
        final ok = await s.verifyEmailOtp(
          _email.text.trim(),
          _code.text.trim(),
        );
        if (!ok) throw 'That code did not work';
        _go(_Step.secret);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final flow = await _getFlow();
      ref
          .read(analyticsProvider)
          .track(AnalyticsEvent.restoreStarted(_sourceName));
      final r = await flow.unlock(_source, _secret.text, filePath: _filePath);
      setState(() {
        _found = r;
        _choice = r.choices.first.id;
      });
      _go(_Step.pick);
    } catch (e) {
      setState(() => _error = describeRestoreError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final flow = await _getFlow();
    if (await flow.hasExistingData()) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace what is on this phone?'),
          content: const Text(
            'This phone already has data in Pulse. Restoring replaces it with the backup. '
            'A safety copy of the current data is kept for 7 days.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _progress = 0;
      _step = _Step.working;
      _error = null;
    });
    try {
      await flow.restore(
        _choice!,
        onProgress: (p) => mounted ? setState(() => _progress = p) : null,
      );
      await flow.reopen();
      if (mounted) _go(_Step.done);
    } catch (e) {
      if (mounted) {
        _go(_Step.pick);
        setState(() => _error = describeRestoreError(e));
      }
    }
  }

  void _open() {
    final s = ref.read(sessionProvider);
    s
      ..finishOnboarding()
      ..signIn()
      ..finishConnect();
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final now = widget.now ?? DateTime.now();
    switch (_step) {
      case _Step.source:
        final cloudOk = ref
            .watch(restoreFlowProvider)
            .maybeWhen(data: (f) => f.cloudAvailable, orElse: () => true);
        return FlowPage(
          title: 'Restore from backup',
          subtitle: 'Bring your data to this phone. You will need your recovery phrase or passphrase.',
          onBack: () => context.go(Routes.onboarding),
          children: [
            ChoiceTile(
              icon: Icons.cloud_download_outlined,
              title: 'From my Pulse account',
              subtitle: cloudOk
                  ? 'Sign in, then pick a saved version.'
                  : 'Not available in this build.',
              selected: false,
              onTap: cloudOk ? () => _chooseSource(RestoreSource.cloud) : null,
            ),
            const SizedBox(height: Space.md),
            ChoiceTile(
              icon: Icons.insert_drive_file_outlined,
              title: 'From a backup file',
              subtitle: 'Choose a .pulsebak file you exported earlier.',
              selected: false,
              onTap: () => _chooseSource(RestoreSource.file),
            ),
            const SizedBox(height: Space.xl),
            const Callout(
              icon: Icons.lock_outline_rounded,
              text: 'Your backup is encrypted. It is opened here on this phone, never on a server.',
            ),
          ],
        );
      case _Step.signIn:
        return FlowPage(
          title: 'Sign in',
          subtitle: 'Use the same email you used on your old phone.',
          onBack: () => _go(_Step.source),
          actions: [
            PrimaryButton(
              label: _codeSent ? 'Verify and continue' : 'Email me a code',
              loading: _busy,
              onPressed: _signIn,
            ),
          ],
          children: [
            TextField(
              controller: _email,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              enabled: !_codeSent,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            if (_codeSent) ...[
              const SizedBox(height: Space.md),
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  hintText: '6-digit code',
                  counterText: '',
                  prefixIcon: Icon(Icons.password_rounded),
                ),
              ),
            ],
            if (_error != null) _err(context, _error!),
          ],
        );
      case _Step.secret:
        final isPhrase = RecoveryPhrase.looksLikePhrase(_secret.text);
        return FlowPage(
          title: 'Enter your key',
          subtitle: _fileName == null
              ? 'Your 12-word recovery phrase, or the passphrase you chose.'
              : 'To open $_fileName, enter your recovery phrase or passphrase.',
          onBack: () => _go(_Step.source),
          actions: [
            PrimaryButton(
              label: 'Unlock backup',
              icon: Icons.lock_open_rounded,
              loading: _busy,
              onPressed: _secret.text.trim().isEmpty ? null : _unlock,
            ),
          ],
          children: [
            TextField(
              controller: _secret,
              obscureText: _obscure,
              maxLines: 1,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Recovery phrase or passphrase',
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show' : 'Hide',
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
            if (isPhrase)
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: c.positive,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Recovery phrase recognised',
                      style: context.tt.bodySmall!.copyWith(color: c.positive),
                    ),
                  ),
                ],
              ),
            if (_error != null) _err(context, _error!),
            const SizedBox(height: Space.xl),
            Callout(
              warning: true,
              icon: Icons.info_outline_rounded,
              text: 'Forgotten it? There is no reset: the key exists only with you, so a backup without it cannot be opened by anyone.',
            ),
          ],
        );
      case _Step.pick:
        final found = _found!;
        return FlowPage(
          title: 'Choose a backup',
          subtitle: 'Nothing on this phone changes until the backup is checked and ready.',
          onBack: () => _go(_Step.secret),
          actions: [
            PrimaryButton(
              label: 'Restore this backup',
              onPressed: _choice == null ? null : _restore,
            ),
          ],
          children: [
            for (final (i, b) in found.choices.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: ChoiceTile(
                  title: formatWhen(b.createdAt, now),
                  badge: i == 0 ? 'Latest' : null,
                  subtitle:
                      '${_n(b.rows)} records${b.photos > 0 ? ', ${b.photos} photos and documents' : ''}',
                  selected: _choice == b.id,
                  onTap: () => setState(() => _choice = b.id),
                ),
              ),
            if (found.damaged > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: Text(
                  '${found.damaged} ${found.damaged == 1 ? 'version was' : 'versions were'} damaged and hidden.',
                  style: context.tt.bodySmall,
                ),
              ),
            if (_error != null) _err(context, _error!),
          ],
        );
      case _Step.working:
        return FlowPage(
          title: 'Restoring',
          subtitle: 'Decrypting and checking every piece. This phone keeps its current data until all of it passes.',
          children: [
            Meter(value: _progress, color: c.accent, height: 6),
            const SizedBox(height: Space.md),
            Text('${(_progress * 100).round()}%', style: context.tt.bodyMedium),
          ],
        );
      case _Step.done:
        return FlowPage(
          title: 'You are back',
          subtitle: 'Your data is on this phone and protected with a new key made for it.',
          actions: [
            PrimaryButton(label: 'Open ${_appName()}', onPressed: _open),
          ],
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: c.positive,
            ),
            const SizedBox(height: Space.xl),
            const Callout(
              icon: Icons.sync_rounded,
              text: 'Backups carry on from here with the same key, so there is nothing more to set up.',
            ),
          ],
        );
    }
  }

  String _appName() => 'Pulse';

  String _n(int v) => v.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  Widget _err(BuildContext context, String e) => Padding(
    padding: const EdgeInsets.only(top: Space.md),
    child: Text(e, style: TextStyle(color: context.pc.negative)),
  );
}
