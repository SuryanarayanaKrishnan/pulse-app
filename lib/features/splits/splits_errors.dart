import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../bugreport/bug_log.dart';
import '../../core/analytics/analytics.dart';
import '../../data/api/api_exception.dart';

/// Which Splits action failed (an analytics-safe fixed set).
enum SplitsAction {
  createGroup('create_group', 'create the group'),
  addExpense('add_expense', 'add the expense'),
  addPeople('add_people', 'add people'),
  settle('settle', 'mark it as paid'),
  confirm('confirm', 'confirm the payment');

  const SplitsAction(this.key, this.phrase);
  final String key;
  final String phrase;
}

/// A coarse, content-free reason for [error].
String splitsFailureReason(Object error) {
  if (error is ApiException) {
    return error.code == 'not_supported' ? 'not_supported' : 'offline';
  }
  if (error is ArgumentError || error is FormatException) return 'invalid';
  final t = error.toString().toLowerCase();
  if (t.contains('sql') || t.contains('database') || t.contains('drift')) {
    return 'storage';
  }
  return 'other';
}

/// What the person reads when [error] stops [action].
String splitsFailureMessage(SplitsAction action, Object error) {
  if (error is ApiException) return error.message;
  if (error is ArgumentError) {
    return error.message?.toString() ?? 'Check the details and try again.';
  }
  return 'Could not ${action.phrase}. Please try again.';
}

/// Never fail silently: log the error (redacted, in memory), send an
/// analytics event with only the action and a coarse reason, and tell the
/// person with a snackbar. Returns the message so a sheet can show it inline.
String reportSplitsError(
  WidgetRef ref,
  BuildContext? context,
  SplitsAction action,
  Object error, [
  StackTrace? stack,
]) {
  final message = splitsFailureMessage(action, error);
  try {
    BugLog.instance.error(error, stack);
    ref
        .read(analyticsProvider)
        .track(
          AnalyticsEvent.splitActionFailed(
            action: action.key,
            reason: splitsFailureReason(error),
          ),
        );
  } catch (e) {
    debugPrint('splits error reporting failed: $e');
  }
  if (context != null && context.mounted) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
  return message;
}
