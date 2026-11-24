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

With no `API_BASE_URL` the app runs fully on mock data: sign-in accepts any 6-digit code, analytics print to the debug console.

| Define | Purpose | Default |
| --- | --- | --- |
| `API_BASE_URL` | Backend base URL (without `/v1`). **Set: real API. Unset: mock data** | none (mock) |
| `APPLE_SHORTCUT_URL` | Shared iCloud link of the "Transaction" Shortcut (iOS guide) | placeholder |
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
    api/        ApiPulseRepository, DTOs, error mapping, ingest client
  capture/      offline ingest queue, capture service + Android bridge, Apple Shortcut link parsing
  features/
    capture/    Android permission sheet, Apple Pay setup guide, pulse:// ingest landing
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

## Backend (`ApiPulseRepository`)

`repositoryProvider` (`lib/data/providers.dart`) returns `ApiPulseRepository` when `API_BASE_URL` is defined and `MockPulseRepository` otherwise. Mock stays the demo default. UI code only sees `PulseRepository`.

```
lib/data/api/
  api_pulse_repository.dart  PulseRepository over dio (/v1 routes)
  dto.dart                   wire types + mapping to UI models, ingest request/response DTOs
  api_exception.dart         backend error envelope -> ApiException (isRetryable / isUnauthorized)
  ingest_api.dart            POST /v1/ingest/{sms,notification,apple-shortcut}
```

- Amounts are fils on the wire (`amount_minor`); DTO mappers convert to the UI's AED doubles. Transaction direction (`debit`/`credit`) becomes `isIncome`.
- Transactions use keyset cursors (`next_cursor`). `transactionsPage(cursor:, limit:)` exposes one page; `transactions()` follows cursors up to 3 pages of 200.
- Categories are matched to the UI's fixed `SpendCategory` set by name (`other` when unknown). Re-categorising PATCHes `category_id` with `remember_merchant`.
- The signed-in user's split member is exposed as `'me'` (the id the UI already uses).
- Auth: the existing Supabase JWT interceptor. Errors: `ApiException` carries `code`, `message`, `request_id` from the `{"error": {...}}` envelope.

Wired endpoints beyond the basics: `/v1/categories` (defaults + custom), `/v1/budgets`, `/v1/rules` (one-condition editor; "starts with" is sent as an escaped, anchored regex, "over/under" as inclusive `gte`/`lte` minor units, account names resolve to `account_id`), `/v1/contacts/match` (SHA-256 of E.164 numbers, chunks of 1000), split members by phone, Aani settlements (`POST settlements` with `method: aani`, then `/mark-paid`; the payee calls `/confirm`), `/v1/statements` (+ multipart upload, reconciliation, reprocess), `/v1/statement-passwords` (write-only upsert), `/v1/email-connections/gmail/start`, and `/v1/rewards/summary` (earned this cycle, cash caps and `verified_on` merged into `myCards()`; ignored while the route returns 404).

Derived on the client until the backend has them (each marked `TODO(api)`): cashflow, category trends, safe-to-spend and the health score (from transactions, budgets and cards), minimum due, net-worth history, the card catalog, and household/family endpoints (`household()` returns just you; invites and sharing throw `not_supported`). "Which card should I use?" ranks cards locally with cap-aware effective rates; `/v1/rewards/best-card` is the intended server source. `simulateCapture()` is mock-only and backs the Settings > Demo "Simulate a card tap" action.

## Cards tab (wallet)

Cards and Accounts share one pattern: a combined view (totals, then an overlapping `WalletStack` that fans out slightly on scroll), tap a card for a shared-element (`Hero`) transition into `WalletDetailPager`, swipe sideways between cards, pull down or tap the chevron to return. Reduced motion (`MediaQuery.disableAnimations`) removes the transition and parallax. "My cards ranked" (`/cards-ranked`) sorts by use, rewards or return net of a month of the annual fee (`cardStandings` in `lib/data/card_ranking.dart`), lists the best card per everyday category via `bestCard()` (`/v1/rewards/best-card` in API mode) and flags underused cards and fees the rewards do not cover.

## Design system notes

- Calm and quiet: warm neutrals, one teal accent, amber for caution, muted coral only for over-budget and errors, green for money in. Tokens in `PulseColors` (`context.pc`): bg, surface, surfaceElevated, border, text tiers, accent/onAccent, positive, negative, warning. `forProgress()` and `statusLabel()` give the on track / nearing limit / over colours and words. Spacing (`Space`), radii (`Radii`) and motion (`Motion`) are constants.
- Light and dark are both first class; Settings > Appearance picks System, Light or Dark (persisted).
- Type: Inter (system font on iOS), one scale (40/32/24/20/17/15/13/11), tabular figures everywhere (`PulseTheme.amount`). `PulseTheme.useGoogleFonts = false` in tests.
- Structure: grouped rows with hairlines (`RowGroup`, `ListRow`), one hero number per screen (`HeroNumber`), `SurfaceCard` only where an object is tappable, sheets via `showPulseSheet` + `SheetScaffold`.
- Charts (`inspect_charts.dart`): `GroupedBarChart` and `InspectLineChart` show the selected period's figures in a readout above the chart instead of floating tooltips; tap or drag to inspect.
- Motion: spring `Pressable` press feedback, animated numbers and meters, snap-scrolling rails, haptics in one place (`Haptics`).
- Note: this Flutter release deprecates `package:flutter/material.dart`; the project imports `material_ui` and `cupertino_ui` instead.

## Analytics

