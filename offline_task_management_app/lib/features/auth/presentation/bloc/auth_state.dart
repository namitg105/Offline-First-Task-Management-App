part of 'auth_bloc.dart';

@immutable
sealed class AuthState {
  const AuthState();
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthSuccess extends AuthState {
  final User user;
  const AuthSuccess(this.user);
}

final class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);
}

/// Signed out, or started with no session to restore. Kept distinct from
/// [AuthFailure]: no saved session on a fresh install is normal, not an error
/// to show the user.
final class AuthLoggedOut extends AuthState {
  const AuthLoggedOut();
}
