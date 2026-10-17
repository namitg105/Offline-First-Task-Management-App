part of 'auth_bloc.dart';

@immutable
sealed class AuthEvent {}

final class AuthSignUp extends AuthEvent {
  final String name;
  final String email;
  final String password;

  AuthSignUp({
    required this.name,
    required this.email,
    required this.password,
  });
}

final class AuthLogin extends AuthEvent {
  final String email;
  final String password;

  AuthLogin({required this.email, required this.password});
}

final class AuthGoogleSignIn extends AuthEvent {}

/// Fired once when the app boots, to restore a previous session.
final class AuthIsUserLoggedIn extends AuthEvent {}

final class AuthLogout extends AuthEvent {}
