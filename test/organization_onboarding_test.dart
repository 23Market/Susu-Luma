import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/auth/organization_onboarding_page.dart';

void main() {
  testWidgets(
      'requires legal and display names before creating an organisation',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: OrganizationOnboardingPage()),
    );

    await tester.tap(find.text('Create organisation'));
    await tester.pump();

    expect(find.text('Enter at least two characters.'), findsNWidgets(2));
    expect(find.textContaining('does not grant verified-supplier status'),
        findsOneWidget);
  });
}
