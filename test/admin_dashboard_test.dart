import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/admin/admin_dashboard.dart';
import 'package:susu_luma/admin/admin_dashboard_data.dart';

void main() {
  test('parses the server dashboard contract', () {
    final dashboard = fixture();
    expect(dashboard.overview.monthlyRevenue, 32500);
    expect(dashboard.marketplace.recentRfqs.single.referenceCode, 'SL-RFQ-101');
    expect(dashboard.suppliers.verificationQueue.single.supplier, 'Kono Trade');
    expect(dashboard.operations.supportQueue.single.priority, 'high');
  });

  testWidgets('renders live business metrics and backend status',
      (tester) async {
    await showDashboard(tester);
    expect(find.text('Business overview'), findsOneWidget);
    expect(find.text('SLE 32500'), findsOneWidget);
    expect(find.text('Live backend'), findsOneWidget);
    expect(find.textContaining('Illustrative business metrics'), findsNothing);
  });

  testWidgets('shows revenue from the server snapshot', (tester) async {
    await showDashboard(tester);
    await tester.tap(find.text('Revenue'));
    await tester.pumpAndSettle();
    expect(find.text('Revenue model'), findsOneWidget);
    expect(find.text('Financial boundary'), findsOneWidget);
    expect(find.text('Subscription'), findsOneWidget);
    expect(find.text('SLE 25000'), findsOneWidget);
  });

  testWidgets('renders each operational section and filters visible queues',
      (tester) async {
    await showDashboard(tester);

    await tester.tap(find.text('Marketplace'));
    await tester.pumpAndSettle();
    expect(find.text('Marketplace activity'), findsOneWidget);
    expect(find.text('SL-RFQ-101'), findsOneWidget);

    await tester.tap(find.text('Suppliers'));
    await tester.pumpAndSettle();
    expect(find.text('Supplier growth'), findsOneWidget);
    expect(find.text('Kono Trade'), findsOneWidget);
    expect(find.text('SLE 650/mo'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'does-not-exist');
    await tester.pumpAndSettle();
    expect(find.text('No records match this view.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.tap(find.text('Operations'));
    await tester.pumpAndSettle();
    expect(find.text('Operations centre'), findsOneWidget);
    expect(find.text('Listing moderation'), findsOneWidget);
    expect(find.text('Support queue'), findsOneWidget);
  });

  testWidgets('executes supplier, listing and support decisions',
      (tester) async {
    final source = FakeAdminDataSource(fixture());
    await showDashboard(tester, dataSource: source);

    await tester.tap(find.text('Suppliers'));
    await tester.pumpAndSettle();
    tester
        .widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.check_circle_outline).first,
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(source.supplierDecisions, ['case-1:approved:']);
    expect(find.text('Supplier review saved'), findsOneWidget);

    await tester.tap(find.text('Operations'));
    await tester.pumpAndSettle();
    tester
        .widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.cancel_outlined).first,
        )
        .onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('Reject listing'), findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextField, 'Reason for rejection'), 'Wrong item');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(source.listingDecisions, ['listing-1:rejected:Wrong item']);

    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Resolve'),
        )
        .onPressed!();
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Resolution note'), 'Issue resolved');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(source.supportResolutions, ['support-1:Issue resolved']);
  });

  testWidgets('shows a retry state when dashboard loading fails',
      (tester) async {
    final source = FakeAdminDataSource(fixture())..failFetch = true;
    await showDashboard(tester, dataSource: source, useInitialSnapshot: false);
    await tester.pumpAndSettle();
    expect(find.text('Dashboard data is unavailable'), findsOneWidget);

    source.failFetch = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Business overview'), findsOneWidget);
  });

  test('dashboard parsing uses safe defaults for malformed payloads', () {
    final dashboard = AdminDashboardSnapshot.fromJson({
      'generatedAt': 'not-a-date',
      'overview': {'monthlyRevenue': '12.5', 'qualifiedRfqs': '3'},
      'marketplace': {'recentRfqs': 'not-a-list'},
      'suppliers': <String, Object?>{},
      'revenue': <String, Object?>{},
      'operations': <String, Object?>{},
    });

    expect(dashboard.overview.monthlyRevenue, 12.5);
    expect(dashboard.overview.qualifiedRfqs, 3);
    expect(dashboard.marketplace.recentRfqs, isEmpty);
    expect(const AdminDashboardException('denied').toString(), 'denied');
  });
}

