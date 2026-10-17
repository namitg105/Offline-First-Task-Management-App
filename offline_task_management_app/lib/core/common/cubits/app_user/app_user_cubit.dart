import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../entities/user.dart';

part 'app_user_state.dart';

/// Holds "who is signed in right now" for the WHOLE app lifetime.
///
/// Why separate from AuthBloc?
/// - AuthBloc answers "did this login attempt succeed?" (a one-off action).
/// - AppUserCubit answers "is somebody signed in?" (a long-lived fact).
///
/// Separation of Concerns: the Tasks feature will read AppUserCubit to know
/// whose tasks to load, without ever importing anything from `features/auth`.
class AppUserCubit extends Cubit<AppUserState> {
  AppUserCubit() : super(AppUserInitial());

  void updateUser(User? user) {
    if (user == null) {
      emit(AppUserInitial());
    } else {
      emit(AppUserLoggedIn(user));
    }
  }
}
