import 'package:get_it/get_it.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/common/cubits/app_user/app_user_cubit.dart';
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

/// `serviceLocator` is the single place where concrete classes are chosen.
/// Everywhere else in the app only ever mentions interfaces.
final serviceLocator = GetIt.instance;

Future<void> initDependencies() async {
  await _initExternalServices();
  _initAuth();
}

Future<void> _initExternalServices() async {
  // Supabase.initialize() also RESTORES a saved session from disk, which is
  // why a returning user is already logged in before the first frame.
  final supabase = await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    anonKey: AppSecrets.supabaseAnonKey,
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
