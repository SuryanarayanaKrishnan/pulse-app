import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/analytics/analytics.dart';
import '../../core/widgets/widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/providers.dart';

void _toast(BuildContext context, String text) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(text)));

/// Starts Gmail OAuth (`POST /v1/email-connections/gmail/start`) and opens the
/// consent page. Returns true when a connection was started or completed.
Future<bool> connectGmail(BuildContext context, WidgetRef ref) async {
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
  }
}

/// Picks a PDF/CSV and uploads it (`POST /v1/statements/upload`).
Future<bool> uploadStatement(BuildContext context, WidgetRef ref) async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'csv'],
  );
  if (files.isEmpty) return false;
  final f = files.first;
  try {
    final bytes = await f.readAsBytes();
    final res = await ref
        .read(repositoryProvider)
        .uploadStatement(bytes: bytes, filename: f.name);
    ref.read(analyticsProvider).track(AnalyticsEvent.statementUploaded);
    ref.invalidate(statementsProvider);
    Haptics.success();
    if (context.mounted) {
      _toast(
        context,
        res.duplicate
            ? 'That statement is already in Pulse.'
            : 'Uploaded. Reading ${f.name} now.',
      );
    }
    return true;
  } on ApiException catch (e) {
    if (context.mounted) _toast(context, e.message);
    return false;
  }
}
