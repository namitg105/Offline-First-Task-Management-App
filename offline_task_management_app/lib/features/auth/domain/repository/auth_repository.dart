import 'package:fpdart/fpdart.dart';

import '../../../../core/common/entities/user.dart';
import '../../../../core/error/failures.dart';

/// The CONTRACT. Pure Dart — it mentions no Supabase, no HTTP, no SQL.
///
/// The domain layer owns this file and the data layer implements it. That
/// inverted arrow is what lets you swap Supabase for Firebase later without
/// touching a single line of domain or presentation code.
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
