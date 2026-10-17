import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/common/blocs/app_user/app_user_bloc.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/sync/presentation/bloc/sync_bloc.dart';
import 'features/tasks/data/datasources/task_local_data_source.dart';
import 'features/tasks/presentation/bloc/task_bloc.dart';
import 'features/tasks/presentation/pages/task_list_page.dart';
import 'init_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => serviceLocator<AppUserBloc>()),
        BlocProvider(create: (_) => serviceLocator<AuthBloc>()),
        BlocProvider(create: (_) => serviceLocator<TaskBloc>()),
        BlocProvider(create: (_) => serviceLocator<SyncBloc>()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Ask once: "is there still a session on this device?"
    // Works offline — see AuthRepositoryImpl.currentUser().
    context.read<AuthBloc>().add(const AuthSessionRestoreRequested());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Offline Tasks',
      theme: AppTheme.darkThemeMode,
      // The app shell is the one place features are allowed to meet.
      // `auth` never imports `sync`, `sync` never imports `auth`; each one
      // reports what happened and this listener forwards it on.
      home: MultiBlocListener(
        listeners: [
          BlocListener<AuthBloc, AuthState>(listener: _onAuthStateChanged),
          BlocListener<AppUserBloc, AppUserState>(listener: _onSessionChanged),
        ],
        child: BlocSelector<AppUserBloc, AppUserState, bool>(
          selector: (state) => state is AppUserLoggedIn,
          builder: (context, isLoggedIn) =>
              isLoggedIn ? const TaskListPage() : const LoginPage(),
        ),
      ),
    );
  }

  /// AuthBloc reports the outcome of a sign-in attempt. Turning that into
  /// "there is now a session" is this shell's job, not AuthBloc's — which is
  /// why AuthBloc no longer holds a reference to AppUserBloc.
  void _onAuthStateChanged(BuildContext context, AuthState state) {
    final appUserBloc = context.read<AppUserBloc>();
    if (state is AuthSuccess) {
      appUserBloc.add(AppUserSessionStarted(state.user));
    } else if (state is AuthLoggedOut) {
      appUserBloc.add(const AppUserSessionEnded());
    }
  }

  /// Everything that has to happen when the signed-in user changes.
  void _onSessionChanged(BuildContext context, AppUserState state) {
    final syncBloc = context.read<SyncBloc>();

    if (state is AppUserLoggedIn) {
      // The task subscription follows the SESSION, not the screen, so it is
      // started here rather than in TaskListPage.initState.
      context.read<TaskBloc>().add(TasksSubscriptionRequested(state.user.id));
      syncBloc.add(SyncWatchStarted(state.user.id));
      return;
    }

    // Logged out: stop the worker, then wipe the local database.
    //
    // Wiping matters on a shared phone. Tasks are cached on disk and readable
    // offline by design, so leaving them behind would let the next person to
    // sign in read the previous user's work.
    syncBloc.add(const SyncWatchStopped());
    serviceLocator<TaskLocalDataSource>().clear();
  }
}
