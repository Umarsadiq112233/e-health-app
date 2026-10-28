class AuthUser {
  final String id;
  final String email;
  final String name;
  final String weight;
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    this.weight = '70',
  });
}

class AuthSessionChange {
  final AuthUser? user;
  final bool recovery, processing;
  const AuthSessionChange(
    this.user, {
    this.recovery = false,
    this.processing = false,
  });
}

class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);
}
