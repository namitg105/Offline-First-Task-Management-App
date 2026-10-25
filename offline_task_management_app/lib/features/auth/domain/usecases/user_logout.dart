import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repository/auth_repository.dart';

class UserLogout implements UseCase<Unit, NoParams> {
  final AuthRepository authRepository;

  const UserLogout(this.authRepository);

  @override
  Future<Either<Failure, Unit>> call(NoParams params) {
    return authRepository.logout();
  }
}
