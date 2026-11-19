// ignore: deprecated_member_use -- Flutter 3.50 prefers material_ui; keep the SDK-wide import until the project migrates.
import 'package:flutter/material.dart';
import 'models.dart';

const buyerBusiness = Business(
    id: 'b1', name: 'Aberdeen Construction', district: 'Western Area Urban');
const supplierSelf = 's1';

/// In-memory prototype state. Replace with Supabase-backed repositories at the integration gate;
/// privileged transitions (quote acceptance, order creation) must move to server-side RPCs.
enum AuthPhase { signedOut, needsOrganization, ready }

class AppStore extends ChangeNotifier {
  AppStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    suppliers = List.of(_demoSuppliers);
    _seed();
  }

  /// Empty store for subclasses that load real data.
  AppStore.empty({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    suppliers = <Business>[];
  }

  final DateTime Function() _clock;
  DateTime now() => _clock();
  int _seq = 100;
  String _id(String p) => '$p${_seq++}';

  /// True when backed by a real backend (see LiveAppStore).
  bool get isLive => false;

  /// Where the UI should be: sign-in, business setup, or the role shell.
  AuthPhase get phase => role == null ? AuthPhase.signedOut : AuthPhase.ready;

  /// The signed-in business (buyer or supplier, by role).
  Business get myBusiness =>
      role == Role.supplier ? supplier(supplierSelf) : buyerBusiness;

  /// Organisation id used to scope supplier-side lists.
  String get mySupplierId => supplierSelf;

  Role? role;
  static const _demoSuppliers = <Business>[
    Business(
        id: 's1',
        name: 'Freetown Building Supply',
        district: 'Western Area Urban',
        verified: true),
    Business(
        id: 's2',
        name: 'Kono Produce Traders',
        district: 'Kono',
        verified: true),
    Business(
        id: 's3',
        name: 'Salone Steel & Hardware',
        district: 'Western Area Urban'),
    Business(id: 's4', name: 'Bo Agro Cooperative', district: 'Bo'),
  ];
  late List<Business> suppliers;
  final products = <Product>[];
  final rfqs = <Rfq>[];
  final orders = <Order>[];
  final threads = <Thread>[];
  final saved = <String>{};
  String verificationStatus = 'approved'; // supplier persona (illustrative)

  Business supplier(String id) => suppliers.firstWhere((s) => s.id == id,
      orElse: () => Business(id: id, name: 'Supplier', district: ''));
  Product? productById(String id) =>
      products.where((p) => p.id == id).firstOrNull;

  // ---- session ----
  void signIn(Role r) {
    role = r;
    notifyListeners();
  }

  void signOut() {
    role = null;
    notifyListeners();
  }

  // ---- views by persona ----
  List<Product> get published => products.where((p) => p.published).toList();
  List<Product> get myListings =>
      products.where((p) => p.supplierId == mySupplierId).toList();
  List<Rfq> get myRfqs => role == Role.supplier
      ? rfqs.where((r) => r.supplierId == mySupplierId).toList()
      : rfqs;
  List<Order> get myOrders => role == Role.supplier
      ? orders.where((o) => o.supplierId == mySupplierId).toList()
      : orders;
  List<Thread> get myThreads => role == Role.supplier
      ? threads.where((t) => t.supplierId == mySupplierId).toList()
      : threads;

  List<Product> search(String query, String category) {
    final q = query.trim().toLowerCase();
    return published.where((p) {
      final text =
          '${p.name} ${p.category} ${supplier(p.supplierId).name} ${p.location}'
              .toLowerCase();
      return text.contains(q) && (category == 'All' || p.category == category);
    }).toList();
  }

  void toggleSaved(String productId) {
    saved.contains(productId) ? saved.remove(productId) : saved.add(productId);
    notifyListeners();
  }

  // ---- buyer actions ----
  Future<Rfq> createRfq(
      {required Product product,
      required double quantity,
      required String district,
      required String notes,
      DateTime? target}) async {
    final n = rfqs.length + 1;
    final rfq = Rfq(
        id: _id('r'),
        ref:
            'SL-${(0x4F2A91 + n * 7919).toRadixString(16).toUpperCase().padLeft(6, '0')}',
        productName: product.name,
        supplierId: product.supplierId,
        quantity: quantity,
        unit: product.unit,
        district: district,
        notes: notes,
        target: target == null ? null : shortDate(target));
    rfqs.insert(0, rfq);
    final thread = threads.firstWhere(
        (t) => t.supplierId == product.supplierId && t.title == product.name,
        orElse: () {
      final t = Thread(
          id: _id('t'), title: product.name, supplierId: product.supplierId);
      threads.insert(0, t);
      return t;
    });
    thread.messages.add(ChatMessage(
        Role.buyer,
        'Hello, we sent RFQ ${rfq.ref} for ${_q(quantity)} ${product.unit}. Please quote.',
        _clock()));
    notifyListeners();
    return rfq;
  }

  String _q(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> cancelRfq(Rfq rfq) async {
    if (rfq.status == RfqStatus.accepted) return;
    rfq.status = RfqStatus.cancelled;
    notifyListeners();
  }

  /// Accepts a quote: snapshots price terms into an order so later quote edits cannot change it.
  Future<Order?> acceptQuote(Rfq rfq, Quote quote) async {
    if (rfq.status != RfqStatus.quoted ||
        quote.status != QuoteStatus.submitted) {
      return null;
    }
    for (final q in rfq.quotes) {
      q.status = q == quote ? QuoteStatus.accepted : QuoteStatus.declined;
    }
    rfq.status = RfqStatus.accepted;
    final order = Order(
        id: _id('o'),
        ref: 'ORD-${(orders.length + 1).toString().padLeft(4, '0')}',
        rfqRef: rfq.ref,
        productName: rfq.productName,
        supplierId: rfq.supplierId,
        quantity: rfq.quantity,
        unit: rfq.unit,
        unitPrice: quote.unitPrice,
        currency: quote.currency,
        leadDays: quote.leadDays);
    orders.insert(0, order);
    notifyListeners();
    return order;
  }

  Future<void> reportProblem(Order o, String text) async {
    if (o.status == OrderStatus.cancelled || o.status == OrderStatus.disputed) {
      return;
    }
    o.status = OrderStatus.disputed;
    o.events.add(DeliveryEvent(
        'exception', 'Buyer reported a problem: $text', _clock()));
    notifyListeners();
  }

  // ---- supplier actions ----
  Future<Quote?> submitQuote(Rfq rfq,
      {required double unitPrice,
      required int leadDays,
      required int validDays,
      required String terms}) async {
    if (unitPrice <= 0 ||
        rfq.status == RfqStatus.accepted ||
        rfq.status == RfqStatus.cancelled) {
      return null;
    }
    final quote = Quote(
        id: _id('q'),
        unitPrice: unitPrice,
        leadDays: leadDays,
        validDays: validDays,
        terms: terms);
    for (final q in rfq.quotes) {
      if (q.status == QuoteStatus.submitted) q.status = QuoteStatus.declined;
    } // superseded revision
    rfq.quotes.add(quote);
    rfq.status = RfqStatus.quoted;
    final t = threads
        .where(
            (t) => t.supplierId == rfq.supplierId && t.title == rfq.productName)
        .firstOrNull;
    t?.messages.add(ChatMessage(
        Role.supplier,
        'Quote submitted: ${money(unitPrice, 'SLE')} per ${rfq.unit}, lead time $leadDays days.',
        _clock()));
    notifyListeners();
    return quote;
  }

  Future<void> confirmOrder(Order o) async {
    if (o.status != OrderStatus.awaitingSellerConfirmation) return;
    o.status = OrderStatus.confirmed;
    o.events.add(
        DeliveryEvent('confirmed', 'Supplier confirmed the order.', _clock()));
    notifyListeners();
  }

  static const deliverySteps = [
    'ready',
    'dispatched',
    'in_transit',
    'delivered'
  ];

  Future<void> addDeliveryEvent(Order o, String type, String note) async {
    if (o.status == OrderStatus.awaitingSellerConfirmation ||
        o.status == OrderStatus.delivered ||
        o.status == OrderStatus.cancelled ||
        o.status == OrderStatus.disputed) {
      return;
    }
    o.events.add(DeliveryEvent(type, note, _clock()));
    o.status =
        type == 'delivered' ? OrderStatus.delivered : OrderStatus.inFulfilment;
    notifyListeners();
  }

  Future<Product> addListing(
      {required String name,
      required String category,
      required String unit,
      double? price,
      required String location}) async {
    final p = Product(
        id: _id('p'),
        name: name,
        category: category,
        supplierId: mySupplierId,
        location: location,
        unit: unit,
        icon: categoryIcon(category),
        color: const Color(0xFFE6EDE6),
        indicativePrice: price,
        published: false);
    products.insert(0, p);
    notifyListeners();
    return p;
  }

  // ---- messaging ----
  Future<void> send(Thread t, String text) async {
    final clean = text.trim();
    if (clean.isEmpty || role == null) return;
    t.messages.add(ChatMessage(role!, clean, _clock()));
    notifyListeners();
  }

  static IconData categoryIcon(String c) => switch (c) {
        'Agriculture' => Icons.grass_rounded,
        'Metals & Hardware' => Icons.construction_rounded,
        'Equipment & Machinery' => Icons.precision_manufacturing_rounded,
        'Food & Beverage' => Icons.restaurant_rounded,
        'Energy & Power' => Icons.bolt_rounded,
        'Packaging & Office' => Icons.inventory_2_rounded,
        'Logistics & Services' => Icons.local_shipping_rounded,
        _ => Icons.foundation_rounded,
      };

  void _seed() {
    final now = _clock();
    products.addAll([
      Product(
          id: 'p1',
          name: 'Portland Cement 50 kg',
          category: 'Construction',
          supplierId: 's1',
          location: 'Western Area Urban',
          unit: 'bag',
          icon: Icons.foundation_rounded,
          color: const Color(0xFFE6EDE6)),
      Product(
          id: 'p2',
          name: 'Fresh Cocoa Beans',
          category: 'Agriculture',
          supplierId: 's2',
          location: 'Kono District',
          unit: 'kg',
          icon: Icons.grass_rounded,
          color: const Color(0xFFF0E7D8)),
      Product(
          id: 'p3',
          name: 'Iron Rods 12 mm',
          category: 'Metals & Hardware',
          supplierId: 's3',
          location: 'Freetown',
          unit: 'length',
          icon: Icons.construction_rounded,
          color: const Color(0xFFE2E9F1),
          indicativePrice: 185),
      Product(
          id: 'p4',
          name: 'Cassava Flour 25 kg',
          category: 'Agriculture',
          supplierId: 's4',
          location: 'Bo District',
          unit: 'sack',
          icon: Icons.inventory_2_rounded,
          color: const Color(0xFFF2E8C9),
          indicativePrice: 420),
      Product(
          id: 'p5',
          name: 'Sand (tipper load)',
          category: 'Construction',
          supplierId: 's1',
          location: 'Western Area Urban',
          unit: 'load',
          icon: Icons.landscape_rounded,
          color: const Color(0xFFEFE9DA)),
      Product(
          id: 'p6',
          name: 'Generator 20 kVA (hire)',
          category: 'Equipment & Machinery',
          supplierId: 's3',
          location: 'Freetown',
          unit: 'day',
          icon: Icons.precision_manufacturing_rounded,
          color: const Color(0xFFECE4F2)),
    ]);
    // Seed: an RFQ already quoted so a buyer can try accepting; plus one open RFQ for the supplier to quote.
    final r1 = Rfq(
        id: 'r1',
        ref: 'SL-4F2A91',
        productName: 'Portland Cement 50 kg',
        supplierId: 's1',
        quantity: 400,
        unit: 'bag',
        district: 'Western Area Urban',
        notes: 'Site delivery, Aberdeen.',
        target: '2026-12-05',
        status: RfqStatus.quoted,
        quotes: [
          Quote(
              id: 'q1',
              unitPrice: 280,
              leadDays: 3,
              validDays: 7,
              terms: 'Delivery within Freetown included. Offloading by buyer.')
        ]);
    final r2 = Rfq(
        id: 'r2',
        ref: 'SL-9C07E1',
        productName: 'Sand (tipper load)',
        supplierId: 's1',
        quantity: 6,
        unit: 'load',
        district: 'Western Area Urban',
        notes: '',
        target: null);
    rfqs.addAll([r2, r1]);
    final t1 =
        Thread(id: 't1', title: 'Portland Cement 50 kg', supplierId: 's1');
    t1.messages.addAll([
      ChatMessage(
          Role.buyer,
          'Hello, we sent RFQ SL-4F2A91 for 400 bag. Please quote.',
          now.subtract(const Duration(days: 2))),
      ChatMessage(
          Role.supplier,
          'Quote submitted: SLE 280 per bag, lead time 3 days.',
          now.subtract(const Duration(days: 1))),
    ]);
    threads.add(t1);
  }
}
