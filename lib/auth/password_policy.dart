class PasswordAssessment {
  const PasswordAssessment({required this.score, required this.errors});

  final int score;
  final List<String> errors;

  bool get isAcceptable => errors.isEmpty;

  String get label => switch (score) {
        0 || 1 => 'Very weak',
        2 => 'Weak',
        3 => 'Good',
        _ => 'Strong',
      };
}

class PasswordPolicy {
  static const _blocked = {
    'password',
    'password123',
    'password123!',
    '12345678',
    '123456789',
    'qwerty123',
    'letmein',
    'admin123',
    'welcome123',
    'susuluma123',
  };

  static PasswordAssessment assess(String password) {
    final errors = <String>[];
    final hasLower = RegExp('[a-z]').hasMatch(password);
    final hasUpper = RegExp('[A-Z]').hasMatch(password);
    final hasDigit = RegExp('[0-9]').hasMatch(password);
    final hasSymbol =
        RegExp(r'''[!@#$%^&*()_+\-=[\]{};'":|<>?,./`~\\]''').hasMatch(password);
    if (password.length < 12) errors.add('Use at least 12 characters.');
    if (!hasLower) errors.add('Add a lowercase letter.');
    if (!hasUpper) errors.add('Add an uppercase letter.');
    if (!hasDigit) errors.add('Add a number.');
    if (!hasSymbol) errors.add('Add a symbol.');

    final normalized = password.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (_blocked.contains(normalized) ||
        RegExp(r'^(.)\1{7,}$').hasMatch(normalized) ||
        normalized.contains('123456') ||
        normalized.contains('qwerty')) {
      errors.add('Choose a password that is not common or predictable.');
    }

    var score = 0;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;
    if (hasLower && hasUpper && hasDigit && hasSymbol) score++;
    if (password.length >= 20 && !_blocked.contains(normalized)) score++;
    if (errors.any((error) => error.contains('common or predictable'))) {
      score = 0;
    }
    return PasswordAssessment(
      score: score.clamp(0, 4),
      errors: List.unmodifiable(errors),
    );
  }
}
