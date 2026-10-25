import 'package:fpdart/fpdart.dart';

import '../error/failures.dart';

/// Contract every use case implements: one class = one action the app can perform.
/// `call` lets an instance be invoked like a function: `await userLogin(params)`.
abstract interface class UseCase<SuccessType, Params> {
  Future<Either<Failure, SuccessType>> call(Params params);
}

/// For use cases that need no input, e.g. CurrentUser / Logout.
class NoParams {
  const NoParams();
}
