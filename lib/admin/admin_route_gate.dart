import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_api_client.dart';
import 'admin_dashboard.dart';

class AdminRouteGate extends StatelessWidget {
  const AdminRouteGate({super.key, required this.backendAvailable});

  final bool backendAvailable;

  Future<bool> _isPlatformAdmin() async {
    if (kIsWeb) return AuthApiClient.instance.hasAdminAccess();
    if (Supabase.instance.client.auth.currentUser == null) return false;
    final result = await Supabase.instance.client.rpc('is_platform_admin_aal2');
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    if (!backendAvailable) {
      return const _AdminAccessDenied(
        message:
            'Administrator access cannot be verified because the backend is not configured.',
      );
    }

    return FutureBuilder<bool>(
      future: _isPlatformAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) return const AdminDashboard();
        return const _AdminAccessDenied(
          message:
              'This account does not have a server-authorised platform administrator role with two-factor verification.',
        );
      },
    );
  }
}

class _AdminAccessDenied extends StatelessWidget {
  const _AdminAccessDenied({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Admin dashboard')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Administrator access required',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      );
}
