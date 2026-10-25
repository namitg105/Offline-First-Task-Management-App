import 'package:equatable/equatable.dart';

/// The expected, handled form of an error. The repository turns data-layer
/// exceptions into Failures, so domain and presentation need no try/catch.
sealed class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

/// The backend was reachable but refused / errored (bad password, 409, 500...).
final class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'No internet connection. Please try again when you are online.',
  ]);
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}
