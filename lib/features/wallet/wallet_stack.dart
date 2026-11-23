import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

/// Wallet-style stack: each card shows its top edge, the last one shows in
/// full. Cards fan out a little as the page scrolls (off with reduced
/// motion). Tap a card to open it.
class WalletStack extends StatefulWidget {
  const WalletStack({
    super.key,
    required this.count,
    required this.faceBuilder,
    required this.heroTag,
    required this.onTap,
    required this.semanticLabel,
    this.peek = 58,
  });
  final int count;
  final Widget Function(BuildContext, int) faceBuilder;
  final Object Function(int) heroTag;
  final void Function(int) onTap;
  final String Function(int) semanticLabel;
  final double peek;

  @override
  State<WalletStack> createState() => _WalletStackState();
}

class _WalletStackState extends State<WalletStack> {
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = Scrollable.maybeOf(context)?.position;
    if (p != _position) {
      _position?.removeListener(_onScroll);
      _position = p?..addListener(_onScroll);
    }
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final scroll = _position?.hasPixels ?? false ? _position!.pixels : 0.0;
    // Fans out by up to 10pt per gap as the stack scrolls toward the top.
    final spread = reduce ? 0.0 : (scroll / 30).clamp(-6.0, 10.0);
    final gap = widget.peek + spread;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth - Space.gutter * 2;
        final cardH = width / 1.586;
        final n = widget.count;
        return SizedBox(
          height: cardH + (n - 1) * gap,
          child: Stack(
            children: [
              for (var i = 0; i < n; i++)
                Positioned(
                  left: Space.gutter,
                  right: Space.gutter,
                  top: i * gap,
                  child: Semantics(
                    button: true,
                    label: widget.semanticLabel(i),
                    child: Pressable(
                      onTap: () {
                        Haptics.tap();
                        widget.onTap(i);
                      },
                      child: Hero(
                        tag: widget.heroTag(i),
                        child: widget.faceBuilder(context, i),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
