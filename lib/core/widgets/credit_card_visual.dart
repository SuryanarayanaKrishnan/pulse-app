import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../env/env.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';

/// Card face. The issuer colour stays (it is how people recognise a card);
/// shine, shadow and the fake chip are gone.
class CreditCardVisual extends StatelessWidget {
  const CreditCardVisual({super.key, required this.card, this.compact = false});
  final CreditCard card;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const fg = Colors.white;
    final pad = compact ? Space.sm : Space.lg + Space.xs;
    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            compact ? Radii.sm / 2 : Radii.md,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              card.gradient.first,
              card.gradient[card.gradient.length ~/ 2],
            ],
          ),
        ),
        child: compact
            ? const SizedBox.expand()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.issuer,
                    style: context.tt.titleSmall!.copyWith(color: fg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.owned ? card.name : Env.appName,
                              style: context.tt.bodySmall!.copyWith(
                                color: fg.withValues(alpha: 0.75),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              card.owned ? '•• ${card.last4}' : card.name,
                              style: PulseTheme.amount(fg, size: 15),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        switch (card.network) {
                          CardNetwork.visa => 'VISA',
                          CardNetwork.mastercard => 'mastercard',
                          CardNetwork.amex => 'AMEX',
                        },
                        style: context.tt.labelMedium!.copyWith(
                          color: fg.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
