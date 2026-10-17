import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/common/cubits/app_user/app_user_cubit.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/sync/presentation/cubit/sync_cubit.dart';
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
        BlocProvider(create: (_) => serviceLocator<AppUserCubit>()),
        BlocProvider(create: (_) => serviceLocator<AuthBloc>()),
        BlocProvider(create: (_) => serviceLocator<TaskBloc>()),
        BlocProvider(create: (_) => serviceLocator<SyncCubit>()),
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
    context.read<AuthBloc>().add(AuthIsUserLoggedIn());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Offline Task Manager',
      theme: AppTheme.darkThemeMode,
      // The app shell is the right place to connect features to each other.
      // The auth feature does not import the sync feature, and the sync
      // feature does not import auth — they only ever meet here.
      home: BlocListener<AppUserCubit, AppUserState>(
        listener: _onSessionChanged,
        child: BlocSelector<AppUserCubit, AppUserState, bool>(
          selector: (state) => state is AppUserLoggedIn,
          builder: (context, isLoggedIn) =>
              isLoggedIn ? const TaskListPage() : const LoginPage(),
        ),
      ),
    );
  }

  void _onSessionChanged(BuildContext context, AppUserState state) {
    final syncCubit = context.read<SyncCubit>();

    if (state is AppUserLoggedIn) {
      syncCubit.start(state.user.id);
      return;
    }

    // Logged out: stop the worker, then wipe the local database.
    //
    // Wiping matters on a shared phone. The tasks are cached on disk and
    // readable offline by design, so leaving them behind would mean the next
    // person to sign in could see the previous user's work.
    syncCubit.stop();
    serviceLocator<TaskLocalDataSource>().clear();
  }
}
