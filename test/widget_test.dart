import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/main.dart';

void main() {
  testWidgets('shows the Susu Luma marketplace home', (tester) async {
    await tester.pumpWidget(const SusuLumaApp());
    expect(
      find.bySemanticsLabel('Luma Industrial Marketplace Sierra Leone'),
      findsOneWidget,
    );
    expect(find.text('Choose a category'), findsOneWidget);
    expect(find.text('BUILDING'), findsOneWidget);
    expect(find.text('FARMING'), findsOneWidget);
    expect(find.text('Listen'), findsOneWidget);
  });

  testWidgets('discover tab filters sample products', (tester) async {
    await tester.pumpWidget(const SusuLumaApp());
    await tester.tap(find.text('Find products'));
    await tester.pumpAndSettle();
    expect(find.text('Browse Sierra Leone listings'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('discover-search')), 'cocoa');
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('discover-list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cocoa Beans'), findsOneWidget);
    expect(find.text('Portland Cement'), findsNothing);
  });

  testWidgets('RFQ composer validates and saves a local draft', (tester) async {
    await tester.pumpWidget(const SusuLumaApp());
    await tester.tap(find.text('Find products'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('discover-search')),
      'Portland Cement',
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('discover-list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    final requestQuote =
        find.widgetWithText(OutlinedButton, 'Request quote').first;
    await tester.tap(requestQuote);
    await tester.pumpAndSettle();

    expect(find.text('Request a quote'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Portland Cement'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Delivery location is required.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Delivery location').first,
      'Freetown',
    );
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();

    expect(find.text('My RFQs'), findsOneWidget);
    expect(find.textContaining('Portland Cement'), findsOneWidget);
    expect(find.textContaining('Local RFQ draft saved'), findsOneWidget);
  });

  testWidgets('cancelling RFQ composer does not create a draft', (
    tester,
  ) async {
    await tester.pumpWidget(const SusuLumaApp());
    await tester.tap(find.text('Find products'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('discover-search')),
      'Portland Cement',
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('discover-list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    final requestQuote =
        find.widgetWithText(OutlinedButton, 'Request quote').first;
    await tester.tap(requestQuote);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('My RFQs'), findsNothing);
    expect(find.textContaining('Portland Cement ·'), findsNothing);
  });

  testWidgets('category shortcuts apply the matching catalogue filter',
      (tester) async {
    await tester.pumpWidget(const SusuLumaApp());
    await tester.tap(find.text('BUILDING'));
    await tester.pumpAndSettle();

    expect(find.text('Browse Sierra Leone listings'), findsOneWidget);
    final construction = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Construction'),
    );
    expect(construction.selected, isTrue);
  });

  testWidgets('principal actions open quote discovery and business account',
      (tester) async {
    await tester.pumpWidget(const SusuLumaApp());
    await tester.drag(
      find.byType(ListView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('ASK FOR'));
    await tester.pumpAndSettle();
    expect(find.text('Browse Sierra Leone listings'), findsOneWidget);
    expect(find.text('Choose a product to request a quote.'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(ListView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('SELL AN'));
    await tester.pumpAndSettle();
    expect(find.text('Business profile'), findsOneWidget);
  });

  testWidgets('bottom navigation exposes orders, messages and account',
      (tester) async {
    await tester.pumpWidget(const SusuLumaApp());

    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    expect(find.text('My RFQs'), findsOneWidget);
    expect(find.text('Your quote requests will appear here.'), findsOneWidget);

    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(
        find.text('Supplier conversations will appear here.'), findsOneWidget);

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Business profile'), findsOneWidget);
  });

  testWidgets('Krio audio failure is explained without blocking navigation',
      (tester) async {
    await tester.pumpWidget(const SusuLumaApp());
    await tester.tap(find.text('Krio'));
    await tester.tap(find.text('Listen'));
    await tester.pumpAndSettle();

    expect(find.text('Krio'), findsOneWidget);
    expect(find.text('Find products'), findsOneWidget);
  });

  testWidgets('notification placeholder gives clear feedback', (tester) async {
    await tester.pumpWidget(const SusuLumaApp());
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();

    expect(
      find.text('Notifications will be available after backend integration.'),
      findsOneWidget,
    );
  });
}
