import 'dart:async';

import '../../core/learning/learning_controller.dart';
import '../../data/learning_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/analytics/analytics.dart';
import '../../core/engine/review.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../categories/category_picker.dart';
import '../transactions/recategorise_sheet.dart';
import '../transactions/tx_detail_sheet.dart';
import 'review_state.dart';

enum _Dir { right, left }

class _Done {
  const _Done(this.tx, this.dir);
  final Transaction tx;
  final _Dir dir;
}

/// One payment at a time. Swipe right when it looks right, left to fix it.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> with SingleTickerProviderStateMixin {
  /// Top card first. Null while loading.
  List<Transaction>? _stack;
  final _history = <_Done>[];

  late final AnimationController _anim = AnimationController(vsync: this);
  double _dx = 0;
  double _from = 0;
  double _to = 0;
  bool _busy = false;
  bool _crossed = false;

  static const _threshold = 96.0;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      setState(() => _dx = _from + (_to - _from) * Motion.curve.transform(_anim.value));
    });
    _load();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final q = await ref.read(reviewQueueProvider.future);
    if (!mounted) return;
    setState(() => _stack = List.of(q));
    if (q.isEmpty) _zero(quiet: true);
  }

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  Future<void> _move(double to, {Duration? duration}) async {
    final d = _reduced ? Duration.zero : (duration ?? Motion.base);
    _from = _dx;
    _to = to;
    if (d == Duration.zero) {
      setState(() => _dx = to);
      return;
    }
    _anim.duration = d;
    await _anim.forward(from: 0);
  }

  // ---- gestures --------------------------------------------------------------

  void _onDrag(DragUpdateDetails d) {
    if (_busy) return;
    setState(() => _dx += d.delta.dx);
    final over = _dx.abs() > _threshold;
    if (over && !_crossed) Haptics.tap();
    _crossed = over;
  }

  void _onDragEnd(DragEndDetails d) {
    if (_busy) return;
    final v = d.primaryVelocity ?? 0;
    final go = _dx.abs() > _threshold || v.abs() > 900;
    _crossed = false;
    if (!go) {
      _move(0, duration: Motion.fast);
      return;
    }
    final right = _dx != 0 ? _dx > 0 : v > 0;
    right ? swipeRight() : swipeLeft();
  }

  // ---- actions -----------------------------------------------------------------

  Future<void> swipeRight() async {
    final stack = _stack;
    if (_busy || stack == null || stack.isEmpty) return;
    _busy = true;
    final tx = stack.first;
    Haptics.light();
    await _move(_width * 1.2);
    await ref.read(repositoryProvider).setReviewed([tx.id], true);
    unawaited(recordConfirmedCategory(ref.read(learningControllerProvider), tx, tx.category));
    unawaited(rememberCategoryChoice(ref.read(merchantMemoryProvider), tx, tx.category));
    ref.read(analyticsProvider).track(AnalyticsEvent.reviewSwiped('right'));
    _finish(tx, _Dir.right);
  }

  Future<void> swipeLeft() async {
    final stack = _stack;
    if (_busy || stack == null || stack.isEmpty) return;
    _busy = true;
    final tx = stack.first;
    // The card settles back while the choice is made, so nothing is lost if
    // it is dismissed.
    await _move(0, duration: Motion.fast);
    final fixed = await _fix(tx);
    if (!mounted) return;
    if (!fixed) {
      _busy = false;
      return;
    }
    await ref.read(repositoryProvider).setReviewed([tx.id], true);
    ref.read(analyticsProvider).track(AnalyticsEvent.reviewSwiped('left'));
    Haptics.light();
    await _move(-_width * 1.2);
    _finish(tx, _Dir.left);
  }

  /// The existing category picker, then the scope sheet. False when the
  /// choice was dismissed or nothing changed.
  Future<bool> _fix(Transaction tx) async {
    final picked = await pickCategory(context, selected: tx.category, title: 'Fix category');
    if (picked == null || picked == tx.category || !mounted) return false;
    if (await recategoriseWithScope(context, ref, tx: tx, to: picked)) return true;
    final analytics = ref.read(analyticsProvider);
    await ref.read(repositoryProvider).recategorise(tx.id, picked);
    unawaited(recordConfirmedCategory(ref.read(learningControllerProvider), tx, picked));
    unawaited(rememberCategoryChoice(ref.read(merchantMemoryProvider), tx, picked, fix: true));
    analytics.track(
      AnalyticsEvent.transactionRecategorized(from: tx.category.name, to: picked.name),
    );
    return true;
  }

  void _finish(Transaction tx, _Dir dir) {
    if (!mounted) return;
    setState(() {
      _stack!.removeWhere((t) => t.id == tx.id);
      _history.add(_Done(tx, dir));
      _dx = 0;
      _busy = false;
      _crossed = false;
    });
    invalidateLedger(ref);
    if (_stack!.isEmpty) _zero();
  }

  Future<void> _zero({bool quiet = false}) async {
    if (!quiet) {
      ref.read(analyticsProvider).track(AnalyticsEvent.reviewInboxZero);
      Haptics.success();
    }
    await ref.read(reviewDaysProvider.notifier).markToday();
  }

  Future<void> undo() async {
    if (_busy || _history.isEmpty) return;
    _busy = true;
    final last = _history.removeLast();
    Haptics.tap();
    final repo = ref.read(repositoryProvider);
    await repo.setReviewed([last.tx.id], false);
    // Fresh copy: a fix changed its category.
    final all = await repo.transactions();
    final fresh = all.where((t) => t.id == last.tx.id).firstOrNull ?? last.tx;
    if (!mounted) return;
    setState(() {
      _stack!.insert(0, fresh.copyWith(reviewed: false));
      _dx = 0;
      _busy = false;
    });
    invalidateLedger(ref);
  }

  Future<void> _details() async {
    final stack = _stack;
    if (_busy || stack == null || stack.isEmpty) return;
    final tx = stack.first;
    await showPulseSheet<void>(context, full: true, builder: (_) => TxDetailSheet(tx: tx));
    if (!mounted) return;
    // The sheet may have changed it; show what is true now.
    final all = await ref.read(repositoryProvider).transactions();
    final fresh = all.where((t) => t.id == tx.id).firstOrNull;
    if (!mounted || fresh == null) return;
    setState(() {
      final i = _stack!.indexWhere((t) => t.id == tx.id);
      if (i < 0) return;
      // Changing the category in the sheet counts as having looked at it.
      fresh.reviewed ? _stack!.removeAt(i) : _stack![i] = fresh;
    });
    invalidateLedger(ref);
    if (_stack!.isEmpty) _zero();
  }

  double get _width => MediaQuery.sizeOf(context).width;

  // ---- build ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final stack = _stack;
    final streak = ref.watch(reviewStreakProvider);
    final cards = ref.watch(myCardsProvider).value ?? const <CreditCard>[];
    final empty = stack != null && stack.isEmpty;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              left: stack?.length,
              canUndo: _history.isNotEmpty && !_busy,
              onClose: () => Navigator.of(context).maybePop(),
              onUndo: undo,
            ),
            Expanded(
              child: stack == null
                  ? const SizedBox.shrink()
                  : empty
                  ? _InboxZero(streak: streak, onDone: () => Navigator.of(context).maybePop())
                  : _Stack(
                      stack: stack,
                      dx: _dx,
                      threshold: _threshold,
                      cards: cards,
                      onDrag: _onDrag,
                      onDragEnd: _onDragEnd,
                      onTap: _details,
                    ),
            ),
            if (!empty && stack != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, Space.xl),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: 'Fix it',
                            secondary: true,
                            icon: Icons.arrow_back_rounded,
                            onPressed: swipeLeft,
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Looks right',
                            icon: Icons.check_rounded,
                            onPressed: swipeRight,
                          ),
                        ),
                      ],
                    ),
                    if (streakLabel(streak) != null) ...[
                      const SizedBox(height: Space.md),
                      Text(streakLabel(streak)!, style: context.tt.bodySmall),
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

class _Header extends StatelessWidget {
  const _Header({required this.left, required this.canUndo, required this.onClose, required this.onUndo});
  final int? left;
  final bool canUndo;
  final VoidCallback onClose;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.gutter, 0),
      child: Row(
        children: [
          RoundIconButton(icon: Icons.close_rounded, label: 'Close', onTap: onClose),
          Expanded(
            child: Column(
              children: [
                Text('Review', style: context.tt.titleMedium),
                if (left != null && left! > 0) Text('$left left', style: context.tt.bodySmall),
              ],
            ),
          ),
          SizedBox(
            width: 56,
            child: AnimatedOpacity(
              duration: Motion.fast,
              opacity: canUndo ? 1 : 0,
              child: IgnorePointer(
                ignoring: !canUndo,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextAction('Undo', color: c.accent, onTap: onUndo),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The card on top, with the next two resting behind it.
class _Stack extends StatelessWidget {
  const _Stack({
    required this.stack,
    required this.dx,
    required this.threshold,
    required this.cards,
    required this.onDrag,
    required this.onDragEnd,
    required this.onTap,
  });
  final List<Transaction> stack;
  final double dx;
  final double threshold;
  final List<CreditCard> cards;
  final GestureDragUpdateCallback onDrag;
  final GestureDragEndCallback onDragEnd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final progress = (dx.abs() / threshold).clamp(0.0, 1.0);
    final right = dx > 0;
    final tx = stack.first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: Space.lg),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          for (var i = (stack.length > 3 ? 2 : stack.length - 1); i >= 1; i--)
            Positioned.fill(
              top: 12.0 * i - (progress * 12 * (i == 1 ? 1 : 0)),
              left: 10.0 * i - (progress * 10 * (i == 1 ? 1 : 0)),
              right: 10.0 * i - (progress * 10 * (i == 1 ? 1 : 0)),
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.isDark ? c.surfaceElevated : c.surface,
                  borderRadius: BorderRadius.circular(Radii.lg + 4),
                  border: Border.all(color: c.border),
                ),
              ),
            ),
          Positioned.fill(
            bottom: 12,
            child: GestureDetector(
              key: const ValueKey('review-card'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: onDrag,
              onHorizontalDragEnd: onDragEnd,
              onTap: onTap,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.rotate(
                  angle: reduced ? 0 : dx / 2400,
                  child: Stack(
                    children: [
                      Positioned.fill(child: _CardFace(tx: tx, cards: cards)),
                      if (dx != 0)
                        Positioned(
                          top: Space.lg,
                          left: right ? Space.lg : null,
                          right: right ? null : Space.lg,
                          child: Opacity(opacity: progress, child: _Hint(right: right)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Looks right" or "Fix it", fading in as the card moves.
class _Hint extends StatelessWidget {
  const _Hint({required this.right});
  final bool right;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final color = right ? c.accent : c.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(right ? Icons.check_rounded : Icons.edit_outlined, size: 18, color: color),
        const SizedBox(width: Space.xs),
        Text(right ? 'Looks right' : 'Fix it', style: context.tt.labelMedium!.copyWith(color: color)),
      ],
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.tx, required this.cards});
  final Transaction tx;
  final List<CreditCard> cards;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final note = rewardsNote(tx, cards);
    return Semantics(
      label: '${tx.merchant}, ${tx.category.label}. Swipe right if it looks right, left to fix it.',
      child: Container(
        padding: const EdgeInsets.all(Space.xl),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg + 4),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: Space.xl),
            CategoryIcon.well(tx.category, size: 48),
            const SizedBox(height: Space.xl),
            Text(
              tx.merchant,
              style: context.tt.headlineMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Space.xs),
            Text(DateFormat('EEEE d MMMM, HH:mm').format(tx.date), style: context.tt.bodyMedium),
            const SizedBox(height: Space.lg),
            AmountText(
              tx.signed,
              size: 44,
              weight: FontWeight.w700,
              decimals: true,
              signed: tx.isIncome,
              color: tx.isIncome ? c.positive : null,
              animate: false,
            ),
            const SizedBox(height: Space.lg),
            Pill(tx.category.label, leading: CategoryIcon(tx.category, size: 18)),
            const Spacer(),
            _Line(icon: Icons.credit_card_rounded, text: tx.accountLabel),
            if (note != null) _Line(icon: Icons.stars_rounded, text: note),
            _Line(
              icon: tx.source.icon,
              text: tx.source.automatic ? 'Captured via ${tx.source.label}' : 'Added by you',
            ),
            if (tx.confidence < 0.5)
              _Line(icon: Icons.help_outline_rounded, text: 'Pulse is not sure about this category'),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: context.pc.textTertiary),
        const SizedBox(width: Space.sm),
        Expanded(child: Text(text, style: context.tt.bodyMedium)),
      ],
    ),
  );
}

/// Nothing left. Quiet on purpose: no confetti, no score.
class _InboxZero extends StatelessWidget {
  const _InboxZero({required this.streak, required this.onDone});
  final int streak;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final label = streakLabel(streak);
    return Center(
      child: SingleChildScrollView(
        child: EmptyState(
          icon: Icons.check_circle_outline_rounded,
          title: 'Inbox zero',
          message: label == null
              ? 'Everything has been looked at.'
              : 'Everything has been looked at.\n$label.',
          action: PrimaryButton(label: 'Done', secondary: true, expand: false, onPressed: onDone),
        ),
      ),
    );
  }
}
