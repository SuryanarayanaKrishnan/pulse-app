import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../bugreport/launcher.dart';
import '../../core/analytics/analytics.dart';
import '../../core/engine/statement_import.dart';
import '../../core/network/cloud_access.dart';
import '../../core/widgets/widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/providers.dart';
import 'statement_problem_sheet.dart';
import 'statements_screen.dart' show PasswordSheet;

void _toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// Extensions the picker offers. iOS turns each into a UTType, so these are
/// the file types Files will let the user tap.
const statementExtensions = ['pdf', 'csv', 'tsv', 'xlsx', 'xls', 'txt'];

/// Bytes of a picked file. iOS hands over a copy inside the app's sandbox, so
/// reading by path works too; both are tried before giving up.
Future<Uint8List> readPickedBytes(PlatformFile f) async {
  try {
    return await f.readAsBytes();
  } catch (_) {
    final path = f.path;
    if (path != null) {
      try {
        return await File(path).readAsBytes();
      } catch (_) {}
    }
    throw StatementImportException.couldNotOpen.copyWith(filename: f.name);
  }
}

/// Starts Gmail OAuth (`POST /v1/email-connections/gmail/start`) and opens the
/// consent page. Needs a Pulse account, so without one it shows the shared
/// "Available once you're signed in" state. Returns true when a connection
/// was started or completed.
Future<bool> connectGmail(BuildContext context, WidgetRef ref) async {
  if (!ref.read(cloudAccessProvider).isReady) {
    await showPulseSheet<void>(
      context,
      builder: (_) => const SheetScaffold(
        title: 'Gmail statements',
        child: NeedsSignIn(
          feature: 'Finds bank statements in your inbox. Read-only.',
          detail: 'You can still add statements from Files in the meantime.',
        ),
      ),
    );
    return false;
  }
  try {
    final uri = await ref.read(repositoryProvider).startGmailConnect();
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Haptics.success();
    }
    ref.read(analyticsProvider).track(AnalyticsEvent.sourceConnected('gmail'));
    ref.invalidate(emailConnectionsProvider);
    ref.invalidate(statementsProvider);
    return true;
  } on ApiException catch (e) {
    if (context.mounted) _toast(context, e.message);
    return false;
  } catch (_) {
    if (context.mounted)
      _toast(
        context,
        'Could not reach Gmail right now. Try again in a moment.',
      );
    return false;
  }
}

/// Stops reading a Gmail account. Statements already saved stay.
Future<bool> disconnectGmail(
  BuildContext context,
  WidgetRef ref,
  String connectionId,
) async {
  try {
    await ref.read(repositoryProvider).disconnectEmail(connectionId);
    ref.invalidate(emailConnectionsProvider);
    if (context.mounted) {
      _toast(context, 'Gmail is off. Statements already saved stay.');
    }
    return true;
  } on ApiException catch (e) {
    if (context.mounted) _toast(context, e.message);
    return false;
  } catch (_) {
    if (context.mounted) {
      _toast(context, 'Could not turn Gmail off right now. Try again.');
    }
    return false;
  }
}

/// Picks a statement file (PDF, CSV, Excel, text) and reads it on this phone.
/// Nothing is uploaded. Every failure ends in a sheet that says what is wrong
/// and what to do next.
Future<bool> uploadStatement(BuildContext context, WidgetRef ref) async {
  final List<PlatformFile> files;
  try {
    files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: statementExtensions,
    );
  } catch (_) {
    if (context.mounted) {
      await showStatementProblem(
        context,
        ref,
        StatementImportException.couldNotOpen,
      );
    }
    return false;
  }
  if (files.isEmpty) return false;
  final f = files.first;
  Uint8List bytes;
  try {
    bytes = await readPickedBytes(f);
  } on StatementImportException catch (e) {
    if (context.mounted) await showStatementProblem(context, ref, e);
    return false;
  }
  if (!context.mounted) return false;
  return importStatementBytes(context, ref, bytes: bytes, filename: f.name);
}

/// Reads [bytes] and reports the result. [columns] and [rows] come from the
/// column-mapping sheet.
Future<bool> importStatementBytes(
  BuildContext context,
  WidgetRef ref, {
  required Uint8List bytes,
  required String filename,
  StatementColumns? columns,
  List<List<String>>? rows,
}) async {
  try {
    final svc = ref.read(localStatementServiceProvider);
    final bool duplicate;
    if (svc != null) {
      duplicate = (await svc.upload(
        bytes: bytes,
        filename: filename,
        columns: columns,
        rows: rows,
      )).duplicate;
    } else {
      duplicate =
          (await ref
                  .read(repositoryProvider)
                  .uploadStatement(bytes: bytes, filename: filename))
              .duplicate;
    }
    ref.read(analyticsProvider).track(AnalyticsEvent.statementUploaded);
    ref.invalidate(statementsProvider);
    Haptics.success();
    if (context.mounted) {
      _toast(
        context,
        duplicate ? 'That statement is already in Pulse.' : 'Read $filename.',
      );
    }
    return true;
  } on StatementImportException catch (e) {
    ref.invalidate(statementsProvider);
    if (context.mounted) {
      await showStatementProblem(context, ref, e, bytes: bytes);
    }
    return false;
  } on NeedsSignInException {
    if (context.mounted) {
      await showPulseSheet<void>(
        context,
        builder: (_) => const SheetScaffold(
          title: 'Statements',
          child: NeedsSignIn(feature: 'Reading statements on this build.'),
        ),
      );
    }
    return false;
  } on ApiException catch (e) {
    if (context.mounted) _toast(context, e.message);
    return false;
  } catch (_) {
    if (context.mounted) {
      await showStatementProblem(
        context,
        ref,
        StatementImportException.damaged.copyWith(filename: filename),
      );
    }
    return false;
  }
}

/// Shows [e] with its next steps: the password prompt for a locked PDF, the
/// column picker for an unknown table, "send us a sample" for an unknown bank.
Future<void> showStatementProblem(
  BuildContext context,
  WidgetRef ref,
  StatementImportException e, {
  Uint8List? bytes,
}) async {
  if (e.problem == StatementProblem.passwordNeeded ||
      e.problem == StatementProblem.wrongPassword) {
    await showPulseSheet<void>(
      context,
      builder: (_) => PasswordSheet(
        institution: e.institution,
        statementId: e.statementId,
        notice: e.problem == StatementProblem.wrongPassword ? e.message : null,
      ),
    );
    return;
  }
  final action = await showPulseSheet<StatementProblemAction>(
    context,
    full: e.canMapColumns,
    builder: (_) => StatementProblemSheet(problem: e),
  );
  if (!context.mounted || action == null) return;
  switch (action) {
    case StatementProblemAction.chooseAnother:
      await uploadStatement(context, ref);
    case StatementProblemAction.sendSample:
      await ref.read(bugReportLauncherProvider).launch('settings');
    case StatementProblemAction.mapColumns:
      final rows = e.rows;
      if (rows == null || bytes == null) return;
      final cols = await showPulseSheet<StatementColumns>(
        context,
        full: true,
        builder: (_) => ColumnMappingSheet(rows: rows),
      );
      if (cols != null && context.mounted) {
        await importStatementBytes(
          context,
          ref,
          bytes: bytes,
          filename: e.filename ?? 'statement',
          columns: cols,
          rows: rows,
        );
      }
  }
}
