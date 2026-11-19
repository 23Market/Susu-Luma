// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/backend/errors.dart';
import 'package:susu_luma/backend/live_store.dart';
import 'package:susu_luma/backend/mappers.dart';
import 'package:susu_luma/backend/remote_api.dart';
import 'package:susu_luma/main.dart';
import 'package:susu_luma/models.dart';
import 'package:susu_luma/store.dart';

class RpcCall {
  RpcCall(this.fn, this.params);
  final String fn;
  final Map<String, dynamic> params;
}

class FakeApi implements RemoteApi {
  FakeApi({this.orgType = 'buyer', this.hasOrg = true});
  final String orgType;
  bool hasOrg;
  bool _in = false;
  Object? signInError;
  final calls = <RpcCall>[];
  final inserted = <Map<String, dynamic>>[];
  Object? rpcError;
  Map<String, dynamic> tables = {};

  @override
  bool get signedIn => _in;
  @override
  String? get userId => 'user-1';
  @override
  String? get email => 'owner@example.com';
  @override
  Future<void> signIn(String email, String password) async {
    if (signInError != null) throw signInError!;
    _in = true;
  }

  @override
  Future<bool> signUp(String email, String password) async => false;
  @override
  Future<void> signOut() async => _in = false;

  @override
  Future<List<Map<String, dynamic>>> select(String table,
      {String columns = '*',
      Map<String, Object>? eq,
      String? orderBy,
      bool descending = false,
      int? limit}) async {
    if (table == 'organization_memberships') {
      return hasOrg
          ? [
              {
                'organization_id': 'org-1',
                'member_role': 'owner',
                'organizations': {
                  'id': 'org-1',
                  'display_name': 'Aberdeen Construction',
                  'district': 'Western Area Urban',
                  'organization_type': orgType,
                  'status': 'active'
                }
              }
            ]
          : [];
    }
    return List<Map<String, dynamic>>.from(
        (tables[table] ?? const <Map<String, dynamic>>[]) as List);
  }

  @override
  Future<Map<String, dynamic>> insert(
      String table, Map<String, dynamic> row) async {
    inserted.add(row);
    final saved = {
      ...row,
      'id': 'lst-new',
      'status': 'draft',
      'created_at': '2026-11-18T10:00:00Z'
    };
    tables['listings'] = [...(tables['listings'] as List? ?? []), saved];
    return saved;
  }

  @override
  Future<dynamic> rpc(String fn, Map<String, dynamic> params) async {
    calls.add(RpcCall(fn, params));
    if (rpcError != null) throw rpcError!;
    return switch (fn) {
      'create_rfq' => 'rfq-new',
      'open_thread' => 'thr-1',
      'accept_quote' => 'ord-1',
      'submit_quote' => 'qt-new',
      _ => null,
    };
  }
}

const _cats = [
  {'id': 'construction', 'name': 'Construction'},
  {'id': 'equipment', 'name': 'Equipment & Machinery'}
];
final _listing = {
  'id': 'lst-1',
  'organization_id': 'sup-1',
  'title': 'Portland cement 50 kg',
  'category': 'construction',
  'quantity_unit': 'bag',
  'price_mode': 'quote_only',
  'price_amount': null,
  'district': 'Western Area Urban',
  'status': 'published',
  'created_at': '2026-11-01T10:00:00Z'
};
Map<String, dynamic> _rfqRow(
        {String status = 'quoted', List<Map<String, dynamic>>? quotes}) =>
    {
      'id': 'rfq-1',
      'reference_code': 'SL-ABC123',
      'buyer_organization_id': 'org-1',
      'status': status,
      'destination_district': 'Western Area Urban',
      'notes': 'Site delivery',
      'target_delivery_date': '2026-12-05',
      'created_at': '2026-11-10T09:00:00Z',
      'rfq_items': [
        {
          'id': 'item-1',
          'product_title': 'Portland cement 50 kg',
          'quantity': 400,
          'quantity_unit': 'bag'
        }
      ],
      'rfq_recipients': [
        {'supplier_organization_id': 'sup-1'}
      ],
      'quotes': quotes ??
          [
            {
              'id': 'qt-v1',
              'supplier_organization_id': 'sup-1',
              'version': 1,
              'status': 'revised',
              'currency_code': 'SLE',
              'lead_time_days': 3,
              'validity_until': '2026-11-20T00:00:00Z',
              'submitted_at': '2026-11-11T00:00:00Z',
              'created_at': '2026-11-11T00:00:00Z',
              'terms': 'v1',
              'quote_lines': [
                {'unit_price': 290}
              ]
            },
            {
              'id': 'qt-v2',
              'supplier_organization_id': 'sup-1',
              'version': 2,
              'status': 'submitted',
              'currency_code': 'SLE',
              'lead_time_days': 3,
              'validity_until': '2026-11-21T00:00:00Z',
              'submitted_at': '2026-11-12T00:00:00Z',
              'created_at': '2026-11-12T00:00:00Z',
              'terms': 'Delivery included',
              'quote_lines': [
                {'unit_price': 280}
              ]
            }
          ]
    };

