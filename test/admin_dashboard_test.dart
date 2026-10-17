import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/admin/admin_dashboard.dart';

void main() {
  testWidgets('shows business metrics and sample-data boundary',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AdminDashboard()),
    );

    expect(find.text('Business overview'), findsOneWidget);
    expect(find.text('Monthly revenue'), findsOneWidget);
    expect(find.text('SLE 32,500'), findsWidgets);
    expect(find.text('Illustrative business metrics'), findsOneWidget);
  });

  testWidgets('navigates to the revenue model and financial boundary',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AdminDashboard()),
    );
    await tester.tap(find.text('Revenue'));
    await tester.pumpAndSettle();

    expect(find.text('Revenue model'), findsOneWidget);
    expect(find.text('Financial boundary'), findsOneWidget);
    expect(find.text('Monthly revenue composition'), findsOneWidget);
  });
}
