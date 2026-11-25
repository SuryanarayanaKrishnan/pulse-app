# Plus entitlement (beta: mock billing)

Free: budgeting, card tracking, everyday card advice, default stacking combos (works with no cards).
Plus: niche card intel (items with `tier: plus` in `assets/catalog/combos.json`) and every LLM feature.

- `lib/core/entitlement/entitlement.dart`: `EntitlementService` is the only billing seam. The beta
  `MockEntitlementService` stores a flag in shared preferences. No payment, no SDK.
- Gate a feature with `ref.watch(canUseProvider(PlusFeature.aiSummaries))`, or `requirePlus(context, ref, feature, onAllowed)`
  to open the paywall when locked. Any LLM call must check this before it runs.
- Screens: `/plus` (paywall) and `/plus/billing` (mock checkout), Settings > Plan > Pulse Plus.
- Combos bundle comes from the backend: `python scripts/export_app_combos.py ../pulse-app/assets/catalog/combos.json`.

Real billing later: implement `EntitlementService` (store purchase + receipt check), override
`entitlementServiceProvider`, replace `MockBillingScreen` with the provider's sheet, and move `plus` item bodies to the
server so the bundle only ships free items (see pulse `docs/ENTITLEMENT.md`).
