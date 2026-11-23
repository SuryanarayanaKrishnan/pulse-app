import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../env/env.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';

/// Realistic credit card face with issuer gradient, chip, last4 and network mark.
class CreditCardVisual extends StatelessWidget {
  const CreditCardVisual({super.key, required this.card, this.compact = false});
  final CreditCard card;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fg = Colors.white;
    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: card.gradient,
          ),
          boxShadow: [
            BoxShadow(
              color: card.gradient.last.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned(
                right: -60,
                top: -60,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Positioned(
                left: -40,
                bottom: -90,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.5],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(compact ? 14 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            card.issuer,
                            style: context.tt.titleSmall!.copyWith(
                              color: fg,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.contactless_rounded,
                          color: fg.withValues(alpha: 0.85),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _Chip(),
                    const SizedBox(height: 10),
                    Text(
                      card.owned
                          ? '••••  ••••  ••••  ${card.last4}'
                          : card.name,
                      style: PulseTheme.amount(
                        fg,
                        size: compact ? 14 : 17,
                        weight: FontWeight.w600,
                      ).copyWith(letterSpacing: 1.6),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            card.owned ? card.name : Env.appName,
                            style: context.tt.labelMedium!.copyWith(
                              color: fg.withValues(alpha: 0.8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _NetworkMark(card.network),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 28,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(6),
      gradient: const LinearGradient(
        colors: [Color(0xFFF5D98B), Color(0xFFC9A24B)],
      ),
    ),
    child: CustomPaint(painter: _ChipPainter()),
  );
}

class _ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(0, s.height / 2), Offset(s.width, s.height / 2), p);
    canvas.drawLine(Offset(s.width / 3, 0), Offset(s.width / 3, s.height), p);
    canvas.drawLine(
      Offset(s.width * 2 / 3, 0),
      Offset(s.width * 2 / 3, s.height),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Placeholder network logos drawn with shapes (no brand assets bundled).
class _NetworkMark extends StatelessWidget {
  const _NetworkMark(this.network);
  final CardNetwork network;

  @override
  Widget build(BuildContext context) {
    switch (network) {
      case CardNetwork.mastercard:
        return SizedBox(
          width: 40,
          height: 24,
          child: Stack(
            children: [
              Positioned(left: 0, child: _dot(const Color(0xCCEB001B))),
              Positioned(left: 16, child: _dot(const Color(0xCCF79E1B))),
            ],
          ),
        );
      case CardNetwork.visa:
        return Text(
          'VISA',
          style: context.tt.titleMedium!.copyWith(
            color: Colors.white,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        );
      case CardNetwork.amex:
        return Text(
          'AMEX',
          style: context.tt.titleSmall!.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        );
    }
  }

  Widget _dot(Color c) => Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(shape: BoxShape.circle, color: c),
  );
}
