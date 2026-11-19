import 'dart:async';
import '../models.dart';
import '../store.dart';
import 'mappers.dart';
import 'remote_api.dart';

/// AppStore backed by Supabase. The server owns every rule (RLS + SECURITY DEFINER functions):
/// this class only calls them and reloads. Errors from the server propagate to the UI as exceptions.
class LiveAppStore extends AppStore {
  LiveAppStore(this.api, {super.clock}) : super.empty();
  final RemoteApi api;

  AuthPhase _phase = AuthPhase.signedOut;
  String? _orgId;
  Business? _me;
  var _orgNames = <String, String>{};
  var _catNameById = <String, String>{};
  var _catIdByName = <String, String>{};
  bool loading = false;

  @override
  bool get isLive => true;
  @override
  AuthPhase get phase => _phase;
  @override
  Business get myBusiness =>
      _me ?? const Business(id: '', name: '', district: '');
  @override
  String get mySupplierId => _orgId ?? '';
  String? get email => api.email;

  @override
  Business supplier(String id) => suppliers.firstWhere((s) => s.id == id,
      orElse: () =>
          Business(id: id, name: _orgNames[id] ?? 'Supplier', district: ''));

  /// Restores an existing session at start-up.
  Future<void> restore() async {
    if (api.signedIn) await refresh();
  }

  Future<void> signInWithPassword(String email, String password) async {
    await api.signIn(email.trim(), password);
    await refresh();
  }

  /// Returns false when the project requires email confirmation before the first sign-in.
  Future<bool> registerWithPassword(String email, String password) async {
    final active = await api.signUp(email.trim(), password);
    if (active) await refresh();
    return active;
  }

  Future<void> createOrganization(
      {required String name,
      required Role type,
      required String district}) async {
    await api.rpc('create_organization', {
      'p_legal_name': name,
      'p_display_name': name,
      'p_type': type == Role.buyer ? 'buyer' : 'supplier',
      'p_district': district,
      'p_locality': null,
    });
    await refresh();
  }

  @override
  void signOut() {
    unawaited(api.signOut());
    _phase = AuthPhase.signedOut;
    role = null;
    _orgId = null;
    _me = null;
    saved.clear();
    for (final l in <List<Object?>>[
      products,
      rfqs,
      orders,
      threads,
      suppliers
    ]) {
      l.clear();
    }
    notifyListeners();
  }

  @override
  void signIn(Role r) =>
      throw UnsupportedError('Use signInWithPassword in live mode.');

