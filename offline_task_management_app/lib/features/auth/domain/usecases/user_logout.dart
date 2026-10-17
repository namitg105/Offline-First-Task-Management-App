import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repository/auth_repository.dart';

/// `Unit` is fpdart's "nothing useful to return, but it succeeded".
/// It is the functional equivalent of `void`.
class UserLogout implements UseCase<Unit, NoParams> {
  final AuthRepository authRepository;

  const UserLogout(this.authRepository);

  @override
  Future<Either<Failure, Unit>> call(NoParams params) {
    return authRepository.logout();
  }
}
