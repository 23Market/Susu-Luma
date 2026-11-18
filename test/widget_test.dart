import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/main.dart';


// DIAGNOSTIC: test whether the failures come from lazily built list items outside the default
// 800x600 test viewport. A tall viewport makes every item build.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('shows the Susu Luma marketplace home', (tester) async {
    _tall(tester);
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

  testWidgets(
      'request quote creates a local draft and warns backend is not connected',
      (tester) async {
    _tall(tester);
    await tester.pumpWidget(const SusuLumaApp());
    await tester.ensureVisible(find.text('Request quote').first);
    await tester.tap(find.text('Request quote').first);
    await tester.pumpAndSettle();
    expect(find.text('My RFQs'), findsOneWidget);
    expect(find.textContaining('Portland Cement'), findsOneWidget);
    expect(find.textContaining('not connected yet'), findsOneWidget);
  });
}