FakeApi _buyerApi() => FakeApi()
  ..tables = {
    'categories': _cats,
    'supplier_directory': [
      {
        'id': 'sup-1',
        'display_name': 'Freetown Building Supply',
        'district': 'Western Area Urban',
        'verified': true
      }
    ],
    'organizations': [
      {
        'id': 'org-1',
        'display_name': 'Aberdeen Construction',
        'organization_type': 'buyer'
      },
      {
        'id': 'sup-1',
        'display_name': 'Freetown Building Supply',
        'organization_type': 'supplier'
      }
    ],
    'listings': [_listing],
    'rfqs': [_rfqRow()],
    'orders': [
      {
        'id': '11111111-2222-3333-4444-555555555555',
        'buyer_organization_id': 'org-1',
        'supplier_organization_id': 'sup-1',
        'status': 'partially_delivered',
        'payment_status': 'pending_unverified',
        'created_at': '2026-11-13T00:00:00Z',
        'accepted_quote_snapshot': {
          'rfq_reference': 'SL-ABC123',
          'currency_code': 'SLE',
          'total': 112000,
          'lead_time_days': 3,
          'lines': [
            {
              'product_title': 'Portland cement 50 kg',
              'quantity': 400,
              'quantity_unit': 'bag',
              'unit_price': 280
            }
          ]
        },
        'delivery_events': [
          {
            'event_type': 'dispatched',
            'note': 'Truck left',
            'created_at': '2026-11-14T00:00:00Z'
          },
          {
            'event_type': 'ready',
            'note': null,
            'created_at': '2026-11-13T12:00:00Z'
          }
        ]
      }
    ],
    'threads': [
      {
        'id': 'thr-1',
        'subject': 'Portland cement 50 kg',
        'buyer_organization_id': 'org-1',
        'supplier_organization_id': 'sup-1',
        'messages': [
          {
            'sender_organization_id': 'sup-1',
            'body': 'Quote sent',
            'created_at': '2026-11-12T00:00:00Z'
          },
          {
            'sender_organization_id': 'org-1',
            'body': 'Please quote',
            'created_at': '2026-11-10T09:30:00Z'
          }
        ]
      }
    ],
  };

