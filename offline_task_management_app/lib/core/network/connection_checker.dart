import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// "Can we reach the internet right now, and tell me when that changes."
///
/// The repository and the sync engine depend on THIS interface, never on the
/// package. Dependency Inversion: swapping the connectivity library later
/// touches exactly one file.
///
/// Note it checks real reachability, not just "wifi icon is on". A phone
/// connected to a captive-portal hotspot reports wifi but cannot reach
/// Supabase, and syncing against that would fail every time.
abstract interface class ConnectionChecker {
  Future<bool> get isConnected;

  /// Emits true when connectivity returns, false when it is lost.
  Stream<bool> get onStatusChange;
}

class ConnectionCheckerImpl implements ConnectionChecker {
  final InternetConnection internetConnection;

  const ConnectionCheckerImpl(this.internetConnection);

  @override
  Future<bool> get isConnected async =>
      await internetConnection.hasInternetAccess;

  @override
  Stream<bool> get onStatusChange => internetConnection.onStatusChange
      .map((status) => status == InternetStatus.connected);
}
