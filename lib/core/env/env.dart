/// Build-time configuration via `--dart-define`.
class Env {
  const Env._();

  /// Single place to rename the product.
  static const appName = 'Pulse';
  static const tagline = 'Your money, in rhythm.';

  /// Backend base URL (no trailing `/v1`). When empty the app runs on mock data.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const posthogKey = String.fromEnvironment('POSTHOG_API_KEY');
  static const posthogHost = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://eu.i.posthog.com',
  );

  /// Dev convenience: skip onboarding, sign-in and connect steps.
  static const devSkipOnboarding = bool.fromEnvironment('DEV_SKIP_ONBOARDING');

  /// Placeholder public iCloud link of the shared "Transaction" Shortcut.
  /// Replace once the Shortcut is published.
  static const appleShortcutUrl = String.fromEnvironment(
    'APPLE_SHORTCUT_URL',
    defaultValue: 'https://www.icloud.com/shortcuts/REPLACE_WITH_SHORTCUT_ID',
  );

  /// URL scheme registered in `ios/Runner/Info.plist` (`pulse://ingest?...`).
  static const urlScheme = 'pulse';

  /// True when a backend is configured; otherwise the mock repository is used.
  static bool get useApi => apiBaseUrl.isNotEmpty;

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get hasPosthog => posthogKey.isNotEmpty;
}
