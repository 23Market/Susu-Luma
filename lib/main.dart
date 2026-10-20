import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin/admin_route_gate.dart';
import 'auth/auth_page.dart';
import 'auth/mfa_page.dart';
import 'auth/organization_onboarding_page.dart';
import 'auth/password_recovery_pages.dart';
import 'config/app_config.dart';
import 'models/rfq_draft.dart';
import 'services/backend_runtime.dart';
import 'services/auth_api_client.dart';
import 'widgets/luma_brand.dart';
import 'widgets/rfq_composer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await BackendRuntime.initialize(AppConfig.fromEnvironment());
  runApp(SusuLumaApp(backend: backend));
}

const _green = Color(0xFF176B50);
const _ink = Color(0xFF17251F);
const _muted = Color(0xFF68766F);
const _canvas = Color(0xFFF5F7F4);

class SusuLumaApp extends StatelessWidget {
  const SusuLumaApp({
    super.key,
    this.backend = const BackendRuntime.offline(),
  });

  final BackendRuntime backend;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Luma Industrial Marketplace',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: _canvas,
          colorScheme: ColorScheme.fromSeed(seedColor: _green),
          appBarTheme: const AppBarTheme(
              backgroundColor: _canvas, foregroundColor: _ink),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        home: MarketplaceShell(backend: backend),
        routes: {
          '/admin': (context) =>
              AdminRouteGate(backendAvailable: backend.isAvailable),
          '/forgot-password': (context) => const ForgotPasswordPage(),
          '/reset-password': (context) => const PasswordResetPage(),
        },
      );
}

class Product {
  const Product(
      {required this.name,
      required this.category,
      required this.supplier,
      required this.location,
      required this.price,
      required this.unit,
      required this.icon,
      required this.color,
      this.verified = false});
  final String name, category, supplier, location, price, unit;
  final IconData icon;
  final Color color;
  final bool verified;
}

// Clearly labelled sample listings; replace with reviewed marketplace data at integration gate.
const _products = <Product>[
  Product(
      name: 'Portland Cement',
      category: 'Construction',
      supplier: 'Freetown Building Supply',
      location: 'Western Area',
      price: 'Request quote',
      unit: 'per bag',
      icon: Icons.foundation_rounded,
      color: Color(0xFFE6EDE6),
      verified: true),
  Product(
      name: 'Fresh Cocoa Beans',
      category: 'Agriculture',
      supplier: 'Kono Produce Traders',
      location: 'Kono District',
      price: 'Request quote',
      unit: 'per kg',
      icon: Icons.grass_rounded,
      color: Color(0xFFF0E7D8)),
  Product(
      name: 'Iron Rods · 12 mm',
      category: 'Metals',
      supplier: 'Salone Steel & Hardware',
      location: 'Freetown',
      price: 'Request quote',
      unit: 'per length',
      icon: Icons.construction_rounded,
      color: Color(0xFFE2E9F1)),
  Product(
      name: 'Cassava Flour',
      category: 'Agriculture',
      supplier: 'Bo Agro Cooperative',
      location: 'Bo District',
      price: 'Request quote',
      unit: 'per 25 kg sack',
      icon: Icons.inventory_2_rounded,
      color: Color(0xFFF2E8C9)),
];

class MarketplaceShell extends StatefulWidget {
  const MarketplaceShell({super.key, required this.backend});

  final BackendRuntime backend;
  @override
  State<MarketplaceShell> createState() => _MarketplaceShellState();
}

class _MarketplaceShellState extends State<MarketplaceShell> {
  int _tab = 0;
  String _query = '';
  String _category = 'All';
  final Set<String> _saved = {};
  final List<String> _rfqs = [];
  final List<String> _messages = [];

