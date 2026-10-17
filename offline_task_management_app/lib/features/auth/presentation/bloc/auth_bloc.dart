import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/cubits/app_user/app_user_cubit.dart';
import '../../../../core/common/entities/user.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/usecases/current_user.dart';
import '../../domain/usecases/user_login.dart';
import '../../domain/usecases/user_logout.dart';
import '../../domain/usecases/user_sign_in_with_google.dart';
import '../../domain/usecases/user_sign_up.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Turns user intentions (events) into UI states.
///
/// Notice what is NOT here: no Supabase, no HTTP, no SQL, no try/catch.
/// The bloc only knows five use cases and how to fold an Either.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final UserSignUp _userSignUp;
  final UserLogin _userLogin;
  final UserSignInWithGoogle _userSignInWithGoogle;
  final CurrentUser _currentUser;
  final UserLogout _userLogout;
  final AppUserCubit _appUserCubit;

  AuthBloc({
    required UserSignUp userSignUp,
    required UserLogin userLogin,
    required UserSignInWithGoogle userSignInWithGoogle,
    required CurrentUser currentUser,
    required UserLogout userLogout,
    required AppUserCubit appUserCubit,
  })  : _userSignUp = userSignUp,
        _userLogin = userLogin,
        _userSignInWithGoogle = userSignInWithGoogle,
        _currentUser = currentUser,
        _userLogout = userLogout,
        _appUserCubit = appUserCubit,
        super(const AuthInitial()) {
    // Any event first puts the UI into a loading state. One line instead of
    // repeating `emit(AuthLoading())` in five handlers (DRY).
    on<AuthEvent>((_, emit) => emit(const AuthLoading()));

    on<AuthSignUp>(_onAuthSignUp);
    on<AuthLogin>(_onAuthLogin);
    on<AuthGoogleSignIn>(_onAuthGoogleSignIn);
    on<AuthIsUserLoggedIn>(_onAuthIsUserLoggedIn);
    on<AuthLogout>(_onAuthLogout);
  }

  Future<void> _onAuthSignUp(AuthSignUp event, Emitter<AuthState> emit) async {
    final result = await _userSignUp(
      UserSignUpParams(
        name: event.name,
        email: event.email,
        password: event.password,
      ),
    );
    result.fold(
      (failure) => emit(AuthFailureState(failure.message)),
      (user) => _emitAuthSuccess(user, emit),
    );
  }

  Future<void> _onAuthLogin(AuthLogin event, Emitter<AuthState> emit) async {
    final result = await _userLogin(
      UserLoginParams(email: event.email, password: event.password),
    );
    result.fold(
      (failure) => emit(AuthFailureState(failure.message)),
      (user) => _emitAuthSuccess(user, emit),
    );
  }

  Future<void> _onAuthGoogleSignIn(
    AuthGoogleSignIn event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _userSignInWithGoogle(const NoParams());
    result.fold(
      (failure) => emit(AuthFailureState(failure.message)),
      (user) => _emitAuthSuccess(user, emit),
    );
  }

  Future<void> _onAuthIsUserLoggedIn(
    AuthIsUserLoggedIn event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _currentUser(const NoParams());
    result.fold(
      (failure) => emit(AuthFailureState(failure.message)),
      (user) => _emitAuthSuccess(user, emit),
    );
  }

  Future<void> _onAuthLogout(AuthLogout event, Emitter<AuthState> emit) async {
    final result = await _userLogout(const NoParams());
    result.fold(
      (failure) => emit(AuthFailureState(failure.message)),
      (_) {
        _appUserCubit.updateUser(null);
        emit(const AuthInitial());
      },
    );
  }

  /// Every successful path ends here: tell the app-wide cubit who is logged in,
  /// then tell the current screen the action succeeded.
  void _emitAuthSuccess(User user, Emitter<AuthState> emit) {
    _appUserCubit.updateUser(user);
    emit(AuthSuccess(user));
  }
}
