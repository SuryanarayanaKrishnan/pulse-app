import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/local/cas_import_service.dart';
import '../../data/providers.dart';
import '../statements/statement_actions.dart' show readPickedBytes;
import 'wealth_widgets.dart' show fmtNum;

/// The free request pages. Opened in the browser: the PAN is typed there, on
/// the registrar's own site, never in Pulse.
const camsCasUrl =
    'https://www.camsonline.com/Investors/Statements/Consolidated-Account-Statement';
const kfintechCasUrl =
    'https://mfs.kfintech.com/investor/General/ConsolidatedAccountStatement';
const mfCentralUrl = 'https://www.mfcentral.com';

typedef PickedPdf = ({Uint8List bytes, String name});

/// Lets the user choose the statement PDF. Overridden in tests.
final casPdfPickerProvider = Provider<Future<PickedPdf?> Function()>(
  (ref) => () async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final f = files.firstOrNull;
    if (f == null) return null;
    return (bytes: await readPickedBytes(f), name: f.name);
  },
);

/// Opens a link outside the app. Overridden in tests.
final casLinkOpenerProvider = Provider<Future<void> Function(String)>(
  (ref) => (url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  },
);

enum _Stage { guide, working, password, preview, done, problem }

/// Guided import of a CAMS/KFintech statement: get it (free, steps and
/// links), pick the PDF, enter its password, review, confirm. Everything is
/// read on this phone; the password is used once to open the file and is not
/// kept, and no PAN is read from the statement or saved.
class CasImportSheet extends ConsumerStatefulWidget {
  const CasImportSheet({super.key});
  @override
  ConsumerState<CasImportSheet> createState() => _CasImportSheetState();
}

class _CasImportSheetState extends ConsumerState<CasImportSheet> {
  _Stage _stage = _Stage.guide;
  Uint8List? _bytes;
  final _pw = TextEditingController();
  bool _wrongPassword = false;
  String? _problem;
  CasPreview? _preview;
  CasApplyReport? _report;

  @override
  void dispose() {
    _pw.dispose();
    _bytes = null;
    super.dispose();
  }

  Future<void> _pick() async {
    PickedPdf? f;
    try {
      f = await ref.read(casPdfPickerProvider)();
    } on Object {
      setState(() {
        _problem = 'Could not open that file. Try saving it to Files first.';
        _stage = _Stage.problem;
      });
      return;
    }
    if (f == null || !mounted) return;
    _bytes = f.bytes;
    _wrongPassword = false;
    await _read(null);
  }

  Future<void> _read(String? password) async {
    final bytes = _bytes;
    if (bytes == null) return;
    setState(() => _stage = _Stage.working);
    final svc = ref.read(casImportServiceProvider);
    final out = await svc.read(bytes, password: password);
    if (!mounted) return;
    switch (out.status) {
      case CasReadStatus.needsPassword:
      case CasReadStatus.wrongPassword:
        setState(() {
          _wrongPassword = out.status == CasReadStatus.wrongPassword;
          _stage = _Stage.password;
        });
      case CasReadStatus.ok:
        _pw.clear();
        final p = await svc.preview(out.statement!);
        if (!mounted) return;
        setState(() {
          _preview = p;
          _stage = _Stage.preview;
        });
      case CasReadStatus.demat:
        _fail(
          'This looks like a demat statement (NSDL/CDSL). Pulse reads the mutual fund statement from CAMS or KFintech here.',
        );
      case CasReadStatus.notAFundStatement:
        _fail(
          'That does not look like a CAMS or KFintech detailed statement. Request the "Detailed" statement for all funds and try again.',
        );
      case CasReadStatus.unreadable:
        _fail(
          'Could not read this PDF. It may be damaged or a scan without text.',
        );
    }
  }

  void _fail(String m) => setState(() {
    _problem = m;
    _stage = _Stage.problem;
  });

  Future<void> _confirm() async {
    final p = _preview;
    if (p == null) return;
    setState(() => _stage = _Stage.working);
    final r = await ref.read(casImportServiceProvider).apply(p);
    invalidateWealth(ref);
    if (!mounted) return;
    _bytes = null;
    setState(() {
      _report = r;
      _stage = _Stage.done;
    });
  }

