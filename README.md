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

The app is **on-device first**: with no defines at all it runs on its own encrypted database, no backend needed. `API_BASE_URL` only switches on the shared features (see Architecture). Sign-in accepts any 6-digit code while `SUPABASE_*` is unset; analytics print to the debug console.

| Define | Purpose | Default |
| --- | --- | --- |
| `DEMO_DATA=true` | Use the built-in demo data instead of the on-device ledger (screenshots, demos). Tests and previews without a database do the same | false |
| `API_BASE_URL` | Backend base URL (without `/v1`). Optional: only serves shared features (auth, splits, family, statements, catalog refresh) | none |
| `APPLE_SHORTCUT_URL` | Shared iCloud link of the "Transaction" Shortcut (iOS guide) | placeholder |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Supabase auth (email OTP, JWT for API calls). Skipped if absent | none |
| `POSTHOG_API_KEY`, `POSTHOG_HOST` | Product analytics. No-op if key absent | none, EU host |
| `DEV_AUTH=true` | Local debug builds only: get a backend token from `/v1/dev/token` (docs/LOCAL_DEV.md) | false |
| `DEV_SKIP_ONBOARDING=true` | Jump straight to the tabs (dev/screenshots) | false |

Checks: `flutter analyze`, `flutter test`, smoke build `flutter build web --release --no-web-resources-cdn --dart-define=DEMO_DATA=true` (the web build only runs demo data: `lib/data/local/open.dart` swaps in a stub for the native encrypted database). Screenshots: serve `build/web` and drive it with Playwright at 390x844, scale 2, `colorScheme` dark and light.

## Architecture: what runs where

Personal money data and the compute on it live on the phone. The backend is optional and never sees transactions, balances or SMS text.

| Concern | Where | How |
| --- | --- | --- |
| Ledger (accounts, transactions, budgets, rules, assets, goals, raw captures) | **Phone** | Encrypted SQLite via drift, `lib/data/local/` |
| Encryption key | **Phone** | 32 random bytes generated on first run, kept in the platform keystore (`flutter_secure_storage`: iOS Keychain `first_unlock_this_device`, Android Keystore-wrapped) |
| SMS / notification / Shortcut capture | **Phone** | Android Kotlin layer and iOS App Intent hand items to the local pipeline; nothing is uploaded |
| Parsing (12 institutions + generic fallback), merchant clean-up, categorisation, user rules, de-duplication | **Phone** | Pure Dart engine, `lib/core/engine/` |
| Rewards, best card, caps, nudges | **Phone** | `rewards.dart` reading the card catalog |
| Safe-to-spend, health, cashflow, trends, due dates, recurring, net worth | **Phone** | `LocalPulseRepository` over the engine |
| Card catalog | **Phone, refreshed from backend** | Bundled `assets/catalog/cards.json`; `CatalogService` fetches a newer version when `API_BASE_URL` is set |
| Jewellery, documents (photos, dates, reminders), mutual fund holdings, valuations | **Phone** | `WealthService` over `lib/data/local/wealth_store.dart`; photos are copied into app-private storage and never uploaded; reminders are local notifications |
| Gold and FX prices, mutual fund scheme search and NAV | **Backend, shared and keyless** | `PriceService` fetches `GET /v1/prices/snapshot` and caches it in the `price_cache` table; `FundLookup` calls `/v1/funds/search` and `/v1/funds/schemes/{code}/latest`. No personal data is sent; the phone does all valuation |
| Auth, splits with other people, family sharing, statement parsing, Gmail, AI | **Backend** | `ApiPulseRepository`, used only for these shared features (AI is not built yet) |
| Backup and restore | **Phone encrypts, cloud stores ciphertext** | `lib/backup/`, end-to-end encrypted, see `docs/BACKUP.md` |

`repositoryProvider` (`lib/data/providers.dart`): `DEMO_DATA` or no open database gives `MockPulseRepository`; otherwise `LocalPulseRepository`, with `ApiPulseRepository` as its `shared` delegate when `API_BASE_URL` is set. Without a backend, server-only features return a clear "not supported" error or an empty list.

### Local database and encryption

