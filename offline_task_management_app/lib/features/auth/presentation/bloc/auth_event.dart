part of 'auth_bloc.dart';

/// Events are named in the PAST TENSE, because an event records something
/// that has already happened in the UI — the user submitted the form, pressed
/// the button, asked for a sync. They are not commands telling the bloc what
/// to do; the bloc decides that. `AuthLoginSubmitted` reads as a fact,
/// `AuthLogin` reads as an order.
@immutable
sealed class AuthEvent {
  const AuthEvent();
}

/// The sign-up form passed validation and was submitted.
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

/// The login form passed validation and was submitted.
final class AuthLoginSubmitted extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginSubmitted({required this.email, required this.password});
}

/// The "Continue with Google" button was pressed.
final class AuthGoogleSignInPressed extends AuthEvent {
  const AuthGoogleSignInPressed();
}

/// The app started and asked whether this device still holds a session.
/// Works offline — see AuthRepositoryImpl.currentUser().
final class AuthSessionRestoreRequested extends AuthEvent {
  const AuthSessionRestoreRequested();
}

/// The log-out button was pressed.
final class AuthLogoutPressed extends AuthEvent {
  const AuthLogoutPressed();
}

/// The UI has shown the current failure message and it can be cleared.
final class AuthErrorDismissed extends AuthEvent {
  const AuthErrorDismissed();
}
