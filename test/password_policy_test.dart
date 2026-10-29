import 'package:flutter_test/flutter_test.dart';
import 'package:susu_luma/auth/password_policy.dart';

void main() {
  group('PasswordPolicy', () {
    test('rejects common and incomplete passwords', () {
      for (final password in [
        'password123!',
        '12345678',
        'qwerty123',
        'OnlyLettersHere',
      ]) {
        expect(PasswordPolicy.assess(password).isAcceptable, isFalse);
      }
    });

    test('accepts a long mixed-character password', () {
      final result = PasswordPolicy.assess('Susu!Market-2026-Strong');

      expect(result.isAcceptable, isTrue);
      expect(result.score, greaterThanOrEqualTo(3));
    });
  });
}
