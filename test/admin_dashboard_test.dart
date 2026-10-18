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
}

Future<void> showDashboard(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(home: AdminDashboard(initialSnapshot: fixture())),
  );
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
