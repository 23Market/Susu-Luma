import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/admin/admin_route_gate.dart';

void main() {
  testWidgets('admin route denies access when backend is unavailable',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdminRouteGate(backendAvailable: false)),
    );

    expect(find.text('Administrator access required'), findsOneWidget);
    expect(find.textContaining('backend is not configured'), findsOneWidget);
  });

  testWidgets('admin route denies an unverifiable native session',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdminRouteGate(backendAvailable: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administrator access required'), findsOneWidget);
    expect(find.textContaining('server-authorised'), findsOneWidget);
  });
}
