import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
const _yellow = Color(0xFFFFC400);
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

// Illustrative Sierra Leone-focused sample listings. These are not live offers; verify suppliers, availability and specifications before publication.
const _products = <Product>[
  Product(
      name: 'Portland Cement',
      category: 'Construction',
      supplier: 'Freetown Building Supply',
      location: 'Western Area',
      price: 'Request quote',
      unit: 'per bag',
      icon: Icons.foundation_rounded,
      color: Color(0xFFE6EDE6)),
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
      name: 'Cocoa Beans',
      category: 'Agriculture',
      supplier: 'Kono Produce Traders',
      location: 'Kono District',
      price: 'Request quote',
      unit: 'per kg',
      icon: Icons.grass_rounded,
      color: Color(0xFFF0E7D8)),
  Product(
      name: 'Cassava Flour',
      category: 'Agriculture',
      supplier: 'Bo Agro Cooperative',
      location: 'Bo District',
      price: 'Request quote',
      unit: 'per 25 kg sack',
      icon: Icons.inventory_2_rounded,
      color: Color(0xFFF2E8C9)),
  Product(
      name: 'Palm Oil',
      category: 'Food & Agro-Processing',
      supplier: 'Southern Produce Network',
      location: 'Pujehun District',
      price: 'Request quote',
      unit: 'per 20 litre container',
      icon: Icons.oil_barrel_rounded,
      color: Color(0xFFF5E8C8)),
  Product(
      name: 'Rice · Local Harvest',
      category: 'Food & Agro-Processing',
      supplier: 'Rural Rice Traders',
      location: 'Moyamba District',
      price: 'Request quote',
      unit: 'per 50 kg bag',
      icon: Icons.grain_rounded,
      color: Color(0xFFF2EAD7)),
  Product(
      name: 'Bauxite Ore',
      category: 'Mining & Minerals',
      supplier: 'Sierra Mineral Sourcing',
      location: 'Port Loko District',
      price: 'Request quote',
      unit: 'per metric tonne',
      icon: Icons.landscape_rounded,
      color: Color(0xFFECE4D8)),
  Product(
      name: 'Rutile / Ilmenite Feedstock',
      category: 'Mining & Minerals',
      supplier: 'Coastal Minerals Exchange',
      location: 'Bonthe District',
      price: 'Request quote',
      unit: 'per metric tonne',
      icon: Icons.diamond_outlined,
      color: Color(0xFFE5E7EB)),
  Product(
      name: 'Sawn Timber',
      category: 'Timber & Wood',
      supplier: 'Eastern Timber Suppliers',
      location: 'Kenema District',
      price: 'Request quote',
      unit: 'per cubic metre',
      icon: Icons.forest_rounded,
      color: Color(0xFFEDE4D6)),
  Product(
      name: 'Fresh Fish · Bulk Supply',
      category: 'Fisheries & Seafood',
      supplier: 'Western Coastal Fisheries',
      location: 'Tombo, Western Area Rural',
      price: 'Request quote',
      unit: 'per crate',
      icon: Icons.set_meal_rounded,
      color: Color(0xFFDDECF0)),
  Product(
      name: 'Solar Panels',
      category: 'Energy & Solar',
      supplier: 'Salone Solar Trade',
      location: 'Freetown',
      price: 'Request quote',
      unit: 'per panel',
      icon: Icons.solar_power_rounded,
      color: Color(0xFFF6EBCB)),
  Product(
      name: 'Diesel Generator',
      category: 'Equipment & Power',
      supplier: 'Industrial Equipment SL',
      location: 'Freetown',
      price: 'Request quote',
      unit: 'per unit',
      icon: Icons.electric_bolt_rounded,
      color: Color(0xFFE5E8EC)),
  Product(
      name: 'Water Storage Tanks',
      category: 'Water & Sanitation',
      supplier: 'Salone Water Systems',
      location: 'Makeni, Bombali District',
      price: 'Request quote',
      unit: 'per tank',
      icon: Icons.water_drop_rounded,
      color: Color(0xFFDDECF0)),
  Product(
      name: 'Woven Raffia & Crafts',
      category: 'Local Crafts & Textiles',
      supplier: 'Community Craft Collective',
      location: 'Kailahun District',
      price: 'Request quote',
      unit: 'per bundle',
      icon: Icons.shopping_basket_rounded,
      color: Color(0xFFEDE4D6)),
  Product(
      name: 'Corrugated Roofing Sheets',
      category: 'Construction',
      supplier: 'Freetown Building Supply',
      location: 'Western Area',
      price: 'Request quote',
      unit: 'per sheet',
      icon: Icons.roofing_rounded,
      color: Color(0xFFE6EDE6)),
  Product(
      name: 'Plastic Packaging & Sacks',
      category: 'Packaging & Supplies',
      supplier: 'National Packaging Traders',
      location: 'Freetown',
      price: 'Request quote',
      unit: 'per bundle',
      icon: Icons.inventory_2_rounded,
      color: Color(0xFFE5EAF3)),
  Product(
      name: 'Paddy Rice',
      category: 'Food Crops',
      supplier: 'Illustrative Rice Supplier',
      location: 'Bombali District',
      price: 'Request quote',
      unit: 'per 50 kg bag',
      icon: Icons.grain_rounded,
      color: Color(0xFFF2EAD7)),
  Product(
      name: 'Groundnuts',
      category: 'Food Crops',
      supplier: 'Illustrative Crop Cooperative',
      location: 'Tonkolili District',
      price: 'Request quote',
      unit: 'per 25 kg sack',
      icon: Icons.spa_rounded,
      color: Color(0xFFF0E7D8)),
  Product(
      name: 'Coffee Beans',
      category: 'Cash Crops',
      supplier: 'Illustrative Cash Crop Trader',
      location: 'Kailahun District',
      price: 'Request quote',
      unit: 'per kg',
      icon: Icons.coffee_rounded,
      color: Color(0xFFEDE4D6)),
  Product(
      name: 'Pineapples',
      category: 'Horticulture',
      supplier: 'Illustrative Produce Grower',
      location: 'Western Area Rural',
      price: 'Request quote',
      unit: 'per crate',
      icon: Icons.spa_rounded,
      color: Color(0xFFF6EBCB)),
  Product(
      name: 'Tomatoes',
      category: 'Horticulture',
      supplier: 'Illustrative Market Gardener',
      location: 'Bo District',
      price: 'Request quote',
      unit: 'per crate',
      icon: Icons.eco_rounded,
      color: Color(0xFFF5E8C8)),
  Product(
      name: 'Fertilizer',
      category: 'Agro-Inputs',
      supplier: 'Illustrative Agricultural Inputs Dealer',
      location: 'Makeni, Bombali District',
      price: 'Request quote',
      unit: 'per 50 kg bag',
      icon: Icons.grass_rounded,
      color: Color(0xFFE6EDE6)),
  Product(
      name: 'Irrigation Pump',
      category: 'Farm Machinery',
      supplier: 'Illustrative Farm Equipment Dealer',
      location: 'Freetown',
      price: 'Request quote',
      unit: 'per unit',
      icon: Icons.water_rounded,
      color: Color(0xFFDDECF0)),
  Product(
      name: 'Animal Feed',
      category: 'Livestock & Veterinary',
      supplier: 'Illustrative Livestock Supplier',
      location: 'Kenema District',
      price: 'Request quote',
      unit: 'per 25 kg bag',
      icon: Icons.pets_rounded,
      color: Color(0xFFEDE4D6)),
  Product(
      name: 'Rice Milling Machine',
      category: 'Agro-Processing',
      supplier: 'Illustrative Processing Equipment Dealer',
      location: 'Bo District',
      price: 'Request quote',
      unit: 'per machine',
      icon: Icons.precision_manufacturing_rounded,
      color: Color(0xFFE5E8EC)),
  Product(
      name: 'Reusable Produce Crates',
      category: 'Packaging & Supplies',
      supplier: 'Illustrative Packaging Supplier',
      location: 'Freetown',
      price: 'Request quote',
      unit: 'per crate',
      icon: Icons.inventory_2_rounded,
      color: Color(0xFFE5EAF3)),
];

