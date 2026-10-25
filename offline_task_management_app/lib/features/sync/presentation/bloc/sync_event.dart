part of 'sync_bloc.dart';

@immutable
sealed class SyncEvent {
  const SyncEvent();
}

/// A user signed in: start the background worker for them.
final class SyncWatchStarted extends SyncEvent {
  final String userId;
  const SyncWatchStarted(this.userId);
}

/// The user signed out: tear the worker down, timers and all.
final class SyncWatchStopped extends SyncEvent {
  const SyncWatchStopped();
}

/// Somebody asked for a sync right now — pull-to-refresh, or tapping the
/// status banner after a failure.
final class SyncRequested extends SyncEvent {
  const SyncRequested();
}

/// Internal. The sync engine reported new progress. Its stream is fed back in as
/// an event so every state this bloc produces has exactly one source.
final class SyncStateReported extends SyncEvent {
  final SyncState state;
  const SyncStateReported(this.state);
}
