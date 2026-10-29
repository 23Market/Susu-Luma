import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('accepts an HTTPS Supabase URL and publishable key', () {
      const config = AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabasePublishableKey: 'publishable-key',
      );

      expect(config.hasSupabaseConfiguration, isTrue);
    });

    test('rejects missing, malformed and insecure configuration', () {
      const configurations = [
        AppConfig(supabaseUrl: '', supabasePublishableKey: ''),
        AppConfig(
          supabaseUrl: 'not-a-url',
          supabasePublishableKey: 'publishable-key',
        ),
        AppConfig(
          supabaseUrl: 'http://example.supabase.co',
          supabasePublishableKey: 'publishable-key',
        ),
        AppConfig(
          supabaseUrl: 'https://example.supabase.co',
          supabasePublishableKey: '',
        ),
      ];

      for (final config in configurations) {
        expect(config.hasSupabaseConfiguration, isFalse);
      }
    });
  });
}
