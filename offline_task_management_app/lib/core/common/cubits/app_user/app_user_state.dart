part of 'app_user_cubit.dart';

@immutable
sealed class AppUserState {}

/// Nobody is signed in (or we have not checked yet).
final class AppUserInitial extends AppUserState {}

/// Someone is signed in; [user] is who.
final class AppUserLoggedIn extends AppUserState {
  final User user;
  AppUserLoggedIn(this.user);
}
