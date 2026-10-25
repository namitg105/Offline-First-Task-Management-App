class Validators {
  const Validators._();

  static final RegExp _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  static String? email(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Email is required';
    if (!_emailPattern.hasMatch(input)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final input = value ?? '';
    if (input.isEmpty) return 'Password is required';
    // Supabase rejects anything shorter than 6 by default — fail fast on the
    // device instead of paying for a round trip to learn that.
    if (input.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? name(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return 'Name is required';
    if (input.length < 2) return 'Name is too short';
    return null;
  }
}
