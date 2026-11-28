import 'package:flutter/foundation.dart' show kReleaseMode, visibleForTesting;

/// Build-time configuration via `--dart-define`.
class Env {
  const Env._();

  /// Single place to rename the product.
  static const appName = 'Pulse';
  static const tagline = 'Your money, in rhythm.';

  /// Backend base URL (no trailing `/v1`). Optional: personal data and
  /// compute live on the phone; the backend only serves shared features
  /// (auth, splits, family, backup, the card catalog and price cache).
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const posthogKey = String.fromEnvironment('POSTHOG_API_KEY');
  static const posthogHost = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://eu.i.posthog.com',
  );

  /// Base64 Ed25519 public key that verifies `/v1/config`. Empty means
  /// unsigned configs are accepted (dev only; release builds need a key).
  static const configPublicKey = String.fromEnvironment('CONFIG_PUBLIC_KEY');

  /// Dev convenience: skip onboarding, sign-in and connect steps.
  static const devSkipOnboarding = bool.fromEnvironment('DEV_SKIP_ONBOARDING');

  /// Local dev only: fetch a token from the local backend's `POST /v1/dev/token`
  /// (needs ALLOW_DEV_AUTH=true there). Ignored in release builds; see
  /// [devAuthEnabled]. `--dart-define=DEV_AUTH=true`.
  static const devAuth = bool.fromEnvironment('DEV_AUTH');

  /// [devAuth], but never in a release build.
  static bool get devAuthEnabled => devAuth && !kReleaseMode && useApi;

  /// Public iCloud share links of the four prebuilt Shortcuts (Shortcuts >
  /// share > Copy iCloud Link). Empty until built: the setup screen then shows
  /// the shortest in-app instruction instead. See docs/SHORTCUT_LINKS.md.
  /// Pass with `--dart-define=SHORTCUT_LINK_WALLET=https://www.icloud.com/shortcuts/...`.
  static const shortcutLinkWallet = String.fromEnvironment(
    'SHORTCUT_LINK_WALLET',
  );
  static const shortcutLinkBankSms = String.fromEnvironment(
    'SHORTCUT_LINK_BANK_SMS',
  );
  static const shortcutLinkCapture = String.fromEnvironment(
    'SHORTCUT_LINK_CAPTURE',
  );
  static const shortcutLinkAskCapture = String.fromEnvironment(
    'SHORTCUT_LINK_ASK_CAPTURE',
  );

  /// URL scheme registered in `ios/Runner/Info.plist` (`pulse://ingest?...`).
  static const urlScheme = 'pulse';

  /// Run on the built-in demo data instead of the on-device ledger
  /// (screenshots, demos): `--dart-define=DEMO_DATA=true`.
  static const demoData = bool.fromEnvironment('DEMO_DATA');

  /// Sample data is for preview/debug builds only. A release build always
  /// runs on the person's own on-device ledger, never on made-up data.
<<<<<<< HEAD
  static bool get sampleAllowed => demoData || !kReleaseMode;
=======
  static bool get sampleAllowed =>
      debugReleaseOverride != null ? !debugReleaseOverride! : (demoData || !kReleaseMode);

  /// Tests only: pretend to be a release build (true) so the guard that keeps
  /// sample data out of release builds can be exercised. Null in production.
  @visibleForTesting
  static bool? debugReleaseOverride;
>>>>>>> origin/main

  /// Beta builds enable shake-to-report by default. Pass
  /// `--dart-define=BETA_BUILD=false` for a store build.
  static const betaBuild = bool.fromEnvironment(
    'BETA_BUILD',
    defaultValue: true,
  );

  /// Optional bug-report endpoint (docs/BUG_REPORTS.md). Empty: reports go
  /// through the system share sheet only. Never put a token here.
  static const bugReportUrl = String.fromEnvironment('BUG_REPORT_URL');

  /// True when a backend is configured (for shared features only).
  static bool get useApi => apiBaseUrl.isNotEmpty;

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get hasPosthog => posthogKey.isNotEmpty;
}