class MarketplaceShell extends StatefulWidget {
  const MarketplaceShell({super.key, required this.backend});

  final BackendRuntime backend;
  @override
  State<MarketplaceShell> createState() => _MarketplaceShellState();
}

class _MarketplaceShellState extends State<MarketplaceShell> {
  final FlutterTts _tts = FlutterTts();
  int _tab = 0;
  String _query = '';
  String _category = 'All';
  bool _krioAudio = false;
  bool _speaking = false;
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
  void dispose() {
    unawaited(_tts.stop());
    super.dispose();
  }

  Future<void> _playHomeGuide() async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }

    setState(() => _speaking = true);
    try {
      await _tts.stop();
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.42);
      await _tts.setVolume(1);
      await _tts.speak(
        _krioAudio
            ? 'Tap di Find products button, or tap wan picture for wetin yu de look for. Tap Ask for price for ask wan seller how much. Tap Sell an item for put you business pan Luma.'
            : 'Tap Find products, or choose a picture for building, farming, tools, or food. Tap Ask for price to request a quote. Tap Sell an item to list a product.',
      );
    } on Object {
      if (mounted) {
        _notice('Audio guidance is unavailable on this device.');
      }
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

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
        selectedIndex: switch (_tab) {
          2 => 1,
          3 => 2,
          4 => 3,
          _ => 0,
        },
        onDestinationSelected: (value) =>
            setState(() => _tab = const [0, 2, 3, 4][value]),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined), label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.forum_outlined), label: 'Messages'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded), label: 'Account'),
        ],
      ),
    );
  }

  Widget _home() => ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('English')),
                    ButtonSegment(value: true, label: Text('Krio')),
                  ],
                  selected: {_krioAudio},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      setState(() => _krioAudio = selection.first),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _playHomeGuide,
                icon: Icon(
                  _speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                ),
                label: Text(_speaking ? 'Stop' : 'Listen'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: 'Find products',
            child: InkWell(
              onTap: () => setState(() => _tab = 1),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                constraints: const BoxConstraints(minHeight: 76),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F2EC),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _green,
                      child: Icon(Icons.search_rounded,
                          color: Colors.white, size: 28),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Find products',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: _green),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Choose a category',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.28,
            children: [
              _visualCategoryTile(
                label: 'BUILDING',
                category: 'Construction',
                icon: Icons.foundation_rounded,
                background: const Color(0xFFFFD54F),
              ),
              _visualCategoryTile(
                label: 'FARMING',
                category: 'Agriculture',
                icon: Icons.eco_rounded,
                background: const Color(0xFFD9EEE1),
              ),
              _visualCategoryTile(
                label: 'TOOLS',
                category: 'Equipment & Power',
                icon: Icons.handyman_rounded,
                background: const Color(0xFFFAD9D6),
              ),
              _visualCategoryTile(
                label: 'FOOD',
                category: 'Food & Agro-Processing',
                icon: Icons.rice_bowl_rounded,
                background: const Color(0xFFFFE9A9),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _primaryHomeAction(
                  label: 'ASK FOR\nPRICE',
                  icon: Icons.request_quote_rounded,
                  color: _green,
                  foreground: Colors.white,
                  onTap: () {
                    setState(() => _tab = 1);
                    _notice('Choose a product to request a quote.');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _primaryHomeAction(
                  label: 'SELL AN\nITEM',
                  icon: Icons.storefront_rounded,
                  color: _yellow,
                  foreground: _green,
                  onTap: () {
                    setState(() => _tab = 4);
                    _notice(
                        'Sign in with a business account to list products.');
                  },
                ),
              ),
            ],
          ),
        ],
      );

  Widget _visualCategoryTile({
    required String label,
    required String category,
    required IconData icon,
    required Color background,
  }) =>
      Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: () => setState(() {
            _category = category;
            _tab = 1;
          }),
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: _green, size: 48),
                const SizedBox(height: 9),
                Text(
                  label,
                  style: const TextStyle(
                    color: _green,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _primaryHomeAction({
    required String label,
    required IconData icon,
    required Color color,
    required Color foreground,
    required VoidCallback onTap,
  }) =>
      Semantics(
        button: true,
        label: label.replaceAll('\n', ' '),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            height: 104,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Icon(icon, color: foreground, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 16,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _discover() => ListView(
          key: const Key('discover-list'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const Text('Browse Sierra Leone listings',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 25, color: _ink)),
            const SizedBox(height: 6),
            const Text(
                'Explore local materials, produce and industrial supplies by category and district.',
                style: TextStyle(color: _muted)),
            const SizedBox(height: 18),
            TextField(
                key: const Key('discover-search'),
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
                  'Food Crops',
                  'Cash Crops',
                  'Horticulture',
                  'Agro-Inputs',
                  'Farm Machinery',
                  'Livestock & Veterinary',
                  'Agro-Processing',
                  'Metals',
                  'Equipment & Power',
                  'Mining & Minerals',
                  'Timber & Wood',
                  'Fisheries & Seafood',
                  'Food & Agro-Processing',
                  'Energy & Solar',
                  'Water & Sanitation',
                  'Local Crafts & Textiles',
                  'Packaging & Supplies'
                ]
                    .map((c) => ChoiceChip(
                            label: Text(c),
                            selected: _category == c,
                            onSelected: (_) => setState(() => _category = c))
                        .copyWith())
                    .toList()),
            const SizedBox(height: 12),
            Text('${_filtered.length} illustrative sample listings',
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
