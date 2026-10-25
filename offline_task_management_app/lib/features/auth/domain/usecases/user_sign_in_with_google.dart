import 'package:fpdart/fpdart.dart';

import '../../../../core/common/entities/user.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repository/auth_repository.dart';

/// Takes no input: the Google account picker collects everything.
class UserSignInWithGoogle implements UseCase<User, NoParams> {
  final AuthRepository authRepository;
  
  const UserSignInWithGoogle(this.authRepository);

  @override
  Future<Either<Failure, User>> call(NoParams params) {
    return authRepository.signInWithGoogle();
  }
}
