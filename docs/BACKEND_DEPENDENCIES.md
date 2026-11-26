# What needs the backend or a sign-in

Everything that holds your own data runs on the phone: the ledger, budgets,
cards, goals, wealth, the vault, statement reading, budget import, capture.
This page lists the features that reach outside the phone, what each one
needs, and what you see without it.

"Available once you're signed in" is one shared state
(`lib/core/widgets/needs_sign_in.dart`, `lib/core/network/cloud_access.dart`).
It is calm, not an error. The Sign in button shows only when a backend exists
and nobody is signed in to it (`CloudAccess.signedOut`); in a build with no
backend (`CloudAccess.unavailable`) there is nothing to sign in to, so the
button is left out. Features that fail inside the repository raise
`NeedsSignInException`, whose message reads "<Feature> is available once
you're signed in." and which the existing toasts already show.

| Feature | Needs | Offline / no sign-in behaviour |
| --- | --- | --- |
| Statement import: PDF, CSV, Excel (.xlsx), text | None | Read on the phone. Nothing uploaded. Specific errors (empty, wrong format, old .xls, password needed, scanned PDF, bank not supported, columns not recognised) with next steps. See "Statement import" below. |
| Statement passwords | None | Keychain / Keystore, this device only. |
| Reconciliation sheet | None | Built on the phone from the statement lines and what was captured. |
| Gmail statements (`connectGmail`, Settings, Monthly close, onboarding connect step) | Backend and Google sign-in | Shared "Available once you're signed in" sheet and row text. Files import still works. |
| Budget import from Excel / CSV file | None | Fully on-device (`readBudgetFile`, `readXlsx`, `parseCsv`). Specific errors. |
| Budget import from a Google Sheets link | Network. Sheet shared as "Anyone with the link can view" | Plain-language message: private sheet (needs a Google sign-in, which is not available yet), offline, or not a workbook; always points at "Choose a file". |
| Splitting with others (groups, expenses, members, settle up, contact matching) | Backend and Pulse sign-in | Lists are empty; actions say "Available once you're signed in." Personal expense tracking is unaffected. |
| Family sharing (invite, sharing levels) | Backend and Pulse sign-in | Same message. |
| Encrypted cloud backup | Supabase sign-in | Option disabled with "Available once you're signed in". "A backup file I keep myself" (encrypted export to Files) works with no sign-in. |
| Restore from the cloud | Supabase sign-in | Disabled with the same text. Restore from a backup file works. |
| Sync between devices | Supabase sign-in and a backup key | Callout explains it comes after backup. Single-phone use is unaffected. |
| Household (shared budget between people) | Supabase sign-in for the encrypted relay | Works on one phone; the relay is off until signed in. |
| Card catalog updates | Backend (`/v1/catalog/cards`) | Bundled catalog always loaded first; update is a bonus, failures are silent and harmless (reference data only). |
| Content packs and feature flags (tips, walkthrough, parser rules, `/v1/config`) | Backend | Bundled copies, then the last verified download. Signature checked. Nothing about you is sent. |
| Gold, FX and stock prices | Backend snapshot | Cached quotes, then bundled last-known values labelled as such. |
| Fund lookup | Backend | Manual entry still works. |
| Bug report | None (share sheet); optional `BUG_REPORT_URL` issue endpoint | Share sheet is always available; the endpoint is optional and falls back to it. |
| Vault automatic release after inactivity | Backend relay | The screens say it is not switched on and the file is handed over by hand. |
| Plus billing | None today | A test purchase screen (entitlement is local); real billing is not wired. |
| Capture ingest API (`/v1/ingest/*`) | Backend | Not used by the app: capture is parsed on the phone. |
| Analytics | PostHog key and your consent | Off until you opt in; the app works the same without it. |
| Sign in itself | Supabase | Without Supabase configured, sign-in succeeds locally (dev mode). |

## Statement import

Pick a file in Monthly close. iOS Files returns a copy inside the app's
sandbox; Pulse reads its bytes (falling back to the file path), works out the
type from the first bytes (not the name), and reads it on the phone.

| File | How it is read |
| --- | --- |
| PDF with text | pdfrx extracts the text, then the line parser (`statement_parser.dart`). Saved bank passwords are tried first. |
| PDF locked | Kept (still encrypted) and a password sheet opens. A wrong password is rejected in the sheet and not kept. Once right, the statement is read again. |
| PDF that is a scan | No text layer: "This PDF is a scan", suggests screenshot capture or the bank's CSV. |
| CSV, TSV, text | Header row and columns detected (date, description, amount or debit / credit, balance, Dr/Cr). |
| Excel `.xlsx` | Same table reader, every visible sheet tried. |
| Excel `.xls` (old) | Refused with "Save As .xlsx or CSV". |
| Anything else | "Not a statement file". |
| Unknown columns in a CSV or Excel file | The column-mapping sheet: pick date, description and amount (or debit / credit) once. |
| A bank or layout Pulse does not know | "Send us a sample" opens the bug report sheet. |

Statements without printed balances (most CSV exports) show as "Imported"
rather than "Reconciled", because there is nothing to check them against.

## Not verified without a device

The iOS file picker, security-scoped access and pdfrx on a real iPhone
cannot be exercised in CI; see the PR description for what to check by hand.
