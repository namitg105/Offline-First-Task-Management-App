import 'package:fpdart/fpdart.dart';

import '../../../../core/common/entities/user.dart';
import '../../../../core/error/failures.dart';

/// The contract. Pure Dart: no Supabase, HTTP or SQL. The domain owns it and the
/// data layer implements it.
abstract interface class AuthRepository {
  Future<Either<Failure, User>> signUpWithEmailPassword({
    required String name,
    required String email,
    required String password,
  });

  Future<Either<Failure, User>> loginWithEmailPassword({
    required String email,
    required String password,
  });

  Future<Either<Failure, User>> signInWithGoogle();

  /// Restores the session on app start. Must work OFFLINE.
  Future<Either<Failure, User>> currentUser();

  Future<Either<Failure, Unit>> logout();
}
