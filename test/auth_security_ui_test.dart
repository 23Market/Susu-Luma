import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/auth/auth_page.dart';
import 'package:susu_luma/auth/mfa_page.dart';

void main() {
  testWidgets('registration blocks a weak password before a network call',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthPage()));
    await tester.tap(find.text('Create a business account'));
    await tester.pump();

    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'buyer@example.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'password123!');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();

    expect(find.textContaining('common or predictable'), findsOneWidget);
    expect(find.textContaining('Password strength:'), findsNothing);
  });

  testWidgets('MFA challenge requires a six-digit authenticator code',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MfaPage(initialFactorId: 'factor-id')),
    );

    await tester.tap(find.text('Verify and enable'));
    await tester.pump();

    expect(
        find.text('Enter the six-digit authenticator code.'), findsOneWidget);
  });
}
