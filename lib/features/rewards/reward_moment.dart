import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/card_util.dart';
import '../../data/local/ingest_pipeline.dart';
import '../../data/local/local_repository.dart';
import '../../data/providers.dart';
import '../../core/analytics/analytics.dart';
import '../cards/card_check_nudge.dart';
import '../cards/card_widgets.dart';

/// Refreshes the ledger after a capture and, when a card earned something,
/// shows the banner built from the real pipeline result.
Future<void> onCaptured(
  BuildContext context,
  WidgetRef ref,
  IngestOutcome outcome,
) async {
  final repo = ref.read(repositoryProvider);
  if (repo is! LocalPulseRepository) return;
  invalidateWallet(ref);
  final d = await repo.momentFor(outcome);
  if (d == null || !context.mounted) return;
  Haptics.success();
  showRewardBanner(
    context,
    RewardMoment(
      merchant: d.tx.merchant,
      amount: d.tx.amount,
      card: d.card,
      category: d.tx.category,
      earned: d.earned,
      rate: d.ratePct,
      cap: d.cap,
      nudge: d.nudge,
    ),
  );
  final check = d.check;
  if (check != null && context.mounted) {
    showCardCheckNudge(context, ref.read(analyticsProvider), check);
  }
}

/// Demo: runs a card tap through the capture pipeline. On-device this is a
/// synthetic message through the real pipeline (the banner follows from
/// [onCaptured]); with demo data it uses the mock capture.
Future<void> simulateCardTap(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(repositoryProvider);
  if (repo is LocalPulseRepository) {
    try {
      await repo.simulateCapture();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    return;
  }
  final before = await ref.read(myCardsProvider.future);
  final tx = await repo.simulateCapture();
  final card = before.where((c) => c.id == tx.cardId).firstOrNull;
  ref.invalidate(myCardsProvider);
  invalidateLedger(ref);
  if (card == null || !context.mounted) return;
  final moment = rewardMoment(
    cards: before,
    card: card,
    merchant: tx.merchant,
    category: tx.category,
    amount: tx.amount,
  );
  Haptics.success();
  showRewardBanner(context, moment);
}

OverlayEntry? _current;

/// A notification-style banner that drops in from the top. Tap it for the
/// full moment; swipe it up to dismiss. Leaves on its own after a while.
void showRewardBanner(BuildContext context, RewardMoment m) {
  _current?.remove();
  _current = null;
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _BannerHost(
      moment: m,
      onOpen: () => showPulseSheet<void>(
        context,
        builder: (_) => RewardMomentSheet(moment: m),
      ),
      onGone: () {
        if (_current == entry) _current = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

class _BannerHost extends StatefulWidget {
  const _BannerHost({
    required this.moment,
    required this.onOpen,
    required this.onGone,
  });
  final RewardMoment moment;
  final VoidCallback onOpen;
  final VoidCallback onGone;
  @override
  State<_BannerHost> createState() => _BannerHostState();
}

class _BannerHostState extends State<_BannerHost>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 220),
  )..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 8), _dismiss);
  }

  Future<void> _dismiss() async {
    _timer?.cancel();
    if (!mounted) return;
    await _c.reverse();
    widget.onGone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(
      parent: _c,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.sm, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, -1.4),
                  end: Offset.zero,
                ).animate(anim),
                child: GestureDetector(
                  onVerticalDragEnd: (d) {
                    if ((d.primaryVelocity ?? 0) < 0) _dismiss();
                  },
                  child: Pressable(
                    onTap: () {
                      _dismiss();
                      widget.onOpen();
                    },
                    child: RewardBanner(moment: widget.moment),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The banner itself, shaped like a system notification.
class RewardBanner extends StatelessWidget {
  const RewardBanner({super.key, required this.moment});
  final RewardMoment moment;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final m = moment;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.all(Space.md + 2),
        decoration: BoxDecoration(
          color: c.isDark ? c.surfaceElevated : c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: c.isDark ? 0.5 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.bolt_rounded, color: c.onAccent, size: 22),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${Money.aed(m.amount)} at ${m.merchant}',
                          style: context.tt.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('now', style: context.tt.labelSmall),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '+${Money.aed(m.earned)} on ${cardName(m.card)}${m.cap?.reached ?? false ? ' · cap reached' : ''}',
                    style: context.tt.bodySmall!.copyWith(color: c.textPrimary),
                  ),
                  if (m.nudge != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      m.nudge!,
                      style: context.tt.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The full moment: what was spent, what it earned, where the cap stands and
/// what to do next time.
class RewardMomentSheet extends StatelessWidget {
  const RewardMomentSheet({super.key, required this.moment});
  final RewardMoment moment;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final m = moment;
    final cap = m.cap;
    return SheetScaffold(
      title: m.merchant,
      subtitle:
          '${m.category.label} · ${cardName(m.card)} · ${DateFormat('h:mm a').format(DateTime.now())}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AmountText(
            m.amount,
            size: 40,
            weight: FontWeight.w700,
            decimals: true,
          ),
          const SizedBox(height: Space.xl),
          RowGroup(
            padding: EdgeInsets.zero,
            children: [
              ListRow(
                dense: true,
                title: 'Rewards earned',
                subtitle: '${formatRate(m.rate)} on this purchase',
                trailing: Text(
                  '+${Money.aed(m.earned)}',
                  style: PulseTheme.amount(c.positive),
                ),
              ),
            ],
          ),
          if (cap != null) ...[
            const SizedBox(height: Space.lg),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${m.category.label} cap this month',
                    style: context.tt.bodyMedium!.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${Money.aed(cap.used)} / ${Money.aed(cap.limit, decimals: false)}',
                  style: PulseTheme.amount(c.textPrimary, size: 15),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Meter(
              value: cap.progress,
              height: 6,
              color: cap.reached ? c.warning : c.forProgress(cap.progress),
            ),
            const SizedBox(height: 6),
            Text(
              cap.reached
                  ? 'Cap reached. This card earns ${formatRate(m.card.baseRate)} on ${m.category.label.toLowerCase()} until the 1st'
                  : '${Money.aed(cap.remaining)} of rewards left',
              style: context.tt.bodySmall!.copyWith(
                color: cap.reached ? c.warning : null,
              ),
            ),
          ],
          if (m.nudge != null) ...[
            const SizedBox(height: Space.xl),
            SurfaceCard(
              color: c.surfaceElevated,
              padding: const EdgeInsets.all(Space.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.swap_horiz_rounded, color: c.accent, size: 20),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Text(
                      m.nudge!,
                      style: context.tt.bodyMedium!.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Space.xl),
          PrimaryButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
