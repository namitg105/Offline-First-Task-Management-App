import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Whether the internet is reachable right now, plus a stream of changes.
///
/// Checks real reachability, not just "wifi is on": a captive-portal hotspot
/// reports wifi but cannot reach Supabase.
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
