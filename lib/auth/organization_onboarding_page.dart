import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrganizationOnboardingPage extends StatefulWidget {
  const OrganizationOnboardingPage({super.key});

  @override
  State<OrganizationOnboardingPage> createState() =>
      _OrganizationOnboardingPageState();
}

class _OrganizationOnboardingPageState
    extends State<OrganizationOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _legalNameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _districtController = TextEditingController();
  final _localityController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _legalNameController.dispose();
    _displayNameController.dispose();
    _districtController.dispose();
    _localityController.dispose();
    super.dispose();
  }

  String? _requiredName(String? value, int maximum) {
    final length = value?.trim().length ?? 0;
    if (length < 2) return 'Enter at least two characters.';
    if (length > maximum) return 'Use no more than $maximum characters.';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.rpc(
        'create_organization',
        params: {
          'organization_legal_name': _legalNameController.text.trim(),
          'organization_display_name': _displayNameController.text.trim(),
          'organization_district': _districtController.text.trim(),
          'organization_locality': _localityController.text.trim(),
        },
      );
      if (mounted) Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Unable to create the organisation right now.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Set up your business')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Business identity',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create the organisation record used for marketplace access. Supplier verification is a separate review.',
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _legalNameController,
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => _requiredName(value, 180),
                        decoration: const InputDecoration(
                          labelText: 'Registered legal name',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _displayNameController,
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => _requiredName(value, 120),
                        decoration: const InputDecoration(
                          labelText: 'Marketplace display name',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _districtController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'District (optional)',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _localityController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Town or area (optional)',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _busy ? null : _submit,
                        icon: const Icon(Icons.add_business_rounded),
                        label: Text(
                          _busy ? 'Creating…' : 'Create organisation',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Creating an organisation does not grant verified-supplier status or approve any listing.',
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
      );
}
