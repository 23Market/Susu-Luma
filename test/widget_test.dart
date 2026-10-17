import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/main.dart';

void main() {
  testWidgets('shows the Susu Luma marketplace home', (tester) async {
    await tester.pumpWidget(const SusuLumaApp());
    expect(find.text('susu luma'), findsOneWidget);
    expect(find.text('Browse categories'), findsOneWidget);
    expect(find.text('Sample listings'), findsOneWidget);
  });

  testWidgets('discover tab filters sample products', (tester) async {
    await tester.pumpWidget(const SusuLumaApp());
    await tester.tap(find.text('Discover').last);
    await tester.pumpAndSettle();
    expect(find.text('Discover products'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'cocoa');
    await tester.pumpAndSettle();
    expect(find.text('Fresh Cocoa Beans'), findsOneWidget);
    expect(find.text('Portland Cement'), findsNothing);
  });

  testWidgets('request quote creates a local draft and warns backend is not connected', (tester) async {
    await tester.pumpWidget(const SusuLumaApp());
    await tester.tap(find.text('Request quote').first);
    await tester.pumpAndSettle();
    expect(find.text('My RFQs'), findsOneWidget);
    expect(find.textContaining('Portland Cement'), findsOneWidget);
    expect(find.textContaining('not connected yet'), findsOneWidget);
  });
}
