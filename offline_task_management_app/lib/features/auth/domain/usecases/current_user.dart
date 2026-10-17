import 'package:fpdart/fpdart.dart';

import '../../../../core/common/entities/user.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repository/auth_repository.dart';

/// Runs once at app start: "is there still a valid session on this device?"
class CurrentUser implements UseCase<User, NoParams> {
  final AuthRepository authRepository;

  const CurrentUser(this.authRepository);

  @override
  Future<Either<Failure, User>> call(NoParams params) {
    return authRepository.currentUser();
  }
}
