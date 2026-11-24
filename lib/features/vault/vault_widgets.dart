import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/vault/input_guard.dart';
import '../../core/vault/vault_models.dart';

IconData vaultIcon(VaultType t) => switch (t) {
  VaultType.bank => Icons.account_balance_outlined,
  VaultType.card => Icons.credit_card_outlined,
  VaultType.loan => Icons.request_quote_outlined,
  VaultType.insurance => Icons.health_and_safety_outlined,
  VaultType.investment => Icons.pie_chart_outline_rounded,
  VaultType.property => Icons.home_work_outlined,
  VaultType.crypto => Icons.currency_bitcoin_rounded,
  VaultType.subscription => Icons.autorenew_rounded,
  VaultType.digital => Icons.alternate_email_rounded,
  VaultType.documents => Icons.folder_open_outlined,
  VaultType.identity => Icons.badge_outlined,
};

void vaultToast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// The calm message under a form when free text looks like a secret.
class GuardNote extends StatelessWidget {
  const GuardNote(this.issues, {super.key});
  final List<GuardIssue> issues;

  @override
  Widget build(BuildContext context) {
    if (issues.isEmpty) return const SizedBox.shrink();
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final i in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    i.blocking
                        ? Icons.lock_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 16,
                    color: i.blocking ? c.negative : c.warning,
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      i.message,
                      key: const Key('vault_guard_note'),
                      style: context.tt.bodySmall!.copyWith(
                        color: i.blocking ? c.negative : c.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Copy a share or code to the clipboard, with a quiet confirmation.
Future<void> copyText(BuildContext context, String text, String what) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) vaultToast(context, '$what copied');
}
