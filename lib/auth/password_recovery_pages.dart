import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../services/auth_api_client.dart';
import '../services/captcha_client.dart';
import 'password_policy.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _message;
  String? _captchaToken;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      if (kIsWeb) {
        _captchaToken ??= await CaptchaClient.getToken(
          AppConfig.fromEnvironment().turnstileSiteKey,
        );
        await AuthApiClient.instance.forgotPassword(
          _email.text.trim(),
          captchaToken: _captchaToken,
        );
        _captchaToken = null;
      } else {
        await Supabase.instance.client.auth.resetPasswordForEmail(
          _email.text.trim(),
        );
      }
      if (mounted) {
        setState(() => _message =
            'If the account exists, password-reset instructions have been sent.');
      }
    } on Object {
      if (mounted) {
        setState(() => _message =
            'If the account exists, password-reset instructions have been sent.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Forgot password')),
        body: _AuthCard(
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Please wait…' : 'Send reset instructions'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 14),
              Text(_message!, textAlign: TextAlign.center),
            ],
          ],
        ),
      );
}

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _password = TextEditingController();
  bool _verified = !kIsWeb;
  bool _busy = true;
  String? _message;
  String? _captchaToken;
  PasswordAssessment _assessment = PasswordPolicy.assess('');

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    if (kIsWeb) {
      final tokenHash = Uri.base.queryParameters['token_hash'] ?? '';
      _verified = tokenHash.isNotEmpty &&
          await AuthApiClient.instance.verifyRecoveryToken(tokenHash);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_assessment.isAcceptable) {
      setState(() => _message = _assessment.errors.join(' '));
      return;
    }
    setState(() => _busy = true);
    try {
      if (kIsWeb) {
        _captchaToken ??= await CaptchaClient.getToken(
          AppConfig.fromEnvironment().turnstileSiteKey,
        );
      }
      final succeeded = kIsWeb
          ? (await AuthApiClient.instance.resetPassword(
              _password.text,
              captchaToken: _captchaToken,
            ))
              .success
          : (await Supabase.instance.client.auth.updateUser(
                UserAttributes(password: _password.text),
              ))
                  .user !=
              null;
      _captchaToken = null;
      if (mounted) {
        setState(() => _message = succeeded
            ? 'Password updated. You can return to the app.'
            : 'Password could not be updated.');
      }
    } on Object {
      if (mounted) setState(() => _message = 'Password could not be updated.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reset password')),
        body: _AuthCard(
          children: _busy
              ? const [Center(child: CircularProgressIndicator())]
              : !_verified
                  ? const [
                      Text(
                        'This password-reset link is invalid or expired.',
                        textAlign: TextAlign.center,
                      )
                    ]
                  : [
                      TextField(
                        controller: _password,
                        obscureText: true,
                        onChanged: (value) => setState(
                            () => _assessment = PasswordPolicy.assess(value)),
                        decoration:
                            const InputDecoration(labelText: 'New password'),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _assessment.score / 4),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _submit,
                        child: const Text('Update password'),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 14),
                        Text(_message!, textAlign: TextAlign.center),
                      ],
                    ],
        ),
      );
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
