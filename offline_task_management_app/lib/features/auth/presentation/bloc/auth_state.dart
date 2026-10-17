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

/// Signed out, or started up with no session to restore.
///
/// Distinct from [AuthFailure] on purpose: finding no saved session on a fresh
/// install is the normal case, not an error, and showing the user a red
/// "no active session" snackbar every cold start would be nonsense.
final class AuthLoggedOut extends AuthState {
  const AuthLoggedOut();
}
