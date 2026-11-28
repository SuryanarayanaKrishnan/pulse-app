import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../capture/providers.dart';
import '../../core/network/cloud_access.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../capture/capture_setup_sheet.dart';
import '../statements/statement_actions.dart';

bool get _android => !kIsWeb && Platform.isAndroid;

/// One place for everything Pulse reads. Each connection is a switch in plain
/// words with a status line underneath.
class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final ready = ref.watch(cloudAccessProvider).isReady;
    final gmail = ref.watch(emailConnectionsProvider).value ?? const [];
    final conn = gmail.firstOrNull;
    final on = conn != null;
    final needsAgain = conn != null && !conn.active;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connections'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.popOrHome(Routes.settings),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.xxxl),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              Space.md,
              Space.gutter,
              0,
            ),
            child: _Intro(),
          ),
          const SectionHeader('Reading your money'),
          RowGroup(
            indent: ListRow.leadingInset,
            children: [
              ListRow(
                key: const Key('connection_gmail'),
                leading: const IconWell(Icons.mail_outline_rounded),
                title: 'Read statement emails',
                subtitle: !ready
                    ? needsSignInTitle
                    : needsAgain
                    ? 'Gmail · ${conn.email}. Sign in again to keep reading.'
                    : on
                    ? 'Gmail · ${conn.email}'
                    : 'Off',
                subtitleColor: needsAgain ? c.warning : null,
                trailing: Switch(
                  key: const Key('connection_gmail_switch'),
                  value: on && !needsAgain,
                  onChanged: (v) {
                    if (v) {
                      connectGmail(context, ref);
                    } else if (conn != null) {
                      disconnectGmail(context, ref, conn.id);
                    }
                  },
                ),
                onTap: needsAgain ? () => connectGmail(context, ref) : null,
              ),
              if (_android)
                ListRow(
                  key: const Key('connection_sms'),
                  leading: const IconWell(Icons.sms_outlined),
                  title: 'Read bank texts and wallet alerts',
                  subtitle: 'Permissions, status and what is read',
                  chevron: true,
                  onTap: () => showCaptureSetupSheet(context),
                )
              else
                ListRow(
                  key: const Key('connection_iphone'),
                  leading: const IconWell(Icons.apple),
                  title: 'Apple Pay and bank texts',
                  subtitle: ref
                      .watch(captureProgressProvider)
                      .maybeWhen(
                        data: (d) => d.length >= 4
                            ? 'All 4 working'
                            : '${d.length} of 4 working. Finish setup so payments are not missed.',
                        orElse: () => 'Shortcuts that send alerts to Pulse',
                      ),
                  subtitleColor:
                      (ref.watch(captureProgressProvider).value?.length ?? 4) <
                          4
                      ? c.warning
                      : null,
                  chevron: true,
                  onTap: () => context.push(Routes.applePaySetup),
                ),
              ListRow(
                key: const Key('settings_email_receipts'),
                leading: const IconWell(Icons.receipt_long_outlined),
                title: 'Email receipts',
                subtitle: ref.watch(receiptSourceProvider).isConfigured
                    ? 'Off. Adds item details from noon, Talabat and Careem receipts, matched on this phone.'
                    : 'Off. Adds item details from noon, Talabat and Careem receipts. Not available yet.',
                trailing: Switch(
                  key: const Key('settings_email_receipts_switch'),
                  value: false,
                  // Disabled until a Gmail sign-in is configured.
                  onChanged: ref.watch(receiptSourceProvider).isConfigured
                      ? (_) {}
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();
  @override
  Widget build(BuildContext context) => Text(
    'Turn a connection off and Pulse stops reading it. '
    'Nothing already saved is deleted.',
    style: context.tt.bodySmall,
  );
}
