// ignore: deprecated_member_use -- Flutter 3.50 prefers material_ui; keep the SDK-wide import until the project migrates.
import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';
import '../ui.dart';
import 'common.dart';

const categories = [
  'All',
  'Construction',
  'Agriculture',
  'Metals',
  'Equipment'
];

class BuyerShell extends StatefulWidget {
  const BuyerShell({super.key});
  @override
  State<BuyerShell> createState() => _BuyerShellState();
}

class _BuyerShellState extends State<BuyerShell> {
  int _tab = 0;
  String _query = '', _category = 'All';

  void _go(int tab, {String? category}) => setState(() {
        _tab = tab;
        if (category != null) _category = category;
      });

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pages = <Widget>[
      _Home(onTab: _go),
      _Discover(
          query: _query,
          category: _category,
          onQuery: (v) => setState(() => _query = v),
          onCategory: (v) => setState(() => _category = v)),
      RfqsTab(onBrowse: () => _go(1)),
      const OrdersTab(),
      const MessagesTab(),
    ];
    return Scaffold(
      appBar: _appBar(context, 'Buyer · ${buyerBusiness.name}'),
      body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _go,
          destinations: [
            const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home'),
            const NavigationDestination(
                icon: Icon(Icons.search_rounded), label: 'Discover'),
            NavigationDestination(
                icon: Badge(
                    isLabelVisible:
                        store.myRfqs.any((r) => r.status == RfqStatus.quoted),
                    child: const Icon(Icons.request_quote_outlined)),
                label: 'RFQs'),
            const NavigationDestination(
                icon: Icon(Icons.local_shipping_outlined), label: 'Orders'),
            const NavigationDestination(
                icon: Icon(Icons.forum_outlined), label: 'Messages'),
          ]),
    );
  }
}

PreferredSizeWidget _appBar(BuildContext context, String subtitle) => AppBar(
      titleSpacing: 20,
      title: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: green, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.storefront_rounded,
                color: Colors.white, size: 21)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('susu luma',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.6)),
          Text(subtitle.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 9,
                  letterSpacing: 1,
                  color: muted,
                  fontWeight: FontWeight.w700)),
        ])),
      ]),
      actions: [
        IconButton(
            tooltip: 'Business profile',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute<void>(builder: (_) => const ProfileScreen())),
            icon: const Icon(Icons.account_circle_outlined)),
        const SizedBox(width: 8)
      ],
    );

PreferredSizeWidget supplierAppBar(BuildContext context, String subtitle) =>
    _appBar(context, subtitle);

class _Home extends StatelessWidget {
  const _Home({required this.onTab});
  final void Function(int, {String? category}) onTab;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final quoted =
        store.myRfqs.where((r) => r.status == RfqStatus.quoted).length;
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                    colors: [green, Color(0xFF0D503B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Business starts with a better connection.',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      height: 1.12,
                      letterSpacing: -.7)),
              const SizedBox(height: 10),
              const Text(
                  'Discover suppliers and source products across Sierra Leone.',
                  style: TextStyle(color: Color(0xFFE2F0E9), height: 1.4)),
              const SizedBox(height: 18),
              FilledButton.icon(
                  onPressed: () => onTab(1),
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.white, foregroundColor: green),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Find products')),
            ]),
          ),
          if (quoted > 0)
            AppCard(
                margin: const EdgeInsets.only(top: 16),
                onTap: () => onTab(2),
                child: Row(children: [
                  const Icon(Icons.notifications_active_outlined, color: green),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(
                          '$quoted RFQ${quoted == 1 ? ' has' : 's have'} quotes waiting for your decision',
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                  const Icon(Icons.chevron_right_rounded, color: muted)
                ])),
          const SizedBox(height: 22),
          const Text('Browse categories',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 18, color: ink)),
          const SizedBox(height: 10),
          SizedBox(
              height: 92,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final c in categories.skip(1))
                  _Cat(c, onTap: () => onTab(1, category: c)),
              ])),
          const SizedBox(height: 20),
          const Row(children: [
            Expanded(
                child: Text('Featured sourcing',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: ink))),
            Text('Sample listings',
                style: TextStyle(color: muted, fontSize: 11))
          ]),
          const SizedBox(height: 12),
          for (final p in store.published.take(3)) ProductCard(p),
          const Disclaimer(
              'Prototype notice: listings and supplier details are illustrative sample data, not live offers.'),
        ]);
  }
}

class _Cat extends StatelessWidget {
  const _Cat(this.title, {required this.onTap});
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
                width: 108,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: line)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: const Color(0xFFE5EEE6),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.category_outlined,
                              color: green, size: 19)),
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ]))),
      );
}

class _Discover extends StatelessWidget {
  const _Discover(
      {required this.query,
      required this.category,
      required this.onQuery,
      required this.onCategory});
  final String query, category;
  final ValueChanged<String> onQuery, onCategory;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final results = store.search(query, category);
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const PageTitle('Discover products',
              'Find the right supplier for your business.'),
          TextField(
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Product, material or supplier'),
              onChanged: onQuery),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in categories)
              ChoiceChip(
                  label: Text(c),
                  selected: category == c,
                  onSelected: (_) => onCategory(c))
          ]),
          const SizedBox(height: 12),
          Text(
              '${results.length} sample listing${results.length == 1 ? '' : 's'}',
              style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 8),
          if (results.isEmpty)
            const Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                    'No sample listings match. Try another search or category.')),
          for (final p in results) ProductCard(p),
        ]);
  }
}

