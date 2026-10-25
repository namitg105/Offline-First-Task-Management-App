import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../entities/user.dart';

part 'app_user_event.dart';
part 'app_user_state.dart';

/// Holds "who is signed in right now" for the whole app.
///
/// Separate from AuthBloc, which only reports the outcome of a sign-in attempt:
/// this is the long-lived session fact that Tasks and Sync read.
class AppUserBloc extends Bloc<AppUserEvent, AppUserState> {
  AppUserBloc() : super(const AppUserInitial()) {
    on<AppUserSessionStarted>(_onAppUserSessionStarted);
    on<AppUserSessionEnded>(_onAppUserSessionEnded);
  }

  void _onAppUserSessionStarted(
    AppUserSessionStarted event,
    Emitter<AppUserState> emit,
  ) {
    emit(AppUserLoggedIn(event.user));
  }

  void _onAppUserSessionEnded(
    AppUserSessionEnded event,
    Emitter<AppUserState> emit,
  ) {
    emit(const AppUserInitial());
  }
}
