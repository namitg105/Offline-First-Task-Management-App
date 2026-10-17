import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'core/common/cubits/app_user/app_user_cubit.dart';
import 'core/database/app_database.dart';
import 'core/network/connection_checker.dart';
import 'core/secrets/app_secrets.dart';
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/datasources/google_auth_service.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repository/auth_repository.dart';
import 'features/auth/domain/usecases/current_user.dart';
import 'features/auth/domain/usecases/user_login.dart';
import 'features/auth/domain/usecases/user_logout.dart';
import 'features/auth/domain/usecases/user_sign_in_with_google.dart';
import 'features/auth/domain/usecases/user_sign_up.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/tasks/data/datasources/task_local_data_source.dart';
import 'features/tasks/data/datasources/task_remote_data_source.dart';
import 'features/tasks/data/repositories/task_repository_impl.dart';
import 'features/tasks/domain/repository/task_repository.dart';
import 'features/tasks/domain/usecases/create_task.dart';
import 'features/tasks/domain/usecases/delete_task.dart';
import 'features/tasks/domain/usecases/toggle_task_completion.dart';
import 'features/tasks/domain/usecases/update_task.dart';
import 'features/tasks/domain/usecases/watch_tasks.dart';
import 'features/tasks/presentation/bloc/task_bloc.dart';

/// `serviceLocator` is the single place where concrete classes are chosen.
/// Everywhere else in the app only ever mentions interfaces.
final serviceLocator = GetIt.instance;

Future<void> initDependencies() async {
  await _initExternalServices();
  _initAuth();
  _initTasks();
}

Future<void> _initExternalServices() async {
  // Supabase.initialize() also RESTORES a saved session from disk, which is
  // why a returning user is already logged in before the first frame.
  final supabase = await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    publishableKey: AppSecrets.supabasePublishableKey,
  );

  serviceLocator.registerLazySingleton<SupabaseClient>(() => supabase.client);
  serviceLocator.registerLazySingleton<GoogleSignIn>(() => GoogleSignIn.instance);
  serviceLocator.registerLazySingleton<InternetConnection>(
    () => InternetConnection(),
  );
  serviceLocator.registerLazySingleton<ConnectionChecker>(
    () => ConnectionCheckerImpl(serviceLocator()),
  );

  // One instance for the whole app lifetime: it holds the active session user.
  serviceLocator.registerLazySingleton<AppUserCubit>(() => AppUserCubit());

  // The SQLite file has exactly one owner.
  serviceLocator.registerLazySingleton<AppDatabase>(() => AppDatabase());

  serviceLocator.registerLazySingleton<Uuid>(() => const Uuid());
}

/// Registration order mirrors the dependency arrows:
/// data sources -> repository -> use cases -> bloc.
void _initAuth() {
  serviceLocator
    // Data sources
    ..registerFactory<GoogleAuthService>(
      () => GoogleAuthServiceImpl(serviceLocator()),
    )
    ..registerFactory<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(
        supabaseClient: serviceLocator(),
        googleAuthService: serviceLocator(),
      ),
    )
    // Repository
    ..registerFactory<AuthRepository>(
      () => AuthRepositoryImpl(
        remoteDataSource: serviceLocator(),
        connectionChecker: serviceLocator(),
      ),
    )
    // Use cases
    ..registerFactory(() => UserSignUp(serviceLocator()))
    ..registerFactory(() => UserLogin(serviceLocator()))
    ..registerFactory(() => UserSignInWithGoogle(serviceLocator()))
    ..registerFactory(() => CurrentUser(serviceLocator()))
    ..registerFactory(() => UserLogout(serviceLocator()))
    // Bloc
    ..registerLazySingleton(
      () => AuthBloc(
        userSignUp: serviceLocator(),
        userLogin: serviceLocator(),
        userSignInWithGoogle: serviceLocator(),
        currentUser: serviceLocator(),
        userLogout: serviceLocator(),
        appUserCubit: serviceLocator(),
      ),
    );
}

/// Tasks feature.
void _initTasks() {
  serviceLocator
    // Data sources
    // MUST be a lazy singleton, not a factory: this object owns the change
    // stream that every open screen listens to. A second instance would have
    // a second stream, and half the UI would stop updating.
    ..registerLazySingleton<TaskLocalDataSource>(
      () => TaskLocalDataSourceImpl(serviceLocator()),
    )
    ..registerFactory<TaskRemoteDataSource>(
      () => TaskRemoteDataSourceImpl(serviceLocator()),
    )
    // Repository
    ..registerFactory<TaskRepository>(
      () => TaskRepositoryImpl(
        localDataSource: serviceLocator(),
        uuid: serviceLocator(),
      ),
    )
    // Use cases
    ..registerFactory(() => WatchTasks(serviceLocator()))
    ..registerFactory(() => CreateTask(serviceLocator()))
    ..registerFactory(() => UpdateTask(serviceLocator()))
    ..registerFactory(() => ToggleTaskCompletion(serviceLocator()))
    ..registerFactory(() => DeleteTask(serviceLocator()))
    // Bloc
    ..registerLazySingleton(
      () => TaskBloc(
        watchTasks: serviceLocator(),
        createTask: serviceLocator(),
        updateTask: serviceLocator(),
        toggleTaskCompletion: serviceLocator(),
        deleteTask: serviceLocator(),
      ),
    );
}
