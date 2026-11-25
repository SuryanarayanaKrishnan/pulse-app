import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the user is on. Two plans only; everything else derives from this.
enum Plan { free, plus }

/// Things behind Plus. Add a value here and gate with [PlusFeatureAccess].
enum PlusFeature {
  /// Niche card intel: rare combos, time-bound caveats, offer changes.
  nicheIntel('Niche card intel'),

  /// Every LLM-powered feature (summaries, explanations). Core budgeting and
  /// card advice run on rules and on-device logic and never need this.
  aiSummaries('AI summaries');

  const PlusFeature(this.label);
  final String label;
}

class PlusOffer {
  const PlusOffer(this.id, this.title, this.priceAed, this.period, {this.note});
  final String id;
  final String title;
  final int priceAed;
  final String period;
  final String? note;
}

/// Placeholder pricing for the friends-and-family beta. Nobody is charged.
const plusOffers = [
  PlusOffer('plus-monthly', 'Monthly', 19, 'month'),
  PlusOffer('plus-yearly', 'Yearly', 149, 'year', note: 'Two months free'),
];

class Entitlement {
  const Entitlement(this.plan, {this.offerId, this.since, this.mock = true});
  const Entitlement.free() : this(Plan.free);

  final Plan plan;
  final String? offerId;
  final DateTime? since;

  /// True while billing is the beta stand-in. Real billing returns false.
  final bool mock;

  bool get isPlus => plan == Plan.plus;
  bool allows(PlusFeature f) => isPlus;
}

/// The one seam between the app and billing. The beta uses
/// [MockEntitlementService]; real billing implements this interface (store
/// purchase, receipt check, restore) and is swapped in via
/// [entitlementServiceProvider]. Nothing else in the app talks to billing.
abstract class EntitlementService {
  Future<Entitlement> load();

  /// Completes a purchase of [offer]. Throws on failure or cancellation.
  Future<Entitlement> purchase(PlusOffer offer);

  /// Ends Plus (cancel or refund).
  Future<Entitlement> cancel();
}

/// Beta billing: no payment, no SDK. A purchase just stores a flag on the phone.
class MockEntitlementService implements EntitlementService {
  MockEntitlementService({this.delay = const Duration(milliseconds: 1400)});
  final Duration delay;

  static const _plan = 'entitlement_plan';
  static const _offer = 'entitlement_offer';
  static const _since = 'entitlement_since';

  @override
  Future<Entitlement> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getString(_plan) != Plan.plus.name) return const Entitlement.free();
      return Entitlement(
        Plan.plus,
        offerId: p.getString(_offer),
        since: DateTime.tryParse(p.getString(_since) ?? ''),
      );
    } catch (_) {
      return const Entitlement.free();
    }
  }

  @override
  Future<Entitlement> purchase(PlusOffer offer) async {
    await Future<void>.delayed(delay); // feels like a real checkout
    final now = DateTime.now();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_plan, Plan.plus.name);
      await p.setString(_offer, offer.id);
      await p.setString(_since, now.toIso8601String());
    } catch (_) {}
    return Entitlement(Plan.plus, offerId: offer.id, since: now);
  }

  @override
  Future<Entitlement> cancel() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_plan);
      await p.remove(_offer);
      await p.remove(_since);
    } catch (_) {}
    return const Entitlement.free();
  }
}

final entitlementServiceProvider = Provider<EntitlementService>(
  (ref) => MockEntitlementService(),
);

class EntitlementController extends Notifier<Entitlement> {
  @override
  Entitlement build() {
    _load();
    return const Entitlement.free();
  }

  Future<void> _load() async {
    final e = await ref.read(entitlementServiceProvider).load();
    if (ref.mounted) state = e;
  }

  Future<void> purchase(PlusOffer offer) async {
    state = await ref.read(entitlementServiceProvider).purchase(offer);
  }

  Future<void> cancel() async {
    state = await ref.read(entitlementServiceProvider).cancel();
  }
}

final entitlementProvider =
    NotifierProvider<EntitlementController, Entitlement>(
      EntitlementController.new,
    );

/// `ref.watch(canUseProvider(PlusFeature.aiSummaries))` gates a feature.
/// LLM calls must check this before they run, not only before they render.
final canUseProvider = Provider.family<bool, PlusFeature>(
  (ref, f) => ref.watch(entitlementProvider).allows(f),
);
