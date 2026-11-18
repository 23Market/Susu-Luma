// ignore: deprecated_member_use -- Flutter 3.50 prefers material_ui; keep the SDK-wide import until the project migrates.
import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';
import '../ui.dart';
import 'buyer.dart' show categories, supplierAppBar;
import 'common.dart';

class SupplierShell extends StatefulWidget {
  const SupplierShell({super.key});
  @override
  State<SupplierShell> createState() => _SupplierShellState();
}

class _SupplierShellState extends State<SupplierShell> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pages = <Widget>[
      _Dashboard(onTab: (i) => setState(() => _tab = i)),
      const _Listings(),
      const RfqsTab(),
      const OrdersTab(),
      const MessagesTab()
    ];
    return Scaffold(
      appBar: supplierAppBar(
          context, 'Supplier · ${store.supplier(supplierSelf).name}'),
      body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            const NavigationDestination(
                icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
            const NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined), label: 'Listings'),
            NavigationDestination(
                icon: Badge(
                    isLabelVisible: store.myRfqs
                        .any((r) => r.status == RfqStatus.submitted),
                    child: const Icon(Icons.inbox_outlined)),
                label: 'RFQs'),
            NavigationDestination(
                icon: Badge(
                    isLabelVisible: store.myOrders.any((o) =>
                        o.status == OrderStatus.awaitingSellerConfirmation),
                    child: const Icon(Icons.local_shipping_outlined)),
                label: 'Orders'),
            const NavigationDestination(
                icon: Icon(Icons.forum_outlined), label: 'Messages'),
          ]),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.onTab});
  final ValueChanged<int> onTab;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final needQuote =
        store.myRfqs.where((r) => r.status == RfqStatus.submitted).length;
    final toConfirm = store.myOrders
        .where((o) => o.status == OrderStatus.awaitingSellerConfirmation)
        .length;
    final inFlight = store.myOrders
        .where((o) =>
            o.status == OrderStatus.inFulfilment ||
            o.status == OrderStatus.confirmed)
        .length;
    final pending = store.myListings.where((p) => !p.published).length;
    Widget tile(String n, String l, int tab, {bool hot = false}) => Expanded(
        child: AppCard(
            margin: EdgeInsets.zero,
            onTap: () => onTab(tab),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n,
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: hot ? const Color(0xFFB7791F) : green)),
              Text(l, style: const TextStyle(fontSize: 11, color: muted))
            ])));
    return ListView(padding: const EdgeInsets.all(20), children: [
      const PageTitle('Dashboard', 'What needs your attention today.'),
      Row(children: [
        tile('$needQuote', 'RFQs awaiting your quote', 2, hot: needQuote > 0),
        const SizedBox(width: 12),
        tile('$toConfirm', 'Orders to confirm', 3, hot: toConfirm > 0)
      ]),
      const SizedBox(height: 12),
      Row(children: [
        tile('$inFlight', 'Orders in progress', 3),
        const SizedBox(width: 12),
        tile('$pending', 'Listings in review', 1)
      ]),
      const SizedBox(height: 16),
      const AppCard(
          child: Row(children: [
        Icon(Icons.verified_rounded, color: green),
        SizedBox(width: 12),
        Expanded(
            child: Text(
                'Verification approved for business registration (sample). Evidence review is scoped and time-limited.',
                style: TextStyle(fontSize: 12)))
      ])),
      const Disclaimer('Prototype: figures reflect this device only.'),
    ]);
  }
}

class _Listings extends StatelessWidget {
  const _Listings();
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ListView(padding: const EdgeInsets.all(20), children: [
      const PageTitle('My listings',
          'New listings are reviewed before they appear to buyers.'),
      FilledButton.icon(
          onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => _ListingForm(store: store)),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add listing')),
      const SizedBox(height: 14),
      for (final p in store.myListings)
        AppCard(
            child: Row(children: [
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: p.color, borderRadius: BorderRadius.circular(12)),
              child: Icon(p.icon, color: green)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(p.name,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${p.category} · per ${p.unit}',
                    style: const TextStyle(fontSize: 12, color: muted))
              ])),
          StatusChip(p.published ? 'Published' : 'Pending review',
              tone: p.published ? ChipTone.good : ChipTone.warn),
        ])),
    ]);
  }
}

class _ListingForm extends StatefulWidget {
  const _ListingForm({required this.store});
  final AppStore store;
  @override
  State<_ListingForm> createState() => _ListingFormState();
}

class _ListingFormState extends State<_ListingForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _unit = TextEditingController(),
      _price = TextEditingController();
  String _cat = 'Construction';
  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
            key: _form,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('New listing',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _name,
                      decoration:
                          const InputDecoration(labelText: 'Product name'),
                      validator: (v) => (v ?? '').trim().length >= 3
                          ? null
                          : 'At least 3 characters'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                      initialValue: _cat,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final c in categories.skip(1))
                          DropdownMenuItem(value: c, child: Text(c))
                      ],
                      onChanged: (v) => _cat = v ?? _cat),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: _unit,
                      decoration: const InputDecoration(
                          labelText: 'Unit (e.g. bag, kg, day)'),
                      validator: (v) =>
                          (v ?? '').trim().isNotEmpty ? null : 'Required'),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: _price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Indicative price in SLE (optional)'),
                      validator: (v) =>
                          (v ?? '').isEmpty || (double.tryParse(v!) ?? -1) >= 0
                              ? null
                              : 'Invalid amount'),
                  const SizedBox(height: 14),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: () {
                            if (!_form.currentState!.validate()) return;
                            widget.store.addListing(
                                name: _name.text.trim(),
                                category: _cat,
                                unit: _unit.text.trim(),
                                price: double.tryParse(_price.text),
                                location: widget.store
                                    .supplier(supplierSelf)
                                    .district);
                            Navigator.pop(context);
                            notice(context, 'Listing submitted for review.');
                          },
                          child: const Text('Submit for review'))),
                ]))),
      );
}
