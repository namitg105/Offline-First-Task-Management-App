import 'package:fpdart/fpdart.dart';

import '../error/failures.dart';

/// Every use case in the app implements this one contract.
///
/// Think of a use case as a verb the app can do: "sign the user up",
/// "log the user in". One class = one verb = Single Responsibility Principle.
///
/// Because it defines `call`, a use case instance can be invoked like a
/// function:
///
/// ```dart
/// final userLogin = UserLogin(authRepository);
/// final result = await userLogin(UserLoginParams(email: e, password: p));
/// ```
abstract interface class UseCase<SuccessType, Params> {
  Future<Either<Failure, SuccessType>> call(Params params);
}

/// For use cases that need no input, e.g. CurrentUser / Logout.
class NoParams {
  const NoParams();
}
