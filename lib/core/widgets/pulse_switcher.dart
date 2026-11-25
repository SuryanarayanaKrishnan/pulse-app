import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// Cross-fade between two blocks of content of different heights without the
/// two ever showing at once.
///
/// A plain [AnimatedSwitcher] stacks the outgoing and incoming child centred
/// on each other. For tall, different-height content in a list (a wallet's
/// cards vs. accounts, a re-sorted list) that paints two screens' worth of
/// text on top of each other for the length of the animation. Here the
/// outgoing child fades out in the first half, the incoming child fades in
/// in the second half, and both are pinned to the top.
class PulseSwitcher extends StatelessWidget {
  const PulseSwitcher({super.key, required this.child, this.duration});

  /// Needs a distinct key per state, as with [AnimatedSwitcher].
  final Widget child;

  /// Defaults to [Motion.base], and none when animations are disabled.
  final Duration? duration;

  static Widget _layout(Widget? current, List<Widget> previous) => Stack(
    alignment: Alignment.topCenter,
    children: [
      for (final p in previous) Positioned(top: 0, left: 0, right: 0, child: p),
      ?current,
    ],
  );

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration:
        duration ??
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false
            ? Duration.zero
            : Motion.base),
    switchInCurve: const Interval(0.5, 1),
    switchOutCurve: const Interval(0.5, 1),
    layoutBuilder: _layout,
    child: child,
  );
}
