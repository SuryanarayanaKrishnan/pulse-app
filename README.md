# Pulse

Premium personal-finance app for the UAE (iOS + Android, Flutter): automated budgeting, card rewards optimisation, net-worth tracking and Splitwise-style splits. Friends and family beta.

> The product name lives in one constant: `Env.appName` in `lib/core/env/env.dart`. Change it there (and the platform display names in `android/` / `ios/`) to rename.

## Run

```bash
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=SUPABASE_URL=https://xyz.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=POSTHOG_API_KEY=phc_... \
  --dart-define=POSTHOG_HOST=https://eu.i.posthog.com
```

With no defines the app runs fully on mock data: sign-in accepts any 6-digit code, analytics print to the debug console.

| Define | Purpose | Default |
| --- | --- | --- |
| `API_BASE_URL` | Backend base URL for the dio client | `http://localhost:8080` |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Supabase auth (email OTP, JWT for API calls). Skipped if absent | none |
| `POSTHOG_API_KEY`, `POSTHOG_HOST` | Product analytics. No-op if key absent | none, EU host |
| `DEV_SKIP_ONBOARDING=true` | Jump straight to the tabs (dev/screenshots) | false |

Checks: `flutter analyze`, `flutter test`, smoke build `flutter build web --release`.

## Folder layout

```
lib/
  app.dart, main.dart
  core/
    env/        dart-define config, app name
    theme/      PulseColors ThemeExtension (dark + light), spacing/radius/elevation tokens, text theme
    router/     go_router config, bottom-nav shell
    network/    dio client + Supabase auth interceptor
    analytics/  typed events, Analytics interface, Console / PostHog / Noop, route observer
    utils/      Money (AED formatter)
    widgets/    GlassCard, AmountText, PrimaryButton, Pill, Skeleton, EmptyState, SheetScaffold,
                ProgressRing, CreditCardVisual, charts (Sparkline, DonutChart, TrendBars), SourceBadge
  data/         models, PulseRepository interface, MockPulseRepository, providers, split/card utils
  features/
    onboarding/ intro carousel + "connect your money"
    auth/       sign-in (email OTP / Apple / Google), session controller
    home/       net-worth hero, spend ring, upcoming dues, best-card tip, recents
    budgets/    Budget dashboard (tab 2)
    transactions/ Activity drill-down, detail sheet with category re-assign, manual entry (secondary)
    cards/      wallet pager, rewards summary, "which card should I use", catalog
    splits/     groups, balances, settle-up plan, add-expense sheet
    net_worth/  Wealth: assets/liabilities, allocation donut
    settings/
```

Bottom nav: Home, Budget, Cards, Splits, Wealth. Activity is a drill-down (Home "See all", Budget header, category cards).

## Automation first

Every transaction carries a source badge (Statement, SMS, Wallet, Apple Pay, Manual). Onboarding pushes the user to connect an automatic source before anything else, and the Budget tab shows an auto-captured vs manual indicator. Manual entry exists only as a small overflow action inside Activity and fires the `manual_transaction_added` analytics event so we can measure how often it is needed.

## Swapping in the real API

Implement `PulseRepository` (`lib/data/repository.dart`) with the dio client from `core/network/api_client.dart` and change `repositoryProvider` in `lib/data/providers.dart`. UI never touches the mock directly.

## Design system notes

- Dark-first. Tokens in `PulseColors` (`context.pc`): bg, surface, surfaceElevated, border, text tiers, accent, accentAlt, positive/negative/warning, glass, hero gradient. Spacing (`Space`), radii (`Radii`) and shadows (`Elevations`) are constants.
- Type: Manrope for UI and numerals, Inter for body (google_fonts). Amounts use tabular figures (`PulseTheme.amount`). `PulseTheme.useGoogleFonts = false` in tests.
- Money: `Money.aed`, `Money.aedCompact`; `AmountText` count-up animation.
- Motion: implicit animations everywhere, flutter_animate staggered entrances, Cupertino page transitions, press-scale on buttons/cards with haptics (`Haptics`).
- Note: this Flutter release deprecates `package:flutter/material.dart`; the project imports `material_ui` and `cupertino_ui` instead.

## Analytics

`Analytics` interface with `PostHogAnalytics` (posthog_flutter), `ConsoleAnalytics` (debug) and `NoopAnalytics`. Events are typed in `AnalyticsEvent`: `onboarding_started`, `onboarding_step_completed{step}`, `signup_completed`, `source_connected{type}`, `statement_uploaded`, `transaction_recategorized{from,to}`, `budget_created`, `card_added`, `card_recommendation_viewed{category}`, `split_expense_added`, `manual_transaction_added{category}`. Screen views come from `AnalyticsRouteObserver` on the GoRouter plus tab-switch reporting in the shell.

## Capturing transactions automatically (to implement)

### iOS: Apple Pay via Shortcuts

Apple exposes no API for Wallet transactions, but Shortcuts has a **Transaction** personal automation trigger (Shortcuts, Automation, New, Transaction, pick cards). The user installs a shared Shortcut that runs on every tap-to-pay with the inputs *Merchant*, *Amount*, *Card or Pass*, *Name*, and does one of:

1. **Get Contents of URL** (POST JSON) to `https://<API_BASE_URL>/v1/ingest/apple-shortcut` with a per-user ingest token in the header or body:
   `{ "merchant": "<Merchant>", "amount": "<Amount>", "card": "<Card or Pass>", "ts": "<Current Date>" }`
2. Or **Open URL** `pulse://ingest?merchant=...&amount=...&card=...` so the app posts it (requires registering the URL scheme in `Info.plist` and handling it via go_router deep links).

The backend normalises, de-duplicates against later statement lines, and tags `source = apple_pay_shortcut`. The connect step in onboarding should deep-link to the shared Shortcut and show a "send test transaction" verification.

### Android: SMS and notification listener

Plan with platform channels (Kotlin):
- `RECEIVE_SMS` broadcast receiver (or `READ_SMS` for backfill) filtered to known bank sender IDs (ENBD, ADCB, FAB, Mashreq, Liv, ...). Parse on device with per-bank templates, send only structured fields to `/v1/ingest/sms`.
- `NotificationListenerService` for wallet/bank-app notifications (Google Wallet, bank apps), same parser. Requires the user to grant "Notification access" in system settings; guide them from the connect screen.
- Dart side: `MethodChannel('pulse/ingest')` for permission state, `EventChannel` for captured events, queued and retried via the dio client. Play Store SMS-permission policy needs a declaration; plan for a sideloaded/beta distribution first.

## Status

Foundation only: all data is mocked, Supabase/PostHog/Apple/Google sign-in are wired structurally, platform capture channels are not implemented yet.
