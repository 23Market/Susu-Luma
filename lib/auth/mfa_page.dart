import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_api_client.dart';

class MfaPage extends StatefulWidget {
  const MfaPage({super.key, this.initialFactorId});

  final String? initialFactorId;

  @override
  State<MfaPage> createState() => _MfaPageState();
}

class _MfaPageState extends State<MfaPage> {
  final _codeController = TextEditingController();
  String? _factorId;
  String? _secret;
  String? _message;
  List<String> _backupCodes = const [];
  bool _busy = false;
  bool _newEnrollment = false;
  bool _usingBackupCode = false;

  @override
  void initState() {
    super.initState();
    _factorId = widget.initialFactorId;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _enroll() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (kIsWeb) {
        final enrollment = await AuthApiClient.instance.enrollTotp();
        if (enrollment == null) throw StateError('Enrollment failed');
        _factorId = enrollment.factorId;
        _secret = enrollment.secret;
      } else {
        final enrollment = await Supabase.instance.client.auth.mfa.enroll(
          factorType: FactorType.totp,
          issuer: 'Susu Luma',
          friendlyName: 'Authenticator app',
        );
        _factorId = enrollment.id;
        _secret = enrollment.totp?.secret;
      }
      _newEnrollment = true;
      if (mounted) setState(() {});
    } on Object {
      if (mounted) {
        setState(() => _message = 'Authenticator setup could not be started.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final factorId = _factorId;
    final code = _codeController.text.trim();
    if (_usingBackupCode) {
      if (code.length < 8) {
        setState(() => _message = 'Enter a valid backup code.');
        return;
      }
    } else if (factorId == null || !RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _message = 'Enter the six-digit authenticator code.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_usingBackupCode && kIsWeb) {
        if (!await AuthApiClient.instance.verifyBackupCode(code)) {
          throw StateError('Backup verification failed');
        }
      } else if (kIsWeb) {
        if (!await AuthApiClient.instance.verifyTotp(factorId!, code)) {
          throw StateError('Verification failed');
        }
        if (_newEnrollment) {
          _backupCodes = await AuthApiClient.instance.generateBackupCodes();
        }
      } else {
        await Supabase.instance.client.auth.mfa.challengeAndVerify(
          factorId: factorId!,
          code: code,
        );
      }
      if (mounted && widget.initialFactorId != null && !_newEnrollment) {
        Navigator.of(context).pop();
        return;
      }
      if (mounted) {
        setState(() {
          _message = _backupCodes.isEmpty
              ? 'Two-factor authentication is active.'
              : 'Two-factor authentication is active. Save the backup codes now.';
        });
      }
    } on Object {
      if (mounted) setState(() => _message = 'The code is invalid or expired.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Two-factor authentication')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.phonelink_lock_rounded, size: 48),
                    const SizedBox(height: 18),
                    const Text('Protect your account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 25, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text(
                      'Platform administrators must verify an authenticator code before accessing admin services.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_factorId == null)
                      FilledButton.icon(
                        onPressed: _busy ? null : _enroll,
                        icon: const Icon(Icons.qr_code_2_rounded),
                        label: const Text('Set up authenticator app'),
                      )
                    else ...[
                      if (_secret != null) ...[
                        const Text(
                            'Add this setup key to your authenticator app:',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        SelectableText(_secret!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 17,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                      ] else
                        Text(
                          _usingBackupCode
                              ? 'Enter one unused backup code.'
                              : 'Enter the code shown in your authenticator app.',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      TextField(
                        controller: _codeController,
                        keyboardType: _usingBackupCode
                            ? TextInputType.text
                            : TextInputType.number,
                        inputFormatters: _usingBackupCode
                            ? [LengthLimitingTextInputFormatter(32)]
                            : [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                        decoration: InputDecoration(
                          labelText: _usingBackupCode
                              ? 'Backup code'
                              : 'Six-digit code',
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: _busy ? null : _verify,
                        child: Text(_busy ? 'Verifying…' : 'Verify and enable'),
                      ),
                      if (kIsWeb && widget.initialFactorId != null)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() {
                                    _usingBackupCode = !_usingBackupCode;
                                    _codeController.clear();
                                    _message = null;
                                  }),
                          child: Text(_usingBackupCode
                              ? 'Use authenticator code'
                              : 'Use a backup code'),
                        ),
                    ],
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Text(_message!, textAlign: TextAlign.center),
                    ],
                    if (_backupCodes.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Backup codes (each works once)',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      SelectableText(_backupCodes.join('\n'),
                          style: const TextStyle(fontFamily: 'monospace')),
                      const SizedBox(height: 10),
                      const Text(
                        'Store these offline. They will not be displayed again.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
