import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/entitlement/entitlement.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../coach/coach.dart';

PlusFeature? _featureFrom(String? name) =>
    PlusFeature.values.where((f) => f.name == name).firstOrNull;

/// Paywall. Opened from any locked row or Settings. Shows what Plus adds and
/// leads to the (mock) billing screen.
class PlusPaywallScreen extends ConsumerStatefulWidget {
  const PlusPaywallScreen({super.key, this.feature});
  final String? feature;

  @override
  ConsumerState<PlusPaywallScreen> createState() => _PlusPaywallScreenState();
}

class _PlusPaywallScreenState extends ConsumerState<PlusPaywallScreen> {
  PlusOffer _offer = plusOffers.last;

  static const _perks = [
    (
      Icons.layers_outlined,
      'Niche card intel',
      'Rare stacking combos, time-bound caveats and offer changes, dated and sourced.',
    ),
    (
      Icons.auto_awesome_outlined,
      'AI summaries',
      'Plain-language explanations of your month. The only part that uses an AI model.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final e = ref.watch(entitlementProvider);
    final from = _featureFrom(widget.feature);
    return CoachHost(
      screen: CoachScreen.plus,
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.gutter,
          0,
          Space.gutter,
          Space.xxxl,
        ),
        children: [
          Text(
            'PULSE PLUS',
            style: context.tt.labelMedium!.copyWith(
              color: c.accent,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: Space.sm),
          Text(
            e.isPlus ? 'You have Plus' : 'The detail that saves you money',
            style: context.tt.headlineMedium,
          ),
          const SizedBox(height: Space.sm),
          Text(
            from == null
                ? 'Budgeting, card tracking and the everyday card advice stay free.'
                : '${from.label} is part of Plus. Budgeting, card tracking and everyday card advice stay free.',
            style: context.tt.bodyLarge!.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.xl),
          CoachTarget(
            id: 'perks',
            child: RowGroup(
            indent: ListRow.leadingInset,
            children: [
              for (final p in _perks)
                ListRow(
                  leading: IconWell(p.$1, color: c.calm),
                  title: p.$2,
                  subtitle: p.$3,
                ),
            ],
          )),
          if (!e.isPlus) ...[
            const SizedBox(height: Space.xl),
            for (final o in plusOffers) ...[
              _OfferTile(o, selected: o.id == _offer.id, onTap: () => setState(() => _offer = o)),
              const SizedBox(height: Space.sm),
            ],
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!e.isPlus)
                PrimaryButton(
                  label: 'Continue',
                  onPressed: () => context.push('/plus/billing?offer=${_offer.id}'),
                )
              else ...[
                PrimaryButton(label: 'Done', onPressed: () => context.pop()),
                const SizedBox(height: Space.sm),
                PrimaryButton(
                  label: 'Switch Plus off (test)',
                  secondary: true,
                  onPressed: () => ref.read(entitlementProvider.notifier).cancel(),
                ),
              ],
              const SizedBox(height: Space.sm),
              Text(
                'Friends and family beta: billing is a test. Nothing is charged.',
                textAlign: TextAlign.center,
                style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile(this.offer, {required this.selected, required this.onTap});
  final PlusOffer offer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Semantics(
      button: true,
      selected: selected,
      label: '${offer.title}, AED ${offer.priceAed} a ${offer.period}',
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.base,
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected ? c.accent : c.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? c.accent : c.textTertiary,
                size: 22,
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(offer.title, style: context.tt.titleMedium),
                    if (offer.note != null)
                      Text(
                        offer.note!,
                        style: context.tt.bodySmall!.copyWith(color: c.accent),
                      ),
                  ],
                ),
              ),
              Text(
                'AED ${offer.priceAed} / ${offer.period}',
                style: context.tt.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Step { review, processing, done }

/// Mock checkout. Collects nothing, charges nothing: confirming flips the
/// entitlement through [EntitlementService]. Real billing replaces the service,
/// and this screen becomes the provider's sheet.
class MockBillingScreen extends ConsumerStatefulWidget {
  const MockBillingScreen({super.key, this.offerId});
  final String? offerId;

  @override
  ConsumerState<MockBillingScreen> createState() => _MockBillingScreenState();
}

class _MockBillingScreenState extends ConsumerState<MockBillingScreen> {
  _Step _step = _Step.review;
  String? _error;

  PlusOffer get _offer => plusOffers.firstWhere(
    (o) => o.id == widget.offerId,
    orElse: () => plusOffers.last,
  );

  Future<void> _confirm() async {
    setState(() {
      _step = _Step.processing;
      _error = null;
    });
    try {
      await ref.read(entitlementProvider.notifier).purchase(_offer);
      if (mounted) setState(() => _step = _Step.done);
    } catch (e) {
      if (mounted)
        setState(() {
          _step = _Step.review;
          _error = 'That did not go through. Nothing was charged. Try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final o = _offer;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing'),
        automaticallyImplyLeading: false,
        leading: _step == _Step.review
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : Motion.base,
        child: _step == _Step.done
            ? _Done(key: const ValueKey('done'), offer: o)
            : ListView(
                key: const ValueKey('review'),
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.md,
                  Space.gutter,
                  Space.xxxl,
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.md,
                      vertical: Space.sm,
                    ),
                    decoration: BoxDecoration(
                      color: c.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.science_outlined,
                          size: 18,
                          color: c.warning,
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Text(
                            'Test mode. No card is used and nothing is charged.',
                            style: context.tt.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  Text('Order summary', style: context.tt.titleLarge),
                  const SizedBox(height: Space.sm),
                  RowGroup(
                    children: [
                      ListRow(
                        title: 'Pulse Plus, ${o.title.toLowerCase()}',
                        trailing: Text(
                          'AED ${o.priceAed}',
                          style: context.tt.bodyMedium,
                        ),
                      ),
                      ListRow(
                        title: 'Renews every ${o.period}',
                        trailing: Text(
                          'Cancel any time',
                          style: context.tt.bodySmall,
                        ),
                      ),
                      ListRow(
                        title: 'Due today',
                        titleStyle: context.tt.titleMedium,
                        trailing: Text(
                          'AED 0 (test)',
                          style: context.tt.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xl),
                  Text('Payment', style: context.tt.titleLarge),
                  const SizedBox(height: Space.sm),
                  RowGroup(
                    children: [
                      ListRow(
                        leading: IconWell(
                          Icons.credit_card_outlined,
                          color: c.textSecondary,
                        ),
                        title: 'Test payment method',
                        subtitle: 'Stands in for Apple Pay and Google Pay',
                        trailing: Icon(
                          Icons.check_circle_rounded,
                          color: c.accent,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: Space.md),
                    Text(
                      _error!,
                      style: context.tt.bodySmall!.copyWith(color: c.negative),
                    ),
                  ],
                  const SizedBox(height: Space.xl),
                  PrimaryButton(
                    label: 'Confirm test purchase',
                    loading: _step == _Step.processing,
                    onPressed: _step == _Step.processing ? null : _confirm,
                  ),
                ],
              ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({super.key, required this.offer});
  final PlusOffer offer;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.all(Space.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: c.accent, size: 36),
          ),
          const SizedBox(height: Space.xl),
          Text('Plus is on', style: context.tt.headlineMedium),
          const SizedBox(height: Space.sm),
          Text(
            'Niche card intel and AI summaries are unlocked. This was a test purchase.',
            textAlign: TextAlign.center,
            style: context.tt.bodyLarge!.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.xxl),
          PrimaryButton(
            label: 'Done',
            onPressed: () {
              context.pop(); // billing
              if (context.canPop()) context.pop(); // paywall
            },
          ),
        ],
      ),
    );
  }
}