`Analytics` interface with `PostHogAnalytics` (posthog_flutter), `ConsoleAnalytics` (debug) and `NoopAnalytics`. Events are typed in `AnalyticsEvent`: `onboarding_started`, `onboarding_step_completed{step}`, `signup_completed`, `source_connected{type}`, `statement_uploaded`, `transaction_recategorized{from,to}`, `budget_created`, `card_added`, `card_recommendation_viewed{category}`, `split_expense_added`, `manual_transaction_added{category}`, `permission_granted{permission}`, `permission_denied{permission}`. Screen views come from `AnalyticsRouteObserver` on the GoRouter plus tab-switch reporting in the shell.

## Capturing transactions automatically

Everything funnels into one persistent **offline queue** (`lib/capture/ingest_queue.dart`, backed by shared_preferences): items are deduplicated by a client `external_id`, uploaded in order, retried with exponential backoff (30s up to 1h, dropped after 10 attempts or 14 days), kept on 401 and dropped on 4xx validation errors. It flushes when something is captured, when the app resumes, and every 10 minutes while open. With no `API_BASE_URL` the queue drains into a debug print.

### Android: SMS and wallet notifications

Kotlin under `android/app/src/main/kotlin/com/pulse/pulse/capture/`:

| File | Role |
| --- | --- |
| `SmsReceiver` | `RECEIVE_SMS` broadcast receiver for live bank SMS |
| `SmsBackfill` | one-time inbox read (`READ_SMS`), last 90 days |
| `PulseNotificationListener` | `NotificationListenerService` for wallet and bank-app notifications |
| `CaptureConfig` | sender-ID / package filters (persisted, pushed from Dart) |
| `CaptureStore` | durable native buffer between receivers and Dart |
| `CapturePlugin` | `MethodChannel('pulse/ingest')` + `EventChannel('pulse/ingest/events')` |

Flow: receiver filters, writes to the native buffer, pings Dart; Dart `peekPending` -> persists to its queue -> `ackPending` -> upload to `/v1/ingest/sms` or `/v1/ingest/notification`. This is at-least-once and works when the app process was dead; the backend dedupes on `external_id` (hash of sender/app + text + minute, identical for live and backfill).

- **Sender IDs** (`CaptureConfig.defaultBankSenderIds`): EmiratesNBD, ENBD, ADCBAlert, ADCB, FAB, Mashreq, RAKBANK, DIB, ADIB, HSBC, CBD, EIB, Liv, and more. IDs of 4 characters or fewer must match exactly (or as a `-` separated part, e.g. `AD-FAB`); longer ones match as substrings. Edit the list in Dart; it is pushed to the native layer on start.
- **Notification packages**: Google Wallet `com.google.android.apps.walletnfcrel`, Google Pay `com.google.android.apps.nbu.paisa.user`, Samsung `com.samsung.android.spay` and `com.samsung.android.samsungpay.gear`, plus bank apps via `bankAppPackages` (exact) and `bankPackageHints` (package-name substrings). Verify real bank package IDs before release; the exact list is empty by default.
- **Privacy**: non-bank SMS and other apps' notifications are dropped before being stored. Messages containing OTP / verification-code wording are never captured. Raw text is sent to the backend, which parses it (the earlier plan to parse on device is not implemented).
- **Permissions UI**: the connect step (Android tiles "Bank SMS" and "Wallet notifications") and Settings open a sheet explaining each permission, showing live status, requesting SMS permissions in-app, and deep-linking to the system notification-access screen (detail page on Android 11+). On return, the result is re-read. Apps installed outside Google Play on Android 13+ may need "Allow restricted settings" in App info; the sheet says so.
- Analytics: `permission_granted{permission}` / `permission_denied{permission}` with `permission` = `sms_receive`, `sms_read`, `notification_access`.
- Play Store: `RECEIVE_SMS`/`READ_SMS` need a Play Console declaration. Plan for sideloaded/beta distribution first.
- No Android SDK is available in this environment, so the Kotlin has not been compiled; run `flutter build apk --debug` before relying on it.

### iOS: Apple Pay via Shortcuts

Apple exposes no Wallet API. `ApplePaySetupScreen` (`/apple-pay-setup`, reachable from the connect step and Settings) walks the user through the Shortcuts **Transaction** automation:

1. Button opens the shared Shortcut (`Env.appleShortcutUrl`, override with `--dart-define=APPLE_SHORTCUT_URL=...`; currently a placeholder, so the button shows a message until set).
2. Automation: Shortcuts, Automation, New, Transaction, Run Immediately.
3. The Shortcut runs **Open URL** `pulse://ingest?amount=[Amount]&merchant=[Merchant]&card=[Card or Pass]` (optional `currency`, `ts`, `direction`). The scheme is registered in `ios/Runner/Info.plist`; go_router rewrites it to `/apple-ingest`, which parses it (`ShortcutTransaction`, tolerant of `AED 1,234.50` style amounts), queues it and posts structured `fields` to `/v1/ingest/apple-shortcut`.
4. A per-install ingest token is shown with copy/reveal for Shortcuts that upload directly. **The backend has no ingest-token endpoint yet** (ingest authenticates with the Supabase JWT), so this token is generated locally and not accepted server-side; the Open-URL flow does not need it.

There is no "send test transaction" button yet; it would create a real transaction server-side.

## Status

- Done: API repository (selected by `API_BASE_URL`), cursor pagination, DTO mapping, offline ingest queue, Android SMS/notification capture and permission UI, iOS Shortcut guide and `pulse://` deep link.
- Mock data remains the default and powers the UI demo.
- Not done: statement upload/passwords/Gmail connect (backend routes missing), server-side ingest tokens, card catalog and rewards data, net-worth history, on-device compilation check of the Kotlin code.

Checks: `flutter analyze`, `flutter test`.