Future<void> showDashboard(
  WidgetTester tester, {
  AdminDashboardDataSource? dataSource,
  bool useInitialSnapshot = true,
}) async {
  tester.view.physicalSize = const Size(2000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: AdminDashboard(
        dataSource: dataSource ?? FakeAdminDataSource(fixture()),
        initialSnapshot: useInitialSnapshot ? fixture() : null,
      ),
    ),
  );
}

class FakeAdminDataSource implements AdminDashboardDataSource {
  FakeAdminDataSource(this.snapshot);

  final AdminDashboardSnapshot snapshot;
  bool failFetch = false;
  final supplierDecisions = <String>[];
  final listingDecisions = <String>[];
  final supportResolutions = <String>[];

  @override
  Future<AdminDashboardSnapshot> fetch() async {
    if (failFetch) throw const AdminDashboardException('unavailable');
    return snapshot;
  }

  @override
  Future<void> reviewSupplier(String caseId, String decision,
      {String? reason}) async {
    supplierDecisions.add('$caseId:$decision:${reason ?? ''}');
  }

  @override
  Future<void> reviewListing(String listingId, String decision,
      {String? reason}) async {
    listingDecisions.add('$listingId:$decision:${reason ?? ''}');
  }

  @override
  Future<void> resolveSupportCase(String caseId, String resolution) async {
    supportResolutions.add('$caseId:$resolution');
  }
}

AdminDashboardSnapshot fixture() => AdminDashboardSnapshot.fromJson({
      'generatedAt': '2026-10-19T10:00:00Z',
      'overview': {
        'monthlyRevenue': 32500,
        'marketplaceGmv': 1260000,
        'qualifiedRfqs': 300,
        'conversionRate': 18.7,
      },
      'marketplace': {
        'openRfqs': 74,
        'ordersThisMonth': 56,
        'disputedOrders': 3,
        'recentRfqs': [
          {
            'id': 'rfq-1',
            'referenceCode': 'SL-RFQ-101',
            'buyer': 'Freetown Foods',
            'category': 'Rice',
            'status': 'open',
            'createdAt': '2026-10-18T10:00:00Z',
          }
        ],
      },
      'suppliers': {
        'activeSuppliers': 100,
        'verifiedSuppliers': 68,
        'proSuppliers': 31,
        'atRiskSuppliers': 8,
        'verificationQueue': [
          {
            'id': 'case-1',
            'organizationId': 'org-1',
            'supplier': 'Kono Trade',
            'district': 'Kono',
            'scope': 'Business identity',
            'status': 'pending',
            'submittedAt': '2026-10-17T10:00:00Z',
          }
        ],
      },
      'revenue': {
        'monthlyTotal': 32500,
        'streams': [
          {'stream': 'subscription', 'volume': 40, 'amount': 25000},
          {'stream': 'qualified_rfq', 'volume': 30, 'amount': 7500},
        ],
        'history': [
          {'month': '2026-05-01', 'amount': 12000},
          {'month': '2026-06-01', 'amount': 16000},
          {'month': '2026-07-01', 'amount': 20000},
          {'month': '2026-08-01', 'amount': 25000},
          {'month': '2026-09-01', 'amount': 29000},
          {'month': '2026-10-01', 'amount': 32500},
        ],
      },
      'operations': {
        'verificationBacklog': 12,
        'listingsInReview': 19,
        'supportCases': 7,
        'highPriorityCases': 2,
        'listingQueue': [
          {
            'id': 'listing-1',
            'title': 'Local rice',
            'supplier': 'Kono Trade',
            'category': 'Food',
            'status': 'pending_review',
            'createdAt': '2026-10-17T10:00:00Z',
          }
        ],
        'supportQueue': [
          {
            'id': 'support-1',
            'priority': 'high',
            'category': 'Order',
            'subject': 'Delivery issue',
            'status': 'open',
            'organization': 'Freetown Foods',
            'createdAt': '2026-10-18T10:00:00Z',
          }
        ],
      },
    });
