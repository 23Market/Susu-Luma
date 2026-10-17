import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/main.dart';

void main() {
  testWidgets('shows Susu Luma marketplace and primary navigation', (tester) async {
    await tester.pumpWidget(const SusuLumaApp());
    expect(find.text('susu luma'), findsOneWidget);
    expect(find.text('Browse categories'), findsOneWidget);
    expect(find.text('Featured sourcing'), findsOneWidget);
    expect(find.text('Discover'), findsOneWidget);
  });

  testWidgets('can navigate to discovery and filter listings', (tester) async {
    await tester.pumpWidget(const SusuLumaApp());
    await tester.tap(find.text('Discover').last);
    await tester.pumpAndSettle();
    expect(find.text('Discover products'), findsOneWidget);
    expect(find.text('Portland Cement'), findsOneWidget);
    await tester.tap(find.text('Agriculture').first);
    await tester.pumpAndSettle();
    expect(find.text('Fresh Cocoa Beans'), findsOneWidget);
    expect(find.text('Portland Cement'), findsNothing);
  });
}
