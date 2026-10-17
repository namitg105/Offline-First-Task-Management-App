import 'package:equatable/equatable.dart';

/// What the app can honestly tell the user about synchronisation.
class SyncState extends Equatable {
  final bool isOnline;
  final bool isSyncing;

  /// How many local changes have not reached the server yet.
  final int pendingCount;

  final DateTime? lastSyncedAt;
  final String? errorMessage;

  const SyncState({
    this.isOnline = true,
    this.isSyncing = false,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.errorMessage,
  });

  bool get hasPending => pendingCount > 0;

  /// Everything the user did is safely on the server.
  bool get isFullySynced => isOnline && !isSyncing && pendingCount == 0;

  SyncState copyWith({
    bool? isOnline,
    bool? isSyncing,
    int? pendingCount,
    DateTime? lastSyncedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SyncState(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [isOnline, isSyncing, pendingCount, lastSyncedAt, errorMessage];
}
