part of 'auth_bloc.dart';

/// Events are named in the past tense: they record something that already happened
/// in the UI (the form was submitted), not commands to the bloc.
@immutable
sealed class AuthEvent {
  const AuthEvent();
}

final class AuthSignUpSubmitted extends AuthEvent {
  final String name;
  final String email;
  final String password;

  const AuthSignUpSubmitted({
    required this.name,
    required this.email,
    required this.password,
  });
}

final class AuthLoginSubmitted extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginSubmitted({required this.email, required this.password});
}

final class AuthGoogleSignInPressed extends AuthEvent {
  const AuthGoogleSignInPressed();
}

/// The app started and asked whether this device still holds a session.
/// Works offline — see AuthRepositoryImpl.currentUser().
final class AuthSessionRestoreRequested extends AuthEvent {
  const AuthSessionRestoreRequested();
}

final class AuthLogoutPressed extends AuthEvent {
  const AuthLogoutPressed();
}

/// The UI has shown the current failure message and it can be cleared.
final class AuthErrorDismissed extends AuthEvent {
  const AuthErrorDismissed();
}
