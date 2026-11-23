import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../env/env.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import '../utils/money.dart';

/// A card face that reads as a physical card: issuer colour kept but muted,
/// a faint sheen, a hairline edge, a chip outline and the network mark.
class WalletCardFace extends StatelessWidget {
  const WalletCardFace({
    super.key,
    required this.gradient,
    required this.title,
    this.subtitle,
    this.number,
    this.mark,
    this.figure,
    this.compact = false,
    this.elevated = false,
    this.chip = true,
  });
  final List<Color> gradient;
  final String title;
  final String? subtitle;
  final String? number;

  /// Network or account kind, bottom right.
  final String? mark;

  /// A large figure in the middle (an account balance).
  final String? figure;
  final bool compact;
  final bool elevated;
  final bool chip;

  @override
  Widget build(BuildContext context) {
    const fg = Colors.white;
    final pad = compact ? Space.sm : Space.lg + Space.xs;
    final radius = BorderRadius.circular(compact ? Radii.sm / 2 : Radii.md + 2);
    final a = gradient.first;
    final b = gradient.length > 1 ? gradient[1] : gradient.first;
    return AspectRatio(
      aspectRatio: 1.586,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: elevated
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [a, b],
                  ),
                ),
              ),
              // Sheen: light falling across the top-left of the card.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: const Alignment(0.4, 0.2),
                    colors: [
                      Colors.white.withValues(alpha: 0.10),
                      Colors.white.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.09),
                    width: 0.8,
                  ),
                ),
              ),
              if (!compact)
                Padding(
                  padding: EdgeInsets.all(pad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: context.tt.titleSmall!.copyWith(color: fg),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.contactless_outlined,
                            size: 18,
                            color: fg.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                      const SizedBox(height: Space.md),
                      if (chip)
                        Container(
                          width: 34,
                          height: 26,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.30),
                                Colors.white.withValues(alpha: 0.14),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.6,
                            ),
                          ),
                        ),
                      if (figure != null)
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            figure!,
                            style: PulseTheme.amount(
                              fg,
                              size: 24,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (subtitle != null)
                                  Text(
                                    subtitle!,
                                    style: context.tt.bodySmall!.copyWith(
                                      color: fg.withValues(alpha: 0.72),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (number != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    number!,
                                    style: PulseTheme.amount(fg, size: 15),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (mark != null)
                            Text(
                              mark!,
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
            ],
          ),
        ),
      ),
    );
  }
}

class CreditCardVisual extends StatelessWidget {
  const CreditCardVisual({
    super.key,
    required this.card,
    this.compact = false,
    this.elevated = false,
  });
  final CreditCard card;
  final bool compact;
  final bool elevated;

  @override
  Widget build(BuildContext context) => WalletCardFace(
    gradient: card.gradient.length > 2
        ? [card.gradient.first, card.gradient[card.gradient.length ~/ 2]]
        : card.gradient,
    title: card.issuer,
    subtitle: card.owned ? card.name : Env.appName,
    number: card.owned ? '•• ${card.last4}' : card.name,
    mark: switch (card.network) {
      CardNetwork.visa => 'VISA',
      CardNetwork.mastercard => 'mastercard',
      CardNetwork.amex => 'AMEX',
    },
    compact: compact,
    elevated: elevated,
  );
}

class AccountCardVisual extends StatelessWidget {
  const AccountCardVisual({
    super.key,
    required this.account,
    this.compact = false,
    this.elevated = false,
    this.showBalance = true,
  });
  final BankAccount account;
  final bool compact;
  final bool elevated;
  final bool showBalance;

  @override
  Widget build(BuildContext context) => WalletCardFace(
    gradient: account.gradient,
    title: account.bank,
    subtitle: account.name,
    number: account.last4 == null ? null : '•• ${account.last4}',
    mark: account.kind.label.toUpperCase(),
    chip: false,
    figure: showBalance ? Money.aed(account.balance, decimals: false) : null,
    compact: compact,
    elevated: elevated,
  );
}
