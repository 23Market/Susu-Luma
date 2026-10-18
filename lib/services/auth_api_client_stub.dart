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
  AuthApiClient._();

  static final instance = AuthApiClient._();
  String? currentEmail;

  Future<void> configure(String baseUrl) async {}
  Future<void> refreshSession() async {}
  Future<AuthApiResult> login(String email, String password,
          {String? captchaToken}) async =>
      const AuthApiResult(success: false, error: 'web_auth_only');
  Future<AuthApiResult> signup(String email, String password,
          {String? captchaToken}) async =>
      const AuthApiResult(success: false, error: 'web_auth_only');
  Future<void> logout() async {}
  Future<bool> hasAdminAccess() async => false;
  Future<Map<String, dynamic>?> fetchAdminDashboard() async => null;
  Future<bool> reviewSupplier(String caseId, String decision,
          {String? reason}) async =>
      false;
  Future<bool> reviewListing(String listingId, String decision,
          {String? reason}) async =>
      false;
  Future<bool> resolveSupportCase(String caseId, String resolution) async =>
      false;
  Future<MfaEnrollment?> enrollTotp() async => null;
  Future<bool> verifyTotp(String factorId, String code) async => false;
  Future<List<String>> generateBackupCodes() async => const [];
  Future<bool> verifyBackupCode(String code) async => false;
  Future<AuthApiResult> forgotPassword(String email,
          {String? captchaToken}) async =>
      const AuthApiResult(success: false, error: 'web_auth_only');
  Future<bool> verifyRecoveryToken(String tokenHash) async => false;
  Future<AuthApiResult> resetPassword(String password,
          {String? captchaToken}) async =>
      const AuthApiResult(success: false, error: 'web_auth_only');
}
