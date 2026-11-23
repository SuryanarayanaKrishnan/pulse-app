/// Build-time configuration via `--dart-define`.
class Env {
  const Env._();

  /// Single place to rename the product.
  static const appName = 'Pulse';
  static const tagline = 'Your money, in rhythm.';

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const posthogKey = String.fromEnvironment('POSTHOG_API_KEY');
  static const posthogHost = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://eu.i.posthog.com',
  );
  static const useMockData = bool.fromEnvironment(
    'USE_MOCK_DATA',
    defaultValue: true,
  );

  /// Dev convenience: skip onboarding, sign-in and connect steps.
  static const devSkipOnboarding = bool.fromEnvironment('DEV_SKIP_ONBOARDING');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get hasPosthog => posthogKey.isNotEmpty;
}
