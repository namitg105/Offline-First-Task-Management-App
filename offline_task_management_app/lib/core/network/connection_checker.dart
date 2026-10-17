import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Contract: "can we reach the internet right now?"
///
/// The repository depends on THIS interface, not on the package. That is the
/// Dependency Inversion Principle: swapping the connectivity package later
/// touches exactly one file.
abstract interface class ConnectionChecker {
  Future<bool> get isConnected;
}

class ConnectionCheckerImpl implements ConnectionChecker {
  final InternetConnection internetConnection;

  const ConnectionCheckerImpl(this.internetConnection);

  @override
  Future<bool> get isConnected async =>
      await internetConnection.hasInternetAccess;
}
