class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    this.authApiBaseUrl = '/api/auth/',
    this.turnstileSiteKey = '',
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
        supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
        supabasePublishableKey:
            String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
        authApiBaseUrl: String.fromEnvironment(
          'AUTH_API_BASE_URL',
          defaultValue: '/api/auth/',
        ),
        turnstileSiteKey: String.fromEnvironment('TURNSTILE_SITE_KEY'),
      );

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String authApiBaseUrl;
  final String turnstileSiteKey;

  bool get hasSupabaseConfiguration {
    final uri = Uri.tryParse(supabaseUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        supabasePublishableKey.trim().isNotEmpty;
  }
}
