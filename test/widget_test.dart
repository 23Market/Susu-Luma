// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/models.dart';
import 'package:susu_luma/main.dart';
import 'package:susu_luma/store.dart';

Future<AppStore> _boot(WidgetTester tester, Role role) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final store = AppStore(clock: () => DateTime(2026, 11, 18));
  await tester.pumpWidget(SusuLumaApp(store: store));
  await tester.tap(find
      .text(role == Role.buyer ? 'Continue as buyer' : 'Continue as supplier'));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  group('store rules', () {
    test('money always carries explicit currency', () async {
      expect(money(1234567, 'SLE'), 'SLE 1,234,567');
      expect(money(12.5, 'SLE'), 'SLE 12.50');
    });

    test(
        'quote acceptance snapshots terms into an order with unverified payment',
        () async {
      final s = AppStore();
      final rfq = s.rfqs.firstWhere((r) => r.status == RfqStatus.quoted);
      final order = (await s.acceptQuote(rfq, rfq.quotes.first))!;
      expect(rfq.status, RfqStatus.accepted);
      expect(order.total, 400 * 280);
      expect(order.paymentStatus, 'pending_unverified');
      expect(await s.acceptQuote(rfq, rfq.quotes.first), isNull,
          reason: 'cannot accept twice');
    });

    test('delivery updates need a confirmed order', () async {
      final s = AppStore();
      final rfq = s.rfqs.firstWhere((r) => r.status == RfqStatus.quoted);
      final o = (await s.acceptQuote(rfq, rfq.quotes.first))!;
      await s.addDeliveryEvent(o, 'dispatched', '');
      expect(o.events, isEmpty);
      await s.confirmOrder(o);
      await s.addDeliveryEvent(o, 'dispatched', '');
      expect(o.status, OrderStatus.inFulfilment);
      await s.addDeliveryEvent(o, 'delivered', '');
      expect(o.status, OrderStatus.delivered);
    });

    test('new listings are unpublished until reviewed', () async {
      final s = AppStore();
      final p = await s.addListing(
          name: 'Test item', category: 'Metals', unit: 'kg', location: 'Bo');
      expect(s.search('test item', 'All'), isEmpty);
      expect(p.published, isFalse);
    });

    test('a revised quote supersedes the previous one', () async {
      final s = AppStore();
      final rfq = s.rfqs.firstWhere((r) => r.status == RfqStatus.submitted);
      await s.submitQuote(rfq,
          unitPrice: 100, leadDays: 2, validDays: 5, terms: '');
      await s.submitQuote(rfq,
          unitPrice: 90, leadDays: 2, validDays: 5, terms: '');
      expect(
          rfq.quotes.where((q) => q.status == QuoteStatus.submitted).length, 1);
      expect(
          await s.submitQuote(rfq,
              unitPrice: 0, leadDays: 1, validDays: 1, terms: ''),
          isNull);
    });
  });

  group('app flows', () {
    testWidgets('sign-in offers both personas with prototype disclaimer',
        (tester) async {
      await tester.pumpWidget(SusuLumaApp(store: AppStore()));
      expect(find.text('Continue as buyer'), findsOneWidget);
      expect(find.text('Continue as supplier'), findsOneWidget);
      expect(
          find.textContaining('No payments, escrow or wallet'), findsOneWidget);
    });

    testWidgets('buyer discovers, filters, and sends an RFQ', (tester) async {
      await _boot(tester, Role.buyer);
      await tester.tap(find.text('Discover').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'cocoa');
      await tester.pumpAndSettle();
      expect(find.text('Fresh Cocoa Beans'), findsOneWidget);
      expect(find.text('Portland Cement 50 kg'), findsNothing);
      await tester.tap(find.text('Fresh Cocoa Beans'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request quote'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send RFQ'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a quantity above zero'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '500');
      await tester.tap(find.text('Send RFQ'));
      await tester.pumpAndSettle();
      expect(find.text('Fresh Cocoa Beans'), findsWidgets);
      expect(
          find.text('Waiting for the supplier to quote.', findRichText: true),
          findsNothing);
      expect(find.textContaining('Waiting for the supplier'), findsOneWidget);
    });

    testWidgets(
        'buyer accepts a quote and lands on an order with payment disclosure',
        (tester) async {
      final store = await _boot(tester, Role.buyer);
      await tester.tap(find.text('RFQs').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Portland Cement 50 kg').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept quote'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept').last);
      await tester.pumpAndSettle();
      expect(store.orders, hasLength(1));
      expect(find.text('ORD-0001'), findsOneWidget);
      expect(find.text('SLE 112,000'), findsOneWidget);
      expect(find.text('Pending unverified'), findsOneWidget);
    });

    testWidgets('supplier sees inbox, sends a quote with validation',
        (tester) async {
      final store = await _boot(tester, Role.supplier);
      await tester.tap(find.text('RFQs').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sand (tipper load)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send quote').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send quote').last);
      await tester.pumpAndSettle();
      expect(find.text('Enter a price above zero'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '1500');
      await tester.tap(find.text('Send quote').last);
      await tester.pumpAndSettle();
      final rfq =
          store.rfqs.firstWhere((r) => r.productName.startsWith('Sand'));
      expect(rfq.quotes.single.unitPrice, 1500);
      expect(rfq.status, RfqStatus.quoted);
    });

    testWidgets('chat messages send as the current persona', (tester) async {
      final store = await _boot(tester, Role.buyer);
      await tester.tap(find.text('Messages').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Freetown Building Supply'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Can you deliver Monday?');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Can you deliver Monday?'), findsOneWidget);
      expect(store.threads.first.messages.last.from, Role.buyer);
    });
  });
}
