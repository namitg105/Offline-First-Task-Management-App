import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../../core/common/entities/user.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/connection_checker.dart';
import '../../domain/repository/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

/// The bridge. Its two jobs:
///   1. Turn thrown exceptions into returned [Failure]s.
///   2. Decide online vs offline behaviour.
///
/// Nothing above this class ever sees a try/catch again.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final ConnectionChecker connectionChecker;

  const AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.connectionChecker,
  });

  @override
  Future<Either<Failure, User>> signUpWithEmailPassword({
    required String name,
    required String email,
    required String password,
  }) {
    return _authenticate(
      () => remoteDataSource.signUpWithEmailPassword(
        name: name,
        email: email,
        password: password,
      ),
    );
  }

  @override
  Future<Either<Failure, User>> loginWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _authenticate(
      () => remoteDataSource.loginWithEmailPassword(
        email: email,
        password: password,
      ),
    );
  }

  @override
  Future<Either<Failure, User>> signInWithGoogle() {
    return _authenticate(() => remoteDataSource.signInWithGoogle());
  }

  /// The only method that is allowed to succeed with no internet.
  ///
  /// Offline-first rule: a user who logged in yesterday must reach their task
  /// list today on the train, with no signal. Supabase already persisted the
  /// session on disk, so we read the user straight out of it.
  @override
  Future<Either<Failure, User>> currentUser() async {
    try {
      if (!await connectionChecker.isConnected) {
        final cached = remoteDataSource.cachedUserFromSession;
        if (cached == null) {
          return left(const NetworkFailure(
            'You are offline and this device has no saved session. '
            'Connect to the internet once to sign in.',
          ));
        }
        return right(cached);
      }

      final user = await remoteDataSource.getCurrentUserData();
      if (user == null) {
        return left(const ServerFailure('No active session. Please log in.'));
      }
      return right(user);
    } on ServerException catch (e) {
      // We are online but the profile fetch failed. If a session exists we
      // would still rather let the user in than lock them out.
      final cached = remoteDataSource.cachedUserFromSession;
      if (cached != null) return right(cached);
      return left(ServerFailure(e.message));
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> logout() async {
    try {
      await remoteDataSource.logout();
      return right(unit);
    } on AuthException catch (e) {
      return left(ServerFailure(e.message));
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  /// DRY: all three sign-in paths need the same connectivity check and the
  /// same exception-to-Failure translation. Written once, used three times.
  Future<Either<Failure, User>> _authenticate(
    Future<User> Function() action,
  ) async {
    try {
      if (!await connectionChecker.isConnected) {
        return left(const NetworkFailure(
          'Signing in needs an internet connection.',
        ));
      }
      return right(await action());
    } on ServerException catch (e) {
      return left(ServerFailure(e.message));
    } on AuthException catch (e) {
      return left(ServerFailure(e.message));
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }
}
