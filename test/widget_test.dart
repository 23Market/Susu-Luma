import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/main.dart';

void main() {
  testWidgets('shows the Susu Luma marketplace home', (tester) async {
    await tester.pumpWidget(const SusuLumaApp());
    expect(find.text('susu luma'), findsOneWidget);
    expect(find.text('Browse categories'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sample listings'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sample listings'), findsOneWidget);
  });

  testWidgets('discover tab filters sample products', (tester) async {
    await tester.pumpWidget(const SusuLumaApp());
    await tester.tap(find.text('Discover').last);
    await tester.pumpAndSettle();
    expect(find.text('Discover products'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).first, 'cocoa');
    await tester.pumpAndSettle();
    expect(find.text('Fresh Cocoa Beans'), findsOneWidget);
    expect(find.text('Portland Cement'), findsNothing);
  });

  testWidgets('RFQ composer validates and saves a local draft', (tester) async {
    await tester.pumpWidget(const SusuLumaApp());
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    final requestQuote = find
        .widgetWithText(OutlinedButton, 'Request quote')
        .hitTestable()
        .first;
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
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    final requestQuote = find
        .widgetWithText(OutlinedButton, 'Request quote')
        .hitTestable()
        .first;
    await tester.tap(requestQuote);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('My RFQs'), findsNothing);
    expect(find.textContaining('Portland Cement ·'), findsNothing);
  });
}