class ProductCard extends StatelessWidget {
  const ProductCard(this.p, {super.key});
  final Product p;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.supplier(p.supplierId);
    final saved = store.saved.contains(p.id);
    return AppCard(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => ProductDetailScreen(product: p))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 76,
            height: 84,
            decoration: BoxDecoration(
                color: p.color, borderRadius: BorderRadius.circular(13)),
            child: Icon(p.icon, color: green, size: 32)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.category.toUpperCase(),
              style: const TextStyle(
                  fontSize: 9,
                  color: muted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1)),
          Text(p.name,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: ink)),
          Row(children: [
            Flexible(
                child: Text(s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: muted))),
            if (s.verified)
              const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.verified_rounded,
                      color: green,
                      size: 13,
                      semanticLabel: 'Verified supplier'))
          ]),
          Text(p.location, style: const TextStyle(fontSize: 10, color: muted)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(
                child: Text(
                    p.indicativePrice == null
                        ? 'Request quote · per ${p.unit}'
                        : 'Indicative ${money(p.indicativePrice!, 'SLE')} per ${p.unit}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: green))),
            IconButton(
                tooltip: saved ? 'Remove saved item' : 'Save item',
                visualDensity: VisualDensity.compact,
                onPressed: () => store.toggleSaved(p.id),
                icon: Icon(
                    saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: green)),
          ]),
        ])),
      ]),
    );
  }
}

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.product});
  final Product product;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final p = product, s = store.supplier(p.supplierId);
    return Scaffold(
      appBar: AppBar(title: const Text('Product')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(
            height: 150,
            decoration: BoxDecoration(
                color: p.color, borderRadius: BorderRadius.circular(20)),
            child: Icon(p.icon, color: green, size: 64)),
        const SizedBox(height: 16),
        PageTitle(p.name, p.category),
        AppCard(
            child: Column(children: [
          LabelValue('Supplier', s.name),
          LabelValue('Verification',
              s.verified ? 'Verified (scope reviewed)' : 'Not yet verified'),
          LabelValue('Location', p.location),
          LabelValue('Unit', p.unit),
          LabelValue(
              'Price',
              p.indicativePrice == null
                  ? 'Quote only'
                  : 'Indicative ${money(p.indicativePrice!, 'SLE')} per ${p.unit}'),
        ])),
        const Disclaimer(
            'Indicative prices are not offers. The binding price is the quote you accept.'),
        const SizedBox(height: 8),
        FilledButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => RfqFormScreen(product: p))),
            icon: const Icon(Icons.request_quote_rounded),
            label: const Text('Request quote')),
      ]),
    );
  }
}

class RfqFormScreen extends StatefulWidget {
  const RfqFormScreen({super.key, required this.product});
  final Product product;
  @override
  State<RfqFormScreen> createState() => _RfqFormScreenState();
}

class _RfqFormScreenState extends State<RfqFormScreen> {
  final _form = GlobalKey<FormState>();
  final _qty = TextEditingController(), _notes = TextEditingController();
  String _district = 'Western Area Urban';
  DateTime? _target;
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
    _qty.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      appBar: AppBar(title: const Text('Request quote')),
      body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            PageTitle(p.name,
                'To ${StoreScope.of(context).supplier(p.supplierId).name}'),
            TextFormField(
                controller: _qty,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Quantity (${p.unit})'),
                validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0
                    ? null
                    : 'Enter a quantity above zero'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
                initialValue: _district,
                decoration:
                    const InputDecoration(labelText: 'Delivery district'),
                items: [
                  for (final d in districts)
                    DropdownMenuItem(value: d, child: Text(d))
                ],
                onChanged: (v) => setState(() => _district = v ?? _district)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.event_rounded),
                label: Text(_target == null
                    ? 'Target delivery date (optional)'
                    : shortDate(_target!))),
            const SizedBox(height: 12),
            TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Notes (specifications, access, unloading)')),
            const SizedBox(height: 18),
            FilledButton(onPressed: _submit, child: const Text('Send RFQ')),
            const Disclaimer(
                'Share only information needed for a quote. Avoid exact addresses or personal contact details until you agree an order.'),
          ])),
    );
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context,
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
        initialDate: _target ?? now.add(const Duration(days: 7)));
    if (d != null) setState(() => _target = d);
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final store = StoreScope.of(context);
    final rfq = store.createRfq(
        product: widget.product,
        quantity: double.parse(_qty.text),
        district: _district,
        notes: _notes.text.trim(),
        target: _target == null ? null : shortDate(_target!));
    Navigator.popUntil(context, (r) => r.isFirst);
    Navigator.push(context,
        MaterialPageRoute<void>(builder: (_) => RfqDetailScreen(rfq: rfq)));
    notice(context, 'RFQ ${rfq.ref} sent.');
  }
}
