import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/admin/admin_dashboard.dart';

class TestRepository implements AdminRepository {
  TestRepository(this.read);
  final Future<AdminSnapshot> Function() read;
  @override
  Future<AdminSnapshot> load() => read();
}

void main() {
  testWidgets('unconfigured console fails closed and offers retry',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminDashboard()));
    await tester.pumpAndSettle();
    expect(find.text('Admin records unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Approve'), findsNothing);
  });

  testWidgets('loading, empty and retry success states', (tester) async {
    final pending = Completer<AdminSnapshot>();
    var attempts = 0;
    final repository = TestRepository(() {
      attempts++;
      return attempts == 1
          ? pending.future
          : Future.value(AdminSnapshot(
              updatedAt: DateTime.utc(2026, 11, 12), records: []));
    });
    await tester
        .pumpWidget(MaterialApp(home: AdminDashboard(repository: repository)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(StateError('unavailable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('0 records'), findsOneWidget);
    expect(find.textContaining('No records match'), findsOneWidget);
  });

  testWidgets('wide navigation scopes records and search', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = TestRepository(() async =>
        AdminSnapshot(updatedAt: DateTime.utc(2026, 11, 12), records: const [
          AdminRecord(
              reference: 'S-1',
              section: 'Supplier verification',
              title: 'Synthetic supplier',
              status: 'pending'),
          AdminRecord(
              reference: 'P-1',
              section: 'Payment status',
              title: 'Synthetic payment',
              status: 'pending_unverified'),
        ]));
    await tester
        .pumpWidget(MaterialApp(home: AdminDashboard(repository: repository)));
    await tester.pumpAndSettle();
    expect(find.text('2 records'), findsOneWidget);
    await tester.tap(find.text('Payment status').first);
    await tester.pumpAndSettle();
    expect(find.text('Synthetic supplier'), findsNothing);
    expect(find.text('pending_unverified'), findsOneWidget);
    expect(find.textContaining('does not hold or settle'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    expect(find.text('0 records'), findsOneWidget);
  });
}