  List<Product> get _filtered => _products.where((p) {
        final text =
            '${p.name} ${p.category} ${p.supplier} ${p.location}'.toLowerCase();
        return text.contains(_query.toLowerCase()) &&
            (_category == 'All' || p.category == _category);
      }).toList();

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _home(),
      _discover(),
      _activity('My RFQs', Icons.request_quote_rounded, _rfqs,
          'Your quote requests will appear here.', 'Create RFQ'),
      _activity('Messages', Icons.chat_bubble_outline_rounded, _messages,
          'Supplier conversations will appear here.', 'Start an inquiry'),
      _profile(),
    ];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const LumaBrand(height: 45),
        actions: [
          IconButton(
              tooltip: 'Notifications',
              onPressed: () => _notice(
                  'Notifications will be available after backend integration.'),
              icon: const Icon(Icons.notifications_none_rounded)),
          const SizedBox(width: 8)
        ],
      ),
      body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.search_rounded), label: 'Discover'),
          NavigationDestination(
              icon: Icon(Icons.request_quote_outlined), label: 'RFQs'),
          NavigationDestination(
              icon: Icon(Icons.forum_outlined), label: 'Messages'),
          NavigationDestination(
              icon: Icon(Icons.business_center_outlined), label: 'Business'),
        ],
      ),
    );
  }

  Widget _home() => ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [_green, Color(0xFF0D503B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'BUY · SELL · SOURCE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Business starts\nwith a better connection.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 27,
                    height: 1.12,
                    letterSpacing: -.7,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Discover suppliers and source products across Sierra Leone.',
                  style: TextStyle(
                    color: Color(0xFFE2F0E9),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => setState(() => _tab = 1),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _green,
                  ),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Find products'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Browse categories',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: _ink,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _tab = 1),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _categoryTile(
                  'Construction',
                  Icons.foundation_rounded,
                  const Color(0xFFE5EEE6),
                ),
                _categoryTile(
                  'Agriculture',
                  Icons.eco_rounded,
                  const Color(0xFFF2EAD7),
                ),
                _categoryTile(
                  'Metals',
                  Icons.handyman_rounded,
                  const Color(0xFFE1EAF2),
                ),
                _categoryTile(
                  'Equipment',
                  Icons.precision_manufacturing_rounded,
                  const Color(0xFFECE4F2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Featured sourcing',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                'Sample listings',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._products.take(3).map((product) => _productCard(product)),
          const SizedBox(height: 8),
          const Text(
            'Prototype notice: listings and supplier details are illustrative sample data, not live offers.',
            style: TextStyle(fontSize: 11, color: _muted, height: 1.4),
          ),
        ],
      );

  Widget _categoryTile(String title, IconData icon, Color color) => Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
          onTap: () {
            setState(() {
              _category = title;
              _tab = 1;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
              width: 105,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE7ECE8))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(icon, color: _green, size: 19)),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700))
                  ]))));

  Widget _discover() =>
      ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
        const Text('Discover products',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 25, color: _ink)),
        const SizedBox(height: 6),
        const Text('Find the right supplier for your business.',
            style: TextStyle(color: _muted)),
        const SizedBox(height: 18),
        TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Product, material or supplier'),
            onChanged: (value) => setState(() => _query = value)),
        const SizedBox(height: 14),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'All',
              'Construction',
              'Agriculture',
              'Metals',
              'Equipment'
            ]
                .map((c) => ChoiceChip(
                        label: Text(c),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c))
                    .copyWith())
                .toList()),
        const SizedBox(height: 12),
        Text('${_filtered.length} sample listings',
            style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 8),
        if (_filtered.isEmpty)
          const Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                  'No sample listings match. Try another search or category.')),
        ..._filtered.map(_productCard),
      ]);

  Widget _productCard(Product p) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE7ECE8))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 82,
            height: 88,
            decoration: BoxDecoration(
                color: p.color, borderRadius: BorderRadius.circular(13)),
            child: Icon(p.icon, color: _green, size: 32)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.category.toUpperCase(),
              style: const TextStyle(
                  fontSize: 9,
                  color: _muted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(p.name,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 5),
          Row(children: [
            Flexible(
                child: Text(p.supplier,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: _muted))),
            if (p.verified)
              const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.verified_rounded, color: _green, size: 13))
          ]),
          const SizedBox(height: 3),
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 12, color: _muted),
            const SizedBox(width: 2),
            Text(p.location,
                style: const TextStyle(fontSize: 10, color: _muted))
          ]),
          const SizedBox(height: 8),
          Text(p.price,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 12, color: _green)),
          Text('Indicative unit: ${p.unit}',
              style: const TextStyle(fontSize: 10, color: _muted)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            OutlinedButton(
                onPressed: () => _createRfq(p),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact),
                child: const Text('Request quote',
                    style: TextStyle(fontSize: 11))),
            IconButton(
                tooltip:
                    _saved.contains(p.name) ? 'Remove saved item' : 'Save item',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _saved.contains(p.name)
                    ? _saved.remove(p.name)
                    : _saved.add(p.name)),
                icon: Icon(
                    _saved.contains(p.name)
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: _green))
          ]),
        ])),
      ]));

  Future<void> _createRfq(Product p) async {
    final draft = await showDialog<RfqDraft>(
      context: context,
      builder: (context) => RfqComposer(
        productName: p.name,
        supplierName: p.supplier,
        suggestedUnit: p.unit,
      ),
    );
    if (!mounted || draft == null) return;

    final item = draft.items.single;
    setState(() {
      _rfqs.insert(
        0,
        '${item.productName} · ${item.quantity} ${item.unit} · ${draft.deliveryLocation}',
      );
      _messages.insert(0, 'Inquiry draft for ${p.supplier}');
      _tab = 2;
    });
    _notice('Local RFQ draft saved. It has not been sent to the supplier.');
  }

  Widget _activity(String title, IconData icon, List<String> items,
          String empty, String action) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 25, color: _ink)),
        const SizedBox(height: 8),
        const Text('Keep sourcing activity organised in one place.',
            style: TextStyle(color: _muted)),
        const SizedBox(height: 20),
        if (items.isEmpty)
          Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                        color: const Color(0xFFE5EEE6),
                        borderRadius: BorderRadius.circular(18)),
                    child: Icon(icon, color: _green, size: 29)),
                const SizedBox(height: 14),
                Text(empty,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _muted)),
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: () => setState(() => _tab = 1),
                    child: Text(action))
              ]))
        else
          ...items.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Icon(icon, color: _green),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(item,
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                const Icon(Icons.chevron_right_rounded, color: _muted)
              ]))),
        const SizedBox(height: 12),
        const Text('Local prototype only. Activity is not synced or persisted.',
            style: TextStyle(fontSize: 11, color: _muted)),
      ]);

  Widget _profile() {
    final backendAvailable = widget.backend.isAvailable;
    final user = backendAvailable && !kIsWeb
        ? Supabase.instance.client.auth.currentUser
        : null;
    final userEmail =
        kIsWeb ? AuthApiClient.instance.currentEmail : user?.email;
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Business profile',
          style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 25, color: _ink)),
      const SizedBox(height: 8),
      const Text('Set up your business identity to start sourcing.',
          style: TextStyle(color: _muted)),
      const SizedBox(height: 20),
      Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            const CircleAvatar(
                radius: 32,
                backgroundColor: Color(0xFFE5EEE6),
                child: Icon(Icons.business_rounded, size: 32, color: _green)),
            const SizedBox(height: 12),
            Text(userEmail ?? 'Your business',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 5),
            Text(
                backendAvailable
                    ? userEmail == null
                        ? 'Sign in to create or join a business organisation.'
                        : 'Signed in. Organisation onboarding and verification remain controlled workflows.'
                    : 'Backend configuration is required before sign-in is enabled.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, height: 1.4)),
            const SizedBox(height: 14),
            FilledButton(
                onPressed: backendAvailable
                    ? userEmail == null
                        ? () async {
                            await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => const AuthPage()));
                            if (mounted) setState(() {});
                          }
                        : () async {
                            if (kIsWeb) {
                              await AuthApiClient.instance.logout();
                            } else {
                              await Supabase.instance.client.auth.signOut();
                            }
                            if (mounted) setState(() {});
                          }
                    : () => _notice(
                        'Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY at build time.'),
                child:
                    Text(userEmail == null ? 'Sign in / Register' : 'Sign out'))
          ])),
      const SizedBox(height: 16),
      _profileRow(
          Icons.bookmarks_outlined,
          'Saved products',
          '${_saved.length} saved',
          () => _notice(_saved.isEmpty
              ? 'You have no saved sample products yet.'
              : _saved.join(', '))),
      if (backendAvailable && userEmail != null)
        _profileRow(Icons.add_business_rounded, 'Set up an organisation',
            'Create your buyer or supplier business identity', () async {
          final created = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                  builder: (_) => const OrganizationOnboardingPage()));
          if (created == true) {
            _notice('Organisation created. You are its owner.');
          }
        }),
      if (backendAvailable && userEmail != null)
        _profileRow(
            Icons.phonelink_lock_rounded,
            'Two-factor authentication',
            'Authenticator app and one-time backup codes',
            () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const MfaPage()),
                )),
      _profileRow(
          Icons.space_dashboard_outlined,
          'Admin dashboard',
          'Open the local business operations demo',
          () => Navigator.of(context).pushNamed('/admin')),
      _profileRow(
          Icons.verified_user_outlined,
          'Supplier verification',
          'Review process required',
          () => _notice(
              'Verification is not live. No supplier is verified by this prototype.')),
      _profileRow(
          Icons.help_outline_rounded,
          'Help & support',
          'Support centre',
          () => _notice(
              'Support contact and escalation policy must be configured before pilot.')),
      const SizedBox(height: 16),
      const Text(
          'Susu Luma is a marketplace and does not itself sell the listed products. No payments, escrow or wallet services are enabled.',
          style: TextStyle(color: _muted, fontSize: 11, height: 1.5)),
    ]);
  }

  Widget _profileRow(
          IconData icon, String title, String subtitle, VoidCallback onTap) =>
      Card(
          color: Colors.white,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
              leading: Icon(icon, color: _green),
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onTap));

  void _notice(String message) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

extension on Widget {
  Widget copyWith() => this;
}
