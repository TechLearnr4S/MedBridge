/// Centralised input validators for MedBridge forms.
///
/// Every function returns `null` when valid, or an error string when invalid.
library;

/// Email regex: requires proper format ending with @gmail.com.
final RegExp kEmailRegex = RegExp(
  r'^[a-zA-Z0-9._%+-]+@gmail\.com$',
  caseSensitive: false,
);

/// General email format check (any valid domain).
final RegExp _generalEmailRegex = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);

/// Validate an email address - must be a valid @gmail.com address.
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email is required';
  }
  final email = value.trim();
  if (!email.contains('@')) {
    return 'Email must contain @ symbol';
  }
  if (!_generalEmailRegex.hasMatch(email)) {
    return 'Enter a valid email address';
  }
  if (!kEmailRegex.hasMatch(email)) {
    return 'Only @gmail.com email addresses are accepted';
  }
  return null;
}

/// Validate a password with strong requirements.
///
/// Rules: min 8 chars, at least 1 uppercase, 1 lowercase, 1 digit, 1 special.
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }
  if (value.length < 8) {
    return 'Password must be at least 8 characters';
  }
  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    return 'Must contain at least 1 uppercase letter (A-Z)';
  }
  if (!RegExp(r'[a-z]').hasMatch(value)) {
    return 'Must contain at least 1 lowercase letter (a-z)';
  }
  if (!RegExp(r'[0-9]').hasMatch(value)) {
    return 'Must contain at least 1 number (0-9)';
  }
  if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]').hasMatch(value)) {
    return 'Must contain at least 1 special character (!@#\$%...)';
  }
  return null;
}

/// Calculate password strength as a value between 0.0 and 1.0.
({double strength, String label, int colorIndex}) passwordStrength(String pw) {
  if (pw.isEmpty) return (strength: 0, label: '', colorIndex: 0);

  double score = 0;

  // Length scoring
  if (pw.length >= 8) score += 0.2;
  if (pw.length >= 12) score += 0.1;

  // Character variety scoring
  if (RegExp(r'[a-z]').hasMatch(pw)) score += 0.15;
  if (RegExp(r'[A-Z]').hasMatch(pw)) score += 0.15;
  if (RegExp(r'[0-9]').hasMatch(pw)) score += 0.15;
  if (RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]').hasMatch(pw)) {
    score += 0.15;
  }

  // Bonus for long passwords
  if (pw.length >= 16) score += 0.1;

  score = score.clamp(0.0, 1.0);

  String label;
  int colorIndex;
  if (score < 0.2) {
    label = 'Very Weak';
    colorIndex = 0;
  } else if (score < 0.4) {
    label = 'Weak';
    colorIndex = 1;
  } else if (score < 0.6) {
    label = 'Fair';
    colorIndex = 2;
  } else if (score < 0.8) {
    label = 'Strong';
    colorIndex = 3;
  } else {
    label = 'Very Strong';
    colorIndex = 4;
  }

  return (strength: score, label: label, colorIndex: colorIndex);
}

/// Validate a required text field.
String? validateRequired(String? value, String fieldName) {
  if (value == null || value.trim().isEmpty) {
    return '$fieldName is required';
  }
  return null;
}

/// Validate a phone number (10 digits).
String? validatePhone(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Phone number is required';
  }
  final digits = value.trim().replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length != 10) {
    return 'Enter a valid 10-digit phone number';
  }
  return null;
}

/// Validate a name (at least 2 characters, no numbers).
String? validateName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Name is required';
  }
  if (value.trim().length < 2) {
    return 'Name must be at least 2 characters';
  }
  if (RegExp(r'[0-9]').hasMatch(value)) {
    return 'Name should not contain numbers';
  }
  return null;
}

/// Validate date of birth (must be in the past, age < 120).
String? validateDOB(DateTime? dob) {
  if (dob == null) return 'Date of birth is required';
  final now = DateTime.now();
  if (dob.isAfter(now)) return 'Date of birth must be in the past';
  final age = now.year - dob.year -
      ((now.month < dob.month ||
              (now.month == dob.month && now.day < dob.day))
          ? 1
          : 0);
  if (age >= 120) return 'Please enter a valid date of birth';
  return null;
}

/// Validate a medical registration number (alphanumeric, 5-20 chars).
String? validateMedRegNo(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Medical registration number is required';
  }
  final v = value.trim();
  if (v.length < 5 || v.length > 20) {
    return 'Must be 5-20 characters';
  }
  if (!RegExp(r'^[A-Za-z0-9/-]+$').hasMatch(v)) {
    return 'Only letters, numbers, / and - are allowed';
  }
  return null;
}

/// Validate a fee (positive integer).
String? validateFee(String? value) {
  if (value == null || value.trim().isEmpty) return 'Fee is required';
  final n = int.tryParse(value.trim());
  if (n == null || n <= 0) return 'Enter a valid fee amount';
  return null;
}

/// Validate experience years (0-60).
String? validateExperience(String? value) {
  if (value == null || value.trim().isEmpty) return 'Experience is required';
  final n = int.tryParse(value.trim());
  if (n == null || n < 0 || n > 60) return 'Enter a value between 0 and 60';
  return null;
}
