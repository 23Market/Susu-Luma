/// Build-time configuration. Only the *publishable* key may ever be shipped in the app; never a service-role
/// or secret key. Pass values with --dart-define (or --dart-define-from-file) — never commit them.
/// Example (placeholders): `flutter run --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_KEY`
/// Without them the app runs in clearly labelled demo mode on in-memory sample data.
class BackendConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}