- drift schema in `lib/data/local/tables.dart` mirrors the pulse-api models (22 tables, schema v2), so a later encrypted backup can map rows one to one. Money is integer fils; ids are text.
- Migrations use drift `stepByStep()`. Schema dumps live in `drift_schemas/`, generated step code in `lib/data/local/schema_versions.dart`, and `test/drift/` verifies fresh and migrated databases against the dumps. To change the schema: bump `currentSchemaVersion`, run `dart run drift_dev schema dump lib/data/local/database.dart drift_schemas/`, `dart run drift_dev schema steps drift_schemas/ lib/data/local/schema_versions.dart`, `dart run drift_dev schema generate drift_schemas/ test/drift/generated/`, add the `fromNToN+1` step, then `dart run build_runner build`.
- Encryption is **SQLite3 Multiple Ciphers**, selected through the `sqlite3` build hook in `pubspec.yaml` (`hooks: user_defines: sqlite3: source: sqlite3mc`). `sqlcipher_flutter_libs` is end-of-life and is not used. The database is keyed with `PRAGMA key`, and opening **refuses to run unencrypted** (`EncryptionUnavailable`); `main.dart` then shows a stop screen instead of silently writing plain text. `test/local/database_test.dart` proves the file contains no plaintext and cannot be read without the key.
- The hook compiles the library with the platform C toolchain at build time. It has been exercised here on Linux only; run an Android and an iOS build before relying on it.

### Engine, fixtures and parity

`lib/core/engine/` is pure Dart (no Flutter imports) and a port of the pulse-api services: parsers, merchant dictionary, rules (AND conditions, priority, preview and retroactive apply), de-duplication (same account and amount, within 3 days, fuzzy merchant; capture dedupe within an hour across channels), rewards, recurring detection, cashflow, safe-to-spend, health, due dates, net worth, salary detection. Semantics are kept (a capped rule earns nothing beyond its cap, OTP messages are never parsed or stored).

Python and Dart share JSON fixtures generated by running the backend code: `tool/gen_engine_fixtures.py` writes `test/fixtures/engine/*.json`, `assets/catalog/cards.json` and `lib/core/engine/merchant_dictionary.dart`. Regenerate with `/path/to/pulse-api/.venv/bin/python tool/gen_engine_fixtures.py` after changing the backend, then run `flutter test test/engine`.

### Card catalog

`assets/catalog/cards.json` (14 UAE cards) carries per-card `verified_on` and `source`. **The bundled figures are illustrative and unverified** (`verified_on: null`); the UI shows them as unverified until a catalog says otherwise. Update contract: `GET {API_BASE_URL}/v1/catalog/cards` returns the same document shape (`version`, `updated_on`, `cards`); `CatalogService.checkForUpdate()` applies it only when `version` is higher and at least one card is valid, and swallows network errors.

### Ingest pipeline

`IngestPipeline` (`lib/data/local/ingest_pipeline.dart`): drop OTP, parse (structured fields or the parser registry), hash and store the raw payload, resolve the account (last four digits and institution), link to a statement row or merge with another channel's capture, categorise (user rules, then dictionary), store, detect salary, compute the reward moment for card purchases and emit it. Messages with no matching account wait as `needs_review` and are retried when a card or account is added. Raw payloads are kept only for parsed and review items; OTP messages and non-transactions are never stored.

## Wealth: prices, jewellery, documents, funds

Everything here is free: no paid packages or APIs (`image_picker`, `flutter_local_notifications`, `timezone` are BSD), and the price sources behind the backend are keyless public feeds.