  @override
  Widget build(BuildContext context) => switch (_stage) {
    _Stage.guide => _guide(context),
    _Stage.working => const SheetScaffold(
      title: 'Reading your statement',
      subtitle: 'On this phone only.',
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(Space.xl),
          child: CircularProgressIndicator(),
        ),
      ),
    ),
    _Stage.password => _password(context),
    _Stage.preview => _previewView(context),
    _Stage.done => _doneView(context),
    _Stage.problem => SheetScaffold(
      title: 'Could not import',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _problem ?? '',
            key: const Key('cas-problem'),
            style: context.tt.bodyMedium,
          ),
          const SizedBox(height: Space.lg),
          PrimaryButton(
            label: 'Choose another file',
            secondary: true,
            onPressed: _pick,
          ),
          const SizedBox(height: Space.sm),
          PrimaryButton(
            label: 'Back to the steps',
            secondary: true,
            onPressed: () => setState(() => _stage = _Stage.guide),
          ),
        ],
      ),
    ),
  };

  // ---- 1. get the statement -------------------------------------------------------

  Widget _step(
    BuildContext context,
    int n,
    String title,
    String body, {
    List<Widget> actions = const [],
  }) => Padding(
    padding: const EdgeInsets.only(bottom: Space.lg),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: context.pc.accent,
          child: Text(
            '$n',
            style: context.tt.labelSmall!.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(width: Space.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.tt.bodyLarge),
              const SizedBox(height: 2),
              Text(body, style: context.tt.bodySmall),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: Space.sm),
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.sm,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _guide(BuildContext context) {
    final open = ref.read(casLinkOpenerProvider);
    return SheetScaffold(
      title: 'Get your statement',
      subtitle:
          'Free from CAMS and KFintech. Pulse reads it on this phone only.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _step(
            context,
            1,
            'Request it, free',
            'Open the CAMS or KFintech page. Either one lists the funds of both. Enter your PAN and the email linked to your funds. '
                'Your PAN goes to their website, not to Pulse.',
            actions: [
              PrimaryButton(
                key: const Key('cas-open-cams'),
                label: 'CAMS',
                icon: Icons.open_in_new_rounded,
                secondary: true,
                expand: false,
                onPressed: () => open(camsCasUrl),
              ),
              PrimaryButton(
                key: const Key('cas-open-kfintech'),
                label: 'KFintech',
                icon: Icons.open_in_new_rounded,
                secondary: true,
                expand: false,
                onPressed: () => open(kfintechCasUrl),
              ),
            ],
          ),
          _step(
            context,
            2,
            'Choose Detailed, all funds',
            'Pick the "Detailed" statement, a period from the start (for example 1990 to today), and include zero-balance folios. '
                'Set a password for the PDF (you will type it here once). Submit.',
          ),
          _step(
            context,
            3,
            'Save the PDF from your email',
            'It usually arrives within minutes at the email you entered. Save the attachment to Files.',
          ),
          _step(
            context,
            4,
            'Choose it here',
            'Pulse opens it on this phone, shows what it found and waits for your OK before saving anything.',
          ),
          PrimaryButton(
            key: const Key('cas-have-pdf'),
            label: 'I have the PDF',
            icon: Icons.upload_file_outlined,
            onPressed: _pick,
          ),
          const SizedBox(height: Space.md),
          Text(
            'Why not just use my PAN? No free service returns your funds from a PAN alone: the registrars only send a statement to the email on record. '
            'MF Central (${mfCentralUrl.replaceFirst('https://', '')}) also gives the same statement after a login.',
            style: context.tt.bodySmall!.copyWith(
              color: context.pc.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ---- 2. password ----------------------------------------------------------------

  Widget _password(BuildContext context) => SheetScaffold(
    title: 'Statement password',
    subtitle: 'The password you set on the request form.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('cas-password'),
          controller: _pw,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => _read(v),
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: _wrongPassword
                ? 'That password did not open the statement'
                : null,
          ),
        ),
        const SizedBox(height: Space.sm),
        Text(
          'It opens this one file on your phone, right now. It is not saved, logged or sent anywhere. '
          'Some statements from the depositories use your PAN in capitals as the password.',
          style: context.tt.bodySmall,
        ),
        const SizedBox(height: Space.lg),
        PrimaryButton(
          key: const Key('cas-open'),
          label: 'Open statement',
          onPressed: () => _read(_pw.text),
        ),
      ],
    ),
  );

  // ---- 3. review ------------------------------------------------------------------

  static String _inr(num v) => 'INR ${Money.number(v, decimals: false)}';

  Widget _previewView(BuildContext context) {
    final p = _preview!;
    final c = context.pc;
    final n = p.candidates.where((x) => x.include && x.nav != null).length;
    if (p.candidates.isEmpty) {
      return SheetScaffold(
        title: 'Nothing to import',
        child: Text(
          'Every fund on this statement has no units left.',
          style: context.tt.bodyMedium,
        ),
      );
    }
    return SheetScaffold(
      title:
          'Review ${p.candidates.length} fund${p.candidates.length == 1 ? '' : 's'}',
      subtitle: 'Nothing is saved until you confirm.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final x in p.candidates)
            Padding(
              key: Key('cas-row-${x.schemeCode ?? x.name}'),
              padding: const EdgeInsets.only(bottom: Space.md),
              child: Container(
                padding: const EdgeInsets.all(Space.md),
                decoration: BoxDecoration(
                  color: c.surfaceElevated,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: x.include,
                          onChanged: (v) =>
                              setState(() => x.include = v ?? true),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(x.name, style: context.tt.bodyLarge),
                              Text(
                                '${fmtNum(x.units, maxDecimals: 3)} units'
                                '${x.nav == null ? '' : ' · NAV ${x.nav!.toStringAsFixed(4)}'}'
                                '${x.nav == null ? '' : ' · ${_inr(x.units * x.nav!)}'}',
                                style: context.tt.bodySmall,
                              ),
                              Text(
                                x.isUpdate
                                    ? 'Updates your existing holding'
                                    : (x.matched
                                          ? 'New · live NAV from AMFI'
                                          : 'New · saved by hand, no live NAV'),
                                style: context.tt.bodySmall!.copyWith(
                                  color: c.textTertiary,
                                ),
                              ),
                              if (x.folios > 1)
                                Text(
                                  '${x.folios} folios combined',
                                  style: context.tt.bodySmall!.copyWith(
                                    color: c.textTertiary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    for (final f in x.flags)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.xs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: c.warning,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                f,
                                style: context.tt.bodySmall!.copyWith(
                                  color: c.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (x.sip != null)
                      SwitchListTile(
                        key: Key('cas-sip-${x.schemeCode ?? x.name}'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: x.useSip,
                        onChanged: (v) => setState(() => x.useSip = v),
                        title: Text(
                          'Save SIP ${_inr(x.sip!.amountMinor / 100)} on day ${x.sip!.day}',
                          style: context.tt.bodyMedium,
                        ),
                        subtitle: Text(
                          '${x.sip!.count} instalments seen${x.sip!.approximate ? ' (a guess from the pattern)' : ''}',
                          style: context.tt.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (p.closedSchemes > 0)
            Text(
              '${p.closedSchemes} fund${p.closedSchemes == 1 ? '' : 's'} with no units left ${p.closedSchemes == 1 ? 'is' : 'are'} skipped.',
              style: context.tt.bodySmall,
            ),
          Text(
            p.amfiOffline
                ? 'Could not refresh AMFI NAVs, so NAVs are from the statement${p.periodTo == null ? '' : ' (to ${p.periodTo})'} or the last AMFI file.'
                : 'NAVs from AMFI${p.amfiAsOf == null ? '' : ', as of ${p.amfiAsOf}'}.',
            style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: Space.lg),
          PrimaryButton(
            key: const Key('cas-confirm'),
            label: n == 0
                ? 'Nothing selected'
                : 'Add $n fund${n == 1 ? '' : 's'}',
            onPressed: n == 0 ? null : _confirm,
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Only units, cost, NAV and SIP are saved, on this phone. Not your PAN, the password or the PDF.',
            style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _doneView(BuildContext context) {
    final r = _report!;
    return SheetScaffold(
      title: 'Done',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${r.added} added, ${r.updated} updated'
            '${r.sips > 0 ? ', ${r.sips} SIP${r.sips == 1 ? '' : 's'} saved' : ''}.'
            '${r.manual > 0 ? ' ${r.manual} without a live NAV.' : ''}',
            key: const Key('cas-done'),
            style: context.tt.bodyMedium,
          ),
          const SizedBox(height: Space.lg),
          PrimaryButton(
            label: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
