import 'dart:convert';

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

class AuthApiResult {
  const AuthApiResult({
    required this.success,
    this.error,
    this.captchaRequired = false,
    this.mfaRequired = false,
    this.factorId,
  });

  final bool success;
  final String? error;
  final bool captchaRequired;
  final bool mfaRequired;
  final String? factorId;
}

class MfaEnrollment {
  const MfaEnrollment({required this.factorId, required this.secret});
  final String factorId;
  final String secret;
}

class AuthApiClient {
  AuthApiClient._() {
    _client.withCredentials = true;
  }

  static final instance = AuthApiClient._();
  final BrowserClient _client = BrowserClient();
  Uri _baseUrl = Uri.base.resolve('/api/auth/');
  String? currentEmail;
  String? _csrfToken;

  Future<void> configure(String baseUrl) async {
    _baseUrl = baseUrl.startsWith('http')
        ? Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/')
        : Uri.base.resolve(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
    await refreshSession();
  }

  Future<void> refreshSession() async {
    final response = await _client.get(_baseUrl.resolve('session'));
    if (response.statusCode != 200) {
      currentEmail = null;
      _csrfToken = null;
      return;
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    currentEmail = body['email'] as String?;
    _csrfToken = body['csrfToken'] as String?;
  }

  Future<AuthApiResult> login(
    String email,
    String password, {
    String? captchaToken,
  }) =>
      _authenticate('login', email, password, captchaToken);

  Future<AuthApiResult> signup(
    String email,
    String password, {
    String? captchaToken,
  }) =>
      _authenticate('signup', email, password, captchaToken);

  Future<AuthApiResult> _authenticate(
    String route,
    String email,
    String password,
    String? captchaToken,
  ) async {
    final response = await _client.post(
      _baseUrl.resolve(route),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        if (captchaToken != null) 'captchaToken': captchaToken,
      }),
    );
    final body = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await refreshSession();
      return AuthApiResult(
        success: true,
        mfaRequired: body['mfaRequired'] == true,
        factorId: body['factorId'] as String?,
      );
    }
    return AuthApiResult(
      success: false,
      error: body['error'] as String? ?? 'authentication_failed',
      captchaRequired: body['captchaRequired'] == true,
    );
  }

  Future<void> logout() async {
    await _client.post(
      _baseUrl.resolve('logout'),
      headers: {
        'Content-Type': 'application/json',
        if (_csrfToken != null) 'X-CSRF-Token': _csrfToken!,
      },
      body: '{}',
    );
    currentEmail = null;
    _csrfToken = null;
  }

  Future<bool> hasAdminAccess() async {
    final response = await _client.get(_baseUrl.resolve('admin/access'));
    return response.statusCode == 200 && _decode(response)['allowed'] == true;
  }

  Future<Map<String, dynamic>?> fetchAdminDashboard() async {
    final response = await _client.get(_baseUrl.resolve('admin/dashboard'));
    if (response.statusCode != 200) return null;
    final dashboard = _decode(response)['dashboard'];
    return dashboard is Map ? Map<String, dynamic>.from(dashboard) : null;
  }

  Future<bool> reviewSupplier(
    String caseId,
    String decision, {
    String? reason,
  }) async {
    final response = await _postAuthenticated('admin/suppliers/review', {
      'caseId': caseId,
      'decision': decision,
      if (reason != null) 'reason': reason,
    });
    return response.statusCode == 200;
  }

  Future<bool> reviewListing(
    String listingId,
    String decision, {
    String? reason,
  }) async {
    final response = await _postAuthenticated('admin/listings/review', {
      'listingId': listingId,
      'decision': decision,
      if (reason != null) 'reason': reason,
    });
    return response.statusCode == 200;
  }

  Future<bool> resolveSupportCase(String caseId, String resolution) async {
    final response = await _postAuthenticated('admin/support/resolve', {
      'caseId': caseId,
      'resolution': resolution,
    });
    return response.statusCode == 200;
  }

  Future<MfaEnrollment?> enrollTotp() async {
    final response = await _postAuthenticated('mfa/enroll', const {});
    if (response.statusCode != 200) return null;
    final body = _decode(response);
    final totp = body['totp'];
    if (totp is! Map<String, dynamic>) return null;
    return MfaEnrollment(
      factorId: body['id'] as String,
      secret: totp['secret'] as String,
    );
  }

  Future<bool> verifyTotp(String factorId, String code) async {
    final response = await _postAuthenticated(
      'mfa/verify',
      {'factorId': factorId, 'code': code},
    );
    if (response.statusCode == 200) await refreshSession();
    return response.statusCode == 200;
  }

  Future<List<String>> generateBackupCodes() async {
    final response = await _postAuthenticated('mfa/backup-codes', const {});
    if (response.statusCode != 201) return const [];
    final codes = _decode(response)['codes'];
    return codes is List ? codes.whereType<String>().toList() : const [];
  }

  Future<bool> verifyBackupCode(String code) async {
    final response = await _postAuthenticated(
      'mfa/backup-code/verify',
      {'code': code},
    );
    return response.statusCode == 200;
  }

  Future<AuthApiResult> forgotPassword(
    String email, {
    String? captchaToken,
  }) async {
    final response = await _client.post(
      _baseUrl.resolve('forgot-password'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        if (captchaToken != null) 'captchaToken': captchaToken,
      }),
    );
    final body = _decode(response);
    return AuthApiResult(
      success: response.statusCode == 202,
      error: body['error'] as String?,
      captchaRequired: body['captchaRequired'] == true,
    );
  }

  Future<bool> verifyRecoveryToken(String tokenHash) async {
    final response = await _client.post(
      _baseUrl.resolve('verify-otp'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'tokenHash': tokenHash, 'type': 'recovery'}),
    );
    if (response.statusCode == 200) await refreshSession();
    return response.statusCode == 200;
  }

  Future<AuthApiResult> resetPassword(
    String password, {
    String? captchaToken,
  }) async {
    final response = await _postAuthenticated('reset-password', {
      'password': password,
      if (captchaToken != null) 'captchaToken': captchaToken,
    });
    final body = _decode(response);
    return AuthApiResult(
      success: response.statusCode == 200,
      error: body['error'] as String?,
      captchaRequired: body['captchaRequired'] == true,
    );
  }

  Future<http.Response> _postAuthenticated(
    String route,
    Map<String, dynamic> body,
  ) async {
    if (_csrfToken == null) await refreshSession();
    return _client.post(
      _baseUrl.resolve(route),
      headers: {
        'Content-Type': 'application/json',
        if (_csrfToken != null) 'X-CSRF-Token': _csrfToken!,
      },
      body: jsonEncode(body),
    );
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on Object {
      return const {'error': 'invalid_server_response'};
    }
  }
}