- **Prices** (`lib/data/local/price_service.dart`, `lib/core/engine/prices.dart`): with `API_BASE_URL` set, the app fetches the shared snapshot on open and resume (at most every 15 minutes; the refresh button forces it), stores each quote with its `fetched_at`, and shows "Live, updated 3 min ago" or "Saved prices, updated 2 days ago". Offline it works from the cache; with no cache and no backend it uses bundled last-known demo values (`bundledPriceBook`, labelled "Demo prices"). Jewellery and funds are revalued locally from the cached prices each time they are read, and one valuation snapshot per item per day is stored for the charts.
- **Gold and jewellery**: weight x purity x 24K price in AED (`valueJewellery` in `lib/core/engine/valuation.dart`). It is the melt value: making charges and dealer margin are not counted, and the add sheet says so. The add sheet shows the computed value live and has a weight stepper to confirm it. Gain/loss is against the total paid.
- **Documents**: category chips (title deed, FD certificate, insurance, passport, Emirates ID, visa, other), photos from the camera or gallery, optional expiry/maturity/renewal date and a reminder 1 week to 3 months before (a 9:00 local notification). Reminders are re-registered on every app open. The Wealth "Upcoming" list merges document dates and fund SIPs. There is no document-scanner SDK: "Scan" is the camera.
- **Mutual funds**: search Indian schemes (needs `API_BASE_URL`) or enter any fund by hand in AED, USD, INR, EUR or GBP. Value is units x NAV converted at the cached FX rate; a currency with no rate is left out of net worth rather than guessed. Funds and jewellery are in net worth and the allocation donut.
- **CAS import**: the entry point (file picker) says "Coming soon". The backend has a CAS endpoint, but it would receive the PAN-protected PDF and keep the holdings on the server, which the on-device rule rules out; an on-device parser is the plan. The file is not read and no password is asked for or stored.
- Platform entries: Android camera and notification permissions plus the scheduled-notification receivers; iOS camera, photo library and notification usage strings.

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
  capture/      ingest queue (durable inbox), capture service, Android bridge, iOS inbox bridge, Shortcut link parsing
  data/local/   encrypted database, repository, ingest pipeline, catalog service
  core/engine/  pure-Dart parsers, rules, rewards and insights engine
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

`ApiPulseRepository` is now the delegate for **shared features only** (splits, family, statements, Gmail), selected by `API_BASE_URL`. `MockPulseRepository` stays for demos via `DEMO_DATA=true`. UI code only sees `PulseRepository`.

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

Everything funnels into one persistent **queue** (`lib/capture/ingest_queue.dart`, backed by shared_preferences) that is now only a durable inbox between the native layer and the on-device pipeline: items are deduplicated by id, handed to `IngestPipeline` in order, retried with exponential backoff if the pipeline throws (30s up to 1h, dropped after 10 attempts or 14 days). It flushes when something is captured, when the app resumes, and every 10 minutes while open. Nothing is uploaded. OTP messages are dropped by the Kotlin layer and again in Dart before queuing. Note the queue briefly holds raw message text in shared_preferences (not the encrypted database) until the pipeline has taken it; it is normally empty within a second.

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

Flow: receiver filters, writes to the native buffer, pings Dart; Dart `peekPending` -> persists to its queue -> `ackPending` -> local pipeline. This is at-least-once and works when the app process was dead; the pipeline dedupes on the message hash (identical for live and backfill) and across channels.

- **Sender IDs** (`CaptureConfig.defaultBankSenderIds`): EmiratesNBD, ENBD, ADCBAlert, ADCB, FAB, Mashreq, RAKBANK, DIB, ADIB, HSBC, CBD, EIB, Liv, and more. IDs of 4 characters or fewer must match exactly (or as a `-` separated part, e.g. `AD-FAB`); longer ones match as substrings. Edit the list in Dart; it is pushed to the native layer on start.
- **Notification packages**: Google Wallet `com.google.android.apps.walletnfcrel`, Google Pay `com.google.android.apps.nbu.paisa.user`, Samsung `com.samsung.android.spay` and `com.samsung.android.samsungpay.gear`, plus bank apps via `bankAppPackages` (exact) and `bankPackageHints` (package-name substrings). Verify real bank package IDs before release; the exact list is empty by default.
- **Privacy**: non-bank SMS and other apps' notifications are dropped before being stored. Messages containing OTP / verification-code wording are never captured. Parsing happens on the phone; raw text never leaves it.
- **Permissions UI**: the connect step (Android tiles "Bank SMS" and "Wallet notifications") and Settings open a sheet explaining each permission, showing live status, requesting SMS permissions in-app, and deep-linking to the system notification-access screen (detail page on Android 11+). On return, the result is re-read. Apps installed outside Google Play on Android 13+ may need "Allow restricted settings" in App info; the sheet says so.
- Analytics: `permission_granted{permission}` / `permission_denied{permission}` with `permission` = `sms_receive`, `sms_read`, `notification_access`.
- `allowBackup` is off in the manifest: the database key lives in the Keystore and does not survive a restore, so a backed-up copy would be unreadable anyway.
- Play Store: `RECEIVE_SMS`/`READ_SMS` need a Play Console declaration. Plan for sideloaded/beta distribution first.
- No Android SDK is available in this environment, so the Kotlin has not been compiled; run `flutter build apk --debug` before relying on it.

