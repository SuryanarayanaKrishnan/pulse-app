import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import 'moments.dart';
import 'tour_flow.dart';

typedef _MomentBuilder = Widget Function(double t);

class _Copy {
  const _Copy(this.headline, this.line, this.builder);
  final String headline;
  final String line;
  final _MomentBuilder builder;
}

final _moments = <_Copy>[
  _Copy(
    'Your number for today',
    'Bills, card dues and goals come off first, so what you see is safe to spend.',
    (t) => SafeToSpendMoment(t: t),
  ),
  _Copy(
    'Always the right card',
    'After you pay, a soft buzz tells you if another card would have earned more.',
    (t) => RightCardMoment(t: t),
  ),
  _Copy(
    'It fills itself in',
    'Bank texts, wallet taps and statements land in your ledger. Nothing to type.',
    (t) => AutoCaptureMoment(t: t),
  ),
  _Copy(
    'Everything adds up',
    'Cash, gold, funds and property, added up quietly into one number.',
    (t) => NetWorthMoment(t: t),
  ),
];

/// First-launch tour: four short moments. Tap anywhere (or swipe) to move on,
/// Skip leaves at any time. [onFinished] gets `true` if the user reached the
/// end and `false` if they skipped.
class TourScreen extends ConsumerStatefulWidget {
  const TourScreen({super.key, required this.onFinished});
  final void Function(bool completed) onFinished;

  @override
  ConsumerState<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends ConsumerState<TourScreen> {
  final _ctl = PageController();
  late final TourFlow _flow = TourFlow(ref.read(analyticsProvider));

  @override
  void initState() {
    super.initState();
    assert(_moments.length == TourFlow.steps.length);
    WidgetsBinding.instance.addPostFrameCallback((_) => _flow.start());
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _finish() {
    if (!_flow.finished) return;
    widget.onFinished(_flow.status == TourStatus.completed);
  }

  void _advance() {
    _flow.start();
    final last = _flow.isLast;
    if (last) {
      Haptics.medium();
      _flow.advance();
      _finish();
      return;
    }
    Haptics.tap();
    final next = _flow.index + 1;
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctl.jumpToPage(next);
    } else {
      _ctl.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _skip() {
    _flow.start();
    _flow.skip();
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final last = _flow.isLast;
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _advance,
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: TextAction(
                      'Skip',
                      color: c.textSecondary,
                      onTap: _skip,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _ctl,
                  itemCount: _moments.length,
                  onPageChanged: (i) => setState(() => _flow.goTo(i)),
                  itemBuilder: (_, i) {
                    final m = _moments[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: ExcludeSemantics(
                                child: LoopingMoment(
                                  builder: (_, t) => m.builder(t),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.xl),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Semantics(
                              header: true,
                              child: Text(
                                m.headline,
                                style: context.tt.displayMedium,
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.md),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              m.line,
                              style: context.tt.bodyLarge!.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: Space.xl),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _moments.length; i++)
                    AnimatedContainer(
                      duration: reduced ? Duration.zero : Motion.base,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _flow.index ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _flow.index ? c.textPrimary : c.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(Space.gutter),
                child: SizedBox(
                  height: 50,
                  child: AnimatedSwitcher(
                    duration: reduced ? Duration.zero : Motion.base,
                    child: last
                        ? PrimaryButton(
                            key: const ValueKey('go'),
                            label: 'Get started',
                            onPressed: _advance,
                          )
                        : Center(
                            key: const ValueKey('hint'),
                            child: Text(
                              'Tap anywhere to continue',
                              style: context.tt.bodySmall!.copyWith(
                                color: c.textTertiary,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
