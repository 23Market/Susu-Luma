import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/auth/auth_page.dart';
import 'package:susu_luma/auth/mfa_page.dart';
import 'package:susu_luma/auth/password_recovery_pages.dart';

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

  testWidgets('sign in validates email before contacting the backend',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthPage()));
    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'not-an-email');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'irrelevant');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('native sign in reports an unavailable backend safely',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthPage()));
    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'buyer@example.com');
    await tester.enterText(
        find.widgetWithText(TextField, 'Password'), 'Str0ng!Password-2026');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Unable to connect. Try again later.'), findsOneWidget);
  });

  testWidgets('forgot password keeps account existence private',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordPage()));
    await tester.enterText(
        find.widgetWithText(TextField, 'Email'), 'buyer@example.com');
    await tester.tap(find.text('Send reset instructions'));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'If the account exists, password-reset instructions have been sent.'),
      findsOneWidget,
    );
  });

  testWidgets('password reset rejects weak passwords before backend access',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PasswordResetPage()));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'New password'), 'password123');
    await tester.tap(find.text('Update password'));
    await tester.pump();

    expect(find.textContaining('12 characters'), findsOneWidget);
    expect(find.textContaining('common or predictable'), findsOneWidget);
  });

  testWidgets('password reset reports a backend failure without crashing',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PasswordResetPage()));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'New password'), 'Str0ng!Password-2026');
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();

    expect(find.text('Password could not be updated.'), findsOneWidget);
  });

  testWidgets('MFA enrollment failure leaves a recoverable screen',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MfaPage()));
    await tester.tap(find.text('Set up authenticator app'));
    await tester.pumpAndSettle();

    expect(
      find.text('Authenticator setup could not be started.'),
      findsOneWidget,
    );
    expect(find.text('Set up authenticator app'), findsOneWidget);
  });

  testWidgets('MFA reports rejected or unavailable verification',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MfaPage(initialFactorId: 'factor-id')),
    );
    await tester.enterText(
        find.widgetWithText(TextField, 'Six-digit code'), '123456');
    await tester.tap(find.text('Verify and enable'));
    await tester.pumpAndSettle();

    expect(find.text('The code is invalid or expired.'), findsOneWidget);
  });
}