### iOS: Shortcuts automation (App Intent)

Apple exposes no Wallet API and no SMS access, so the supported route is a Shortcuts **Transaction** automation that hands each payment to the app without a server.

**Primary: the "Record Payment" App Intent** (`ios/Runner/ShortcutCapture.swift`). The Shortcut calls the intent in the background; the intent appends `{amount, merchant, card, timestamp}` to a small file inbox in the app's Application Support folder (`PulseInbox/`). Flutter drains that inbox (`AppleInboxCapturePlatform`, channel `pulse/shortcut_inbox`) when the app starts and whenever it returns to the foreground, and feeds each item to the on-device pipeline. No server, no network. Because iOS does not start Flutter for a background intent, a payment is shown in the app the next time it is opened (the reward banner appears then).

Set it up (also shown in the in-app guide, `ApplePaySetupScreen`):

1. Open **Shortcuts**, then **Automation**, **New Automation**, **Transaction**.
2. Pick the cards (Wallet) to watch and choose **Run Immediately** (not "Ask Before Running"), then Next.
3. Add the action **Record Payment** (from Pulse). Fill its fields with the variables the trigger offers: **Amount** from `Amount`, **Merchant** from `Merchant`, **Card** from `Card or Pass`. Amounts like `AED 1,234.50` are fine.
4. Save. Repeat for each card, or choose several cards in one automation.

**Fallback: the `pulse://` deep link.** If you prefer, the automation can run **Open URL** `pulse://ingest?amount=[Amount]&merchant=[Merchant]&card=[Card or Pass]` (optional `currency`, `ts`, `direction`). The scheme is registered in `ios/Runner/Info.plist`; go_router rewrites it to `/apple-ingest`, which parses it (`ShortcutTransaction`) and runs it through the same queue and local pipeline. This opens the app on every payment, so the App Intent is preferred.

**Uncompiled.** The Swift file (about 130 lines: inbox, Flutter channel, App Intent, `AppShortcutsProvider`) was written without Xcode and has never been built or run. It is added to `Runner.xcodeproj` by hand; open the project, build once, and fix anything the compiler finds. The Dart side (`AppleInboxCapturePlatform`) is covered by tests with a mocked channel. The shared "Transaction" Shortcut link (`APPLE_SHORTCUT_URL`) is still a placeholder.

## Status

- Done: encrypted on-device database with migrations; `LocalPulseRepository` as the default; pure-Dart engine with golden parity tests against pulse-api; on-device ingest pipeline fed by Android SMS/notifications, the iOS App Intent inbox and the `pulse://` fallback; reward banner driven by real pipeline results; empty states and add-card/account/asset flows; card catalog loader with remote refresh.
- Stubbed or not built: CAS statement import (entry point only), document scanning beyond a plain photo, statement upload and parsing, Gmail, splits with other people and family sharing work only through the backend (`API_BASE_URL`); encrypted backup/sync and AI features are not built; health "bills on time" is neutral until statements exist; card minimum due is unknown on-device (shown as 0); non-AED transactions are stored but left out of AED totals.
- Unverified: reminders and the camera/gallery pickers on a real device (the notification plugin and the Android desugaring change have not been built here), the price and fund endpoints against live services, the card catalog figures (`verified_on` is null for every card); the sqlite3mc build hook on Android and iOS; the Kotlin and Swift code (neither compiled here).

Checks: `flutter analyze`, `flutter test`.
