import 'package:equatable/equatable.dart';

/// A [Failure] is the "expected, handled" version of an error.
///
/// Data layer throws exceptions -> repository converts them to Failures ->
/// domain and presentation only ever see Failures. This is why the domain
/// layer never needs a single try/catch.
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

/// There is no usable internet connection right now.
final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'No internet connection. Please try again when you are online.',
  ]);
}

/// Something went wrong reading/writing the on-device cache.
final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}
