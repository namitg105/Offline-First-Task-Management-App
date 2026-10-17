import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../entities/user.dart';

part 'app_user_event.dart';
part 'app_user_state.dart';

/// Holds "who is signed in right now" for the WHOLE app lifetime.
///
/// Why separate from AuthBloc?
/// - AuthBloc answers "did this sign-in attempt succeed?" — a one-off action.
/// - AppUserBloc answers "is somebody signed in?" — a long-lived fact.
///
/// Separation of Concerns: the Tasks feature reads this to know whose tasks to
/// load, without importing anything from `features/auth`.
///
/// It was a Cubit, and a Cubit would still be enough — it has no asynchronous
/// work and two possible transitions. It is a Bloc now so that every state
/// change in the app arrives the same way, as a named past-tense event you can
/// see in the logs, rather than some screens dispatching events and others
/// calling methods.
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