void main() {
  group('mappers', () {
    test('listing maps category name, unit and quote-only price', () {
      final p = mapListing(_listing, {'construction': 'Construction'});
      expect(p.category, 'Construction');
      expect(p.unit, 'bag');
      expect(p.indicativePrice, isNull);
      expect(p.published, isTrue);
    });

    test(
        'RFQ hides superseded quote versions and keeps explicit currency and unit',
        () {
      final r = mapRfq(_rfqRow(), orgNames: {
        'org-1': 'Aberdeen Construction',
        'sup-1': 'Freetown Building Supply'
      });
      expect(r.status, RfqStatus.quoted);
      expect(r.quotes, hasLength(1));
      expect(r.quotes.single.unitPrice, 280);
      expect(r.quotes.single.currency, 'SLE');
      expect(r.quotes.single.supplierName, 'Freetown Building Supply');
      expect(r.unit, 'bag');
      expect(r.itemIds, ['item-1']);
      expect(r.buyerName, 'Aberdeen Construction');
    });

    test(
        'order reads the frozen snapshot, real payment status and sorted events',
        () {
      final o = mapOrder(
          (_buyerApi().tables['orders'] as List).first as Map<String, dynamic>,
          orgNames: {});
      expect(o.total, 112000);
      expect(o.currency, 'SLE');
      expect(o.paymentStatus, 'pending_unverified');
      expect(o.status, OrderStatus.inFulfilment);
      expect(o.events.first.type, 'ready');
      expect(o.ref, startsWith('ORD-11111111'));
    });

    test('thread assigns message sides by sender organisation', () {
      final t = mapThread(
          (_buyerApi().tables['threads'] as List).first as Map<String, dynamic>,
          orgNames: {'org-1': 'Aberdeen'});
      expect(t.messages.first.from, Role.buyer);
      expect(t.messages.last.from, Role.supplier);
    });
  });

  group('LiveAppStore', () {
    test('a signed-in user with no organisation is sent to business setup',
        () async {
      final api = FakeApi(hasOrg: false);
      final s = LiveAppStore(api);
      expect(s.phase, AuthPhase.signedOut);
      await s.signInWithPassword(' owner@example.com ', 'password123');
      expect(s.phase, AuthPhase.needsOrganization);
      api.hasOrg = true;
      api.tables = _buyerApi().tables;
      await s.createOrganization(
          name: 'Aberdeen Construction', type: Role.buyer, district: 'Bo');
      final call = api.calls.firstWhere((c) => c.fn == 'create_organization');
      expect(call.params['p_type'], 'buyer');
      expect(call.params['p_display_name'], 'Aberdeen Construction');
      expect(s.phase, AuthPhase.ready);
      expect(s.role, Role.buyer);
    });

    test('role comes from the organisation, never from the client', () async {
      final api = _buyerApi();
      final s = LiveAppStore(FakeApi(orgType: 'supplier')..tables = api.tables);
      await s.signInWithPassword('a@b.co', 'password123');
      expect(s.role, Role.supplier);
      expect(s.myBusiness.name, 'Aberdeen Construction');
      expect(() => s.signIn(Role.buyer), throwsUnsupportedError);
    });

    test(
        'creating an RFQ calls the server with listing id and quantity, then opens a thread',
        () async {
      final api = _buyerApi();
      final s = LiveAppStore(api);
      await s.signInWithPassword('a@b.co', 'password123');
      api.tables['rfqs'] = [
        _rfqRow(status: 'open', quotes: []),
        {..._rfqRow(), 'id': 'rfq-new', 'reference_code': 'SL-NEW'}
      ];
      final rfq = await s.createRfq(
          product: s.products.first,
          quantity: 400,
          district: 'Western Area Urban',
          notes: 'n',
          target: DateTime(2026, 12, 5));
      final c = api.calls.firstWhere((c) => c.fn == 'create_rfq');
      expect(c.params['p_buyer_org'], 'org-1');
      expect(c.params['p_target_delivery_date'], '2026-12-05');
      expect((c.params['p_items'] as List).single,
          {'listing_id': 'lst-1', 'quantity': 400.0});
      expect(api.calls.map((c) => c.fn),
          containsAllInOrder(['create_rfq', 'open_thread', 'send_message']));
      expect(rfq.ref, 'SL-NEW');
    });

    test(
        'accepting a quote calls accept_quote with the quote id only (the server snapshots terms)',
        () async {
      final api = _buyerApi();
      final s = LiveAppStore(api);
      await s.signInWithPassword('a@b.co', 'password123');
      final rfq = s.rfqs.single;
      await s.acceptQuote(rfq, rfq.quotes.single);
      final c = api.calls.firstWhere((c) => c.fn == 'accept_quote');
      expect(c.params, {'p_quote': 'qt-v2'});
    });

    test('server errors surface as friendly messages', () async {
      final api = _buyerApi();
      final s = LiveAppStore(api);
      await s.signInWithPassword('a@b.co', 'password123');
      api.rpcError =
          Exception('PostgrestException(message: quote_expired, code: P0001)');
      await expectLater(
          s.acceptQuote(s.rfqs.single, s.rfqs.single.quotes.single),
          throwsException);
      expect(friendlyError(api.rpcError!), contains('expired'));
      expect(friendlyError(Exception('Invalid login credentials')),
          contains('incorrect'));
      expect(
          friendlyError(Exception('boom')), contains('Something went wrong'));
    });

    test(
        'supplier quotes a single-item RFQ with server item id; multi-item is refused',
        () async {
      final api = FakeApi(orgType: 'supplier')..tables = _buyerApi().tables;
      final s = LiveAppStore(api, clock: () => DateTime.utc(2026, 11, 18));
      await s.signInWithPassword('a@b.co', 'password123');
      await s.submitQuote(s.rfqs.single,
          unitPrice: 270, leadDays: 3, validDays: 7, terms: '');
      final c = api.calls.firstWhere((c) => c.fn == 'submit_quote');
      expect(c.params['p_lines'], [
        {'rfq_item_id': 'item-1', 'unit_price': 270.0}
      ]);
      expect(c.params['p_currency'], 'SLE');
      expect(c.params['p_validity'], '2026-11-25T00:00:00.000Z');
      final multi = Rfq(
          id: 'r',
          ref: 'x',
          productName: 'x',
          supplierId: 's',
          quantity: 1,
          unit: 'u',
          district: 'd',
          notes: '',
          itemIds: ['a', 'b']);
      await expectLater(
          s.submitQuote(multi,
              unitPrice: 1, leadDays: 1, validDays: 1, terms: ''),
          throwsStateError);
    });

    test(
        'supplier listing is created as a draft then submitted for review (never self-published)',
        () async {
      final api = FakeApi(orgType: 'supplier')..tables = _buyerApi().tables;
      final s = LiveAppStore(api);
      await s.signInWithPassword('a@b.co', 'password123');
      final p = await s.addListing(
          name: 'Concrete mixer',
          category: 'Equipment & Machinery',
          unit: 'unit',
          price: 14500,
          location: 'Bo');
      expect(api.inserted.single['category'], 'equipment');
      expect(api.inserted.single['price_mode'], 'indicative');
      expect(api.inserted.single['currency_code'], 'SLE');
      expect(api.inserted.single.containsKey('status'), isFalse);
      expect(api.calls.last.fn, 'submit_listing_for_review');
      expect(p.published, isFalse);
    });

    test('signing out clears all data', () async {
      final s = LiveAppStore(_buyerApi());
      await s.signInWithPassword('a@b.co', 'password123');
      expect(s.rfqs, isNotEmpty);
      s.signOut();
      expect(s.phase, AuthPhase.signedOut);
      expect(s.rfqs, isEmpty);
    });
  });

  group('saved products', () {
    test('refresh restores saved ids and logout clears them', () async {
      final api = _buyerApi();
      api.tables['saved_products'] = [
        {'listing_id': 'lst-1'}
      ];
      final store = LiveAppStore(api);
      await store.signInWithPassword('a@b.co', 'password123');
      expect(store.saved, contains('lst-1'));
      store.signOut();
      expect(store.saved, isEmpty);
    });

    test('failed save does not claim success and can be retried', () async {
      final api = _buyerApi();
      final store = LiveAppStore(api);
      await store.signInWithPassword('a@b.co', 'password123');
      api.rpcError = StateError('network unavailable');
      await expectLater(store.toggleSaved('lst-1'), throwsStateError);
      expect(store.saved, isEmpty);
      api.rpcError = null;
      await store.toggleSaved('lst-1');
      expect(store.saved, contains('lst-1'));
      expect(api.calls.last.fn, 'set_saved_product');
      expect(api.calls.last.params, {'p_listing': 'lst-1', 'p_saved': true});
    });
  });

  group('live UI', () {
    testWidgets('wrong credentials show a friendly error and stay on sign-in',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = FakeApi()
        ..signInError =
            Exception('AuthApiException: Invalid login credentials');
      await tester.pumpWidget(SusuLumaApp(store: LiveAppStore(api)));
      expect(find.text('Sign in to your business account'), findsOneWidget);
      await tester.enterText(
          find.byType(TextFormField).first, 'owner@example.com');
      await tester.enterText(find.byType(TextFormField).last, 'wrongpassword');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
    });

    testWidgets('after sign-in a buyer lands on the buyer shell with live data',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _buyerApi();
      await tester.pumpWidget(SusuLumaApp(store: LiveAppStore(api)));
      await tester.enterText(
          find.byType(TextFormField).first, 'owner@example.com');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Home · Aberdeen Construction'.toUpperCase()),
          findsOneWidget);
      expect(find.text('Portland cement 50 kg'), findsWidgets);
    });
  });
}
