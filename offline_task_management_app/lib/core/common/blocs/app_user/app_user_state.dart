part of 'app_user_bloc.dart';

@immutable
sealed class AppUserState {
  const AppUserState();
}

/// Nobody is signed in (or we have not checked yet).
final class AppUserInitial extends AppUserState {
  const AppUserInitial();
}

/// Someone is signed in; [user] is who.
final class AppUserLoggedIn extends AppUserState {
  final User user;
  const AppUserLoggedIn(this.user);
}
