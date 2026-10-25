part of 'app_user_bloc.dart';

@immutable
sealed class AppUserEvent {
  const AppUserEvent();
}

/// A user signed in, by any route (password, Google, or a session restored at startup).
final class AppUserSessionStarted extends AppUserEvent {
  final User user;
  const AppUserSessionStarted(this.user);
}

/// The user signed out, or the session could not be restored.
final class AppUserSessionEnded extends AppUserEvent {
  const AppUserSessionEnded();
}
