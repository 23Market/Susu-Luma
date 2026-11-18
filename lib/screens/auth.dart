// ignore: deprecated_member_use -- Flutter 3.50 prefers material_ui; keep the SDK-wide import until the project migrates.
import 'package:flutter/material.dart';
import '../backend/errors.dart';
import '../backend/live_store.dart';
import '../models.dart';
import '../store.dart';
import '../ui.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 24),
          Align(
              alignment: Alignment.centerLeft,
              child: Image.asset('assets/images/logo.png',
                  width: 64, height: 64, semanticLabel: 'Susu Luma logo')),
          const SizedBox(height: 18),
          const Text('susu luma',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                  letterSpacing: -1,
                  color: ink)),
          const SizedBox(height: 6),
          const Text(
              'Source and sell across Sierra Leone — request quotes, agree orders and track delivery.',
              style: TextStyle(color: muted, height: 1.4)),
          const SizedBox(height: 28),
          const Text('Prototype sign-in',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Choose a demo persona. No account or password is needed.',
              style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 12),
          _persona(Icons.shopping_bag_outlined, 'Continue as buyer',
              buyerBusiness.name, () => store.signIn(Role.buyer)),
          _persona(
              Icons.local_shipping_outlined,
              'Continue as supplier',
              store.supplier(supplierSelf).name,
              () => store.signIn(Role.supplier)),
          const Disclaimer(
              'Sample data only. Susu Luma is a marketplace and does not sell the listed products. No payments, escrow or wallet services are enabled. Real sign-in and verification arrive with the secure backend.'),
        ]),
      ),
    );
  }

  Widget _persona(
          IconData icon, String title, String subtitle, VoidCallback onTap) =>
      AppCard(
        onTap: onTap,
        child: Row(children: [
          Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: const Color(0xFFE5EEE6),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: green)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(subtitle,
                    style: const TextStyle(color: muted, fontSize: 12))
              ])),
          const Icon(Icons.chevron_right_rounded, color: muted),
        ]),
      );
}

/// Live mode: email + password against Supabase Auth. Roles are never chosen here — they come from the
/// organisation the user belongs to.
class LiveSignInScreen extends StatefulWidget {
  const LiveSignInScreen({super.key});
  @override
  State<LiveSignInScreen> createState() => _LiveSignInScreenState();
}

class _LiveSignInScreenState extends State<LiveSignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  bool _register = false, _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(LiveAppStore store) async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_register) {
        final active =
            await store.registerWithPassword(_email.text, _password.text);
        if (!active && mounted) {
          setState(() => _message =
              'Check your email to confirm your account, then sign in.');
        }
      } else {
        await store.signInWithPassword(_email.text, _password.text);
      }
    } catch (e) {
      if (mounted) setState(() => _message = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context) as LiveAppStore;
    return Scaffold(
      body: SafeArea(
          child: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 24),
          const Text('susu luma',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                  letterSpacing: -1,
                  color: ink)),
          const SizedBox(height: 6),
          Text(
              _register
                  ? 'Create your account'
                  : 'Sign in to your business account',
              style: const TextStyle(color: muted)),
          const SizedBox(height: 24),
          TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) =>
                  (v ?? '').contains('@') ? null : 'Enter a valid email'),
          const SizedBox(height: 12),
          TextFormField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) =>
                  (v ?? '').length >= 8 ? null : 'At least 8 characters'),
          if (_message != null)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_message!,
                    style: const TextStyle(color: Color(0xFF8C1D16)))),
          const SizedBox(height: 18),
          FilledButton(
              onPressed: _busy ? null : () => _submit(store),
              child: Text(_busy
                  ? 'Please wait…'
                  : (_register ? 'Create account' : 'Sign in'))),
          TextButton(
              onPressed:
                  _busy ? null : () => setState(() => _register = !_register),
              child: Text(_register
                  ? 'I already have an account'
                  : 'Create an account')),
          const Disclaimer(
              'Susu Luma is a marketplace and does not sell the listed products. No payments, escrow or wallet services are provided.'),
        ]),
      )),
    );
  }
}

/// Shown after sign-in when the user belongs to no business yet.
class CreateBusinessScreen extends StatefulWidget {
  const CreateBusinessScreen({super.key});
  @override
  State<CreateBusinessScreen> createState() => _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends State<CreateBusinessScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  Role _type = Role.buyer;
  String _district = 'Western Area Urban';
  bool _busy = false;
  static const districts = [
    'Western Area Urban',
    'Western Area Rural',
    'Bo',
    'Bombali',
    'Kenema',
    'Kono',
    'Port Loko',
    'Other district'
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context) as LiveAppStore;
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your business'), actions: [
        TextButton(onPressed: store.signOut, child: const Text('Sign out')),
      ]),
      body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Text('Signed in as ${store.email ?? ''}',
                style: const TextStyle(color: muted)),
            const SizedBox(height: 16),
            TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Business name'),
                validator: (v) => (v ?? '').trim().length >= 2
                    ? null
                    : 'Enter your business name'),
            const SizedBox(height: 12),
            SegmentedButton<Role>(segments: const [
              ButtonSegment(value: Role.buyer, label: Text('I buy')),
              ButtonSegment(value: Role.supplier, label: Text('I supply')),
            ], selected: {
              _type
            }, onSelectionChanged: (s) => setState(() => _type = s.first)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
                initialValue: _district,
                decoration: const InputDecoration(labelText: 'District'),
                items: [
                  for (final d in districts)
                    DropdownMenuItem(value: d, child: Text(d))
                ],
                onChanged: (v) => setState(() => _district = v ?? _district)),
            const SizedBox(height: 18),
            FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        if (!_form.currentState!.validate()) return;
                        setState(() => _busy = true);
                        await guarded(
                            context,
                            () => store.createOrganization(
                                name: _name.text.trim(),
                                type: _type,
                                district: _district));
                        if (mounted) setState(() => _busy = false);
                      },
                child: Text(_busy ? 'Creating…' : 'Create business')),
            const Disclaimer(
                'Suppliers are reviewed before a verified badge is shown. Verification confirms the evidence reviewed, not any product or transaction.'),
          ])),
    );
  }
}
