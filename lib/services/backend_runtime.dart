import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'auth_api_client.dart';
import 'secure_session_storage.dart';

class BackendRuntime {
  const BackendRuntime._(
      {required this.isConfigured, this.initializationError});

  const BackendRuntime.offline()
      : isConfigured = false,
        initializationError = null;

  final bool isConfigured;
  final Object? initializationError;

  bool get isAvailable => isConfigured && initializationError == null;

  static Future<BackendRuntime> initialize(AppConfig config) async {
    if (kIsWeb) {
      try {
        await AuthApiClient.instance.configure(config.authApiBaseUrl);
        return const BackendRuntime._(isConfigured: true);
      } on Object catch (error) {
        return BackendRuntime._(
          isConfigured: true,
          initializationError: error,
        );
      }
    }
    if (!config.hasSupabaseConfiguration) {
      return const BackendRuntime.offline();
    }

    try {
      await Supabase.initialize(
        url: config.supabaseUrl,
        publishableKey: config.supabasePublishableKey,
        authOptions: const FlutterAuthClientOptions(
          localStorage: SecureSessionStorage(),
        ),
      );
      return const BackendRuntime._(isConfigured: true);
    } on Object catch (error) {
      return BackendRuntime._(
        isConfigured: true,
        initializationError: error,
      );
    }
  }
}
