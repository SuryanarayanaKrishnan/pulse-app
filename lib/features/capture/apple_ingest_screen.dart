import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../capture/apple_shortcut.dart';
import '../../capture/providers.dart';
import '../../core/env/env.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';

/// Landing page of `pulse://ingest?amount=..&merchant=..&card=..`. The router
/// rewrites the custom-scheme link to this route; the payment is queued (so it
/// survives being offline) and uploaded to `/v1/ingest/apple-shortcut`.
class AppleIngestScreen extends ConsumerStatefulWidget {
  const AppleIngestScreen({super.key, required this.params});
  final Map<String, String> params;
  @override
  ConsumerState<AppleIngestScreen> createState() => _AppleIngestScreenState();
}

class _AppleIngestScreenState extends ConsumerState<AppleIngestScreen> {
  ShortcutTransaction? _tx;
  bool _done = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _tx = ShortcutTransaction.tryParse(
      Uri(
        scheme: Env.urlScheme,
        host: 'ingest',
        queryParameters: widget.params,
      ),
    );
    if (_tx == null) {
      _failed = true;
    } else {
      _submit(_tx!);
    }
  }

  Future<void> _submit(ShortcutTransaction tx) async {
    final queue = ref.read(ingestQueueProvider);
    await queue.enqueue(tx.toPending(DateTime.now()));
    await queue.flush();
    if (!mounted) return;
    setState(() => _done = true);
    // Shortcuts opens the app just to hand over data; go back to where the
    // user was after a moment.
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final tx = _tx;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Space.gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _failed
                      ? Icons.error_outline_rounded
                      : (_done
                            ? Icons.check_circle_rounded
                            : Icons.sync_rounded),
                  size: 56,
                  color: _failed ? c.negative : (_done ? c.positive : c.accent),
                ),
                const SizedBox(height: Space.lg),
                Text(
                  _failed
                      ? 'Could not read that payment'
                      : (_done ? 'Payment captured' : 'Saving payment...'),
                  style: context.tt.headlineMedium,
                ),
                if (tx != null) ...[
                  const SizedBox(height: Space.sm),
                  Text(
                    '${tx.merchant} · ${tx.currency == 'AED' ? Money.aed(tx.amountMinor / 100) : '${tx.currency} ${(tx.amountMinor / 100).toStringAsFixed(2)}'}',
                    style: context.tt.bodyLarge,
                  ),
                ],
                if (_failed) ...[
                  const SizedBox(height: Space.sm),
                  Text(
                    'The link had no valid amount. Check the Shortcut passes the Amount.',
                    style: context.tt.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Space.xl),
                  PrimaryButton(
                    label: 'Back to ${Env.appName}',
                    expand: false,
                    onPressed: () => context.go(Routes.home),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