  /// Reloads everything the signed-in business may see. Row-level security decides what comes back.
  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    try {
      final memberships = await api.select('organization_memberships',
          columns:
              'organization_id,member_role,organizations(id,display_name,district,organization_type,status)');
      final mine = memberships
          .where((m) => (m['organizations'] as Map?)?['status'] == 'active')
          .toList();
      if (mine.isEmpty) {
        _phase = AuthPhase.needsOrganization;
        return;
      }
      final org = Map<String, dynamic>.from(mine.first['organizations'] as Map);
      _orgId = '${org['id']}';
      role =
          org['organization_type'] == 'supplier' ? Role.supplier : Role.buyer;
      _me = Business(
          id: _orgId!,
          name: '${org['display_name']}',
          district: '${org['district'] ?? ''}');

      final savedRows = await api.select('saved_products');
      saved
        ..clear()
        ..addAll(savedRows.map((r) => '${r['listing_id']}'));
      final cats = await api.select('categories');
      _catNameById = {for (final c in cats) '${c['id']}': '${c['name']}'};
      _catIdByName = {for (final c in cats) '${c['name']}': '${c['id']}'};

      final directory =
          (await api.select('supplier_directory')).map(mapBusiness).toList();
      final orgRows = await api.select('organizations',
          columns: 'id,display_name,district,organization_type');
      _orgNames = {
        for (final o in orgRows) '${o['id']}': '${o['display_name']}'
      };
      final known = {for (final s in directory) s.id};
      suppliers
        ..clear()
        ..addAll(directory)
        ..addAll(orgRows
            .where((o) =>
                o['organization_type'] == 'supplier' &&
                !known.contains('${o['id']}'))
            .map(mapBusiness));

      products
        ..clear()
        ..addAll((await api.select('listings',
                orderBy: 'created_at', descending: true))
            .map((r) => mapListing(r, _catNameById)));
      rfqs
        ..clear()
        ..addAll((await api.select('rfqs',
                columns:
                    '*,rfq_items(*),rfq_recipients(*),quotes(*,quote_lines(*))',
                orderBy: 'created_at',
                descending: true))
            .map((r) => mapRfq(r,
                orgNames: _orgNames,
                mySupplierId: role == Role.supplier ? _orgId : null)));
      orders
        ..clear()
        ..addAll((await api.select('orders',
                columns: '*,delivery_events(*)',
                orderBy: 'created_at',
                descending: true))
            .map((r) => mapOrder(r, orgNames: _orgNames)));
      threads
        ..clear()
        ..addAll((await api.select('threads',
                columns: '*,messages(*)',
                orderBy: 'created_at',
                descending: true))
            .map((r) => mapThread(r, orgNames: _orgNames)));
      if (role == Role.supplier) {
        final v = await api.select('supplier_verification_cases',
            columns: 'status',
            eq: {'organization_id': _orgId!},
            orderBy: 'submitted_at',
            descending: true,
            limit: 1);
        verificationStatus = v.isEmpty
            ? 'not submitted'
            : '${v.first['status']}'.replaceAll('_', ' ');
      }
      _phase = AuthPhase.ready;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ---- buyer ----
  @override
  Future<Rfq> createRfq(
      {required Product product,
      required double quantity,
      required String district,
      required String notes,
      DateTime? target}) async {
    final id = await api.rpc('create_rfq', {
      'p_buyer_org': _orgId,
      'p_destination_district': district,
      'p_destination_locality': null,
      'p_target_delivery_date': target?.toIso8601String().substring(0, 10),
      'p_notes': notes,
      'p_items': [
        {'listing_id': product.id, 'quantity': quantity}
      ],
      'p_supplier_orgs': <String>[],
    });
    final rfqId = '$id';
    final thread = await api.rpc('open_thread', {
      'p_buyer_org': _orgId,
      'p_supplier_org': product.supplierId,
      'p_rfq': rfqId,
      'p_subject': product.name
    });
    await api.rpc('send_message', {
      'p_thread': '$thread',
      'p_body':
          'Hello, we sent an RFQ for ${quantity == quantity.roundToDouble() ? quantity.toInt() : quantity} ${product.unit}. Please quote.'
    });
    await refresh();
    return rfqs.firstWhere((r) => r.id == rfqId);
  }

  @override
  Future<void> cancelRfq(Rfq rfq) async {
    await api.rpc('cancel_rfq', {'p_rfq': rfq.id});
    await refresh();
  }

  @override
  Future<Order?> acceptQuote(Rfq rfq, Quote quote) async {
    final id = await api.rpc('accept_quote', {'p_quote': quote.id});
    await refresh();
    return orders.where((o) => o.id == '$id').firstOrNull;
  }

  @override
  Future<void> reportProblem(Order o, String text) async {
    await api.rpc('report_delivery_problem', {'p_order': o.id, 'p_text': text});
    await refresh();
  }

  // ---- supplier ----
  @override
  Future<Quote?> submitQuote(Rfq rfq,
      {required double unitPrice,
      required int leadDays,
      required int validDays,
      required String terms}) async {
    if (rfq.itemIds.length != 1) throw StateError('multi_item_unsupported');
    final id = await api.rpc('submit_quote', {
      'p_rfq': rfq.id,
      'p_supplier_org': _orgId,
      'p_currency': 'SLE',
      'p_lead_time_days': leadDays,
      'p_validity':
          now().toUtc().add(Duration(days: validDays)).toIso8601String(),
      'p_terms': terms.isEmpty ? null : terms,
      'p_exclusions': null,
      'p_lines': [
        {'rfq_item_id': rfq.itemIds.first, 'unit_price': unitPrice}
      ],
    });
    await refresh();
    return rfqs
        .firstWhere((r) => r.id == rfq.id)
        .quotes
        .where((q) => q.id == '$id')
        .firstOrNull;
  }

  @override
  Future<void> confirmOrder(Order o) async {
    await api.rpc('confirm_order', {'p_order': o.id});
    await refresh();
  }

  @override
  Future<void> addDeliveryEvent(Order o, String type, String note) async {
    await api.rpc('add_delivery_event', {
      'p_order': o.id,
      'p_type': type,
      'p_note': note.isEmpty ? null : note,
      'p_quantity': null,
      'p_unit': null,
      'p_evidence': null,
    });
    await refresh();
  }

  /// Creates a draft listing and submits it; the server decides whether it needs moderation.
  @override
  Future<Product> addListing(
      {required String name,
      required String category,
      required String unit,
      double? price,
      required String location}) async {
    final row = await api.insert('listings', {
      'organization_id': _orgId,
      'title': name,
      'category': _catIdByName[category] ?? category,
      'quantity_unit': unit,
      'price_mode': price == null ? 'quote_only' : 'indicative',
      'price_amount': price,
      'currency_code': price == null ? null : 'SLE',
      'district': location,
      'created_by': api.userId,
    });
    await api.rpc('submit_listing_for_review', {'p_listing': row['id']});
    await refresh();
    return products.firstWhere((p) => p.id == '${row['id']}');
  }

  @override
  Future<void> toggleSaved(String productId) async {
    final actor = api.userId;
    final next = !saved.contains(productId);
    await api.rpc('set_saved_product',
        {'p_listing': productId, 'p_saved': next});
    if (actor != api.userId || phase != AuthPhase.ready) return;
    if (next) {
      saved.add(productId);
    } else {
      saved.remove(productId);
    }
    notifyListeners();
  }

  // ---- messaging ----
  @override
  Future<void> send(Thread t, String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    await api.rpc('send_message', {'p_thread': t.id, 'p_body': clean});
    await refresh();
  }
}
