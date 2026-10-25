import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/entities/user.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/usecases/current_user.dart';
import '../../domain/usecases/user_login.dart';
import '../../domain/usecases/user_logout.dart';
import '../../domain/usecases/user_sign_in_with_google.dart';
import '../../domain/usecases/user_sign_up.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Turns user actions (events) into UI states. It holds no Supabase, HTTP or SQL,
/// and no reference to AppUserBloc: it only reports what happened and the app
/// shell forwards it.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final UserSignUp _userSignUp;
  final UserLogin _userLogin;
  final UserSignInWithGoogle _userSignInWithGoogle;
  final CurrentUser _currentUser;
  final UserLogout _userLogout;

  AuthBloc({
    required UserSignUp userSignUp,
    required UserLogin userLogin,
    required UserSignInWithGoogle userSignInWithGoogle,
    required CurrentUser currentUser,
    required UserLogout userLogout,
  })  : _userSignUp = userSignUp,
        _userLogin = userLogin,
        _userSignInWithGoogle = userSignInWithGoogle,
        _currentUser = currentUser,
        _userLogout = userLogout,
        super(const AuthInitial()) {
    // Every event except the dismissal shows the loading state, once here instead of
    // in each handler.
    on<AuthEvent>((event, emit) {
      if (event is! AuthErrorDismissed) emit(const AuthLoading());
    });

    on<AuthSignUpSubmitted>(_onAuthSignUpSubmitted);
    on<AuthLoginSubmitted>(_onAuthLoginSubmitted);
    on<AuthGoogleSignInPressed>(_onAuthGoogleSignInPressed);
    on<AuthSessionRestoreRequested>(_onAuthSessionRestoreRequested);
    on<AuthLogoutPressed>(_onAuthLogoutPressed);
    on<AuthErrorDismissed>(_onAuthErrorDismissed);
  }

  Future<void> _onAuthSignUpSubmitted(
    AuthSignUpSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _userSignUp(UserSignUpParams(
      name: event.name,
      email: event.email,
      password: event.password,
    ));
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (user) => emit(AuthSuccess(user)),
    );
  }

  Future<void> _onAuthLoginSubmitted(
    AuthLoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _userLogin(
      UserLoginParams(email: event.email, password: event.password),
    );
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (user) => emit(AuthSuccess(user)),
    );
  }

  Future<void> _onAuthGoogleSignInPressed(
    AuthGoogleSignInPressed event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _userSignInWithGoogle(const NoParams());
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (user) => emit(AuthSuccess(user)),
    );
  }

  Future<void> _onAuthSessionRestoreRequested(
    AuthSessionRestoreRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _currentUser(const NoParams());
    result.fold(
      // No saved session is the normal first-run case, not a failure to
      // shout about. Go quietly to the login screen.
      (_) => emit(const AuthLoggedOut()),
      (user) => emit(AuthSuccess(user)),
    );
  }

  Future<void> _onAuthLogoutPressed(
    AuthLogoutPressed event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _userLogout(const NoParams());
    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (_) => emit(const AuthLoggedOut()),
    );
  }

  void _onAuthErrorDismissed(
    AuthErrorDismissed event,
    Emitter<AuthState> emit,
  ) {
    if (state is AuthFailure) emit(const AuthLoggedOut());
  }
}
