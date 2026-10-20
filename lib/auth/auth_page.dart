import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../services/auth_api_client.dart';
import '../services/captcha_client.dart';
import '../widgets/luma_brand.dart';
import 'mfa_page.dart';
import 'password_policy.dart';
import 'password_recovery_pages.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  String? _message;
  PasswordAssessment _passwordAssessment = PasswordPolicy.assess('');
  bool _captchaRequired = false;
  String? _captchaToken;

  @override
  void initState() {
    super.initState();
    _captchaRequired =
        kIsWeb && AppConfig.fromEnvironment().turnstileSiteKey.isNotEmpty;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _message = 'Enter a valid email address.');
      return;
    }
    final assessment = PasswordPolicy.assess(password);
    if (_registering && !assessment.isAcceptable) {
      setState(() => _message = assessment.errors.join(' '));
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (kIsWeb) {
        if (_captchaRequired && _captchaToken == null) {
          _captchaToken = await CaptchaClient.getToken(
            AppConfig.fromEnvironment().turnstileSiteKey,
          );
          if (_captchaToken == null) {
            setState(
                () => _message = 'Security challenge could not be completed.');
            return;
          }
        }
        final result = _registering
            ? await AuthApiClient.instance.signup(
                email,
                password,
                captchaToken: _captchaToken,
              )
            : await AuthApiClient.instance.login(
                email,
                password,
                captchaToken: _captchaToken,
              );
        if (!mounted) return;
        if (result.success) {
          if (result.mfaRequired) {
            await Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => MfaPage(initialFactorId: result.factorId),
              ),
            );
          } else {
            Navigator.of(context).pop();
          }
          return;
        }
        setState(() {
          _captchaRequired = result.captchaRequired;
          _captchaToken = null;
          _message = _friendlyError(result.error);
        });
        return;
      }
      if (_registering) {
        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        if (!mounted) return;
        setState(() {
          _message = response.session == null
              ? 'Check your email to confirm the account.'
              : 'Account created. You are signed in.';
        });
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (mounted) Navigator.of(context).pop();
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on Object {
      if (mounted) {
        setState(() => _message = 'Unable to connect. Try again later.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(String? error) => switch (error) {
        'captcha_required' => 'Complete the security challenge and try again.',
        'rate_limited' => 'Too many attempts. Wait before trying again.',
        'invalid_credentials' => 'The email or password is incorrect.',
        'password_found_in_breach' =>
          'Choose a password that has not appeared in a known breach.',
        'password_breach_check_unavailable' =>
          'Password safety verification is unavailable. Try again later.',
        _ => 'Authentication could not be completed.',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: Text(_registering ? 'Create account' : 'Sign in')),
        body: SafeArea(
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
                      children: [
                        const LumaBrand(compact: true, height: 92),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          autofillHints: _registering
                              ? const [AutofillHints.newPassword]
                              : const [AutofillHints.password],
                          onSubmitted: (_) => _busy ? null : _submit(),
                          onChanged: (value) => setState(() {
                            _passwordAssessment = PasswordPolicy.assess(value);
                          }),
                          decoration:
                              const InputDecoration(labelText: 'Password'),
                        ),
                        if (_registering) ...[
                          const SizedBox(height: 10),
                          Semantics(
                            label:
                                'Password strength: ${_passwordAssessment.label}',
                            child: LinearProgressIndicator(
                              value: _passwordAssessment.score / 4,
                              minHeight: 7,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${_passwordAssessment.label} · 12+ characters with uppercase, lowercase, number and symbol',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                        if (_captchaRequired && kIsWeb) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'A security challenge will run when you continue.',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                        if (_message != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            _message!,
                            semanticsLabel: 'Authentication status: $_message',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: Text(_busy
                              ? 'Please wait…'
                              : _registering
                                  ? 'Create account'
                                  : 'Sign in'),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _registering = !_registering;
                                    _message = null;
                                  }),
                          child: Text(_registering
                              ? 'Already registered? Sign in'
                              : 'Create a business account'),
                        ),
                        if (!_registering)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            const ForgotPasswordPage(),
                                      ),
                                    ),
                            child: const Text('Forgot password?'),
                          ),
                        const Text(
                          'Use a business email you control. Organisation access is granted separately after sign-in.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
