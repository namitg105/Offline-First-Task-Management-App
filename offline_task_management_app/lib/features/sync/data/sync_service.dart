import 'dart:async';
import 'dart:math';

import '../../../../core/error/exceptions.dart';
import '../../../../core/network/connection_checker.dart';
import '../../tasks/data/datasources/task_local_data_source.dart';
import '../../tasks/data/datasources/task_remote_data_source.dart';
import '../../tasks/data/models/outbox_entry.dart';
import '../domain/entities/sync_state.dart';

/// The background worker that reconciles the device database with Postgres.
///
/// It is the ONLY thing in the app allowed to be slow. Nothing the user does
/// waits on it: they write to SQLite, the UI updates, and this catches up
/// whenever it can.
///
/// Order matters: push first, then pull. Pushing first means our own pending
/// changes reach the server before we ask what the server has, so we never
/// pull a stale row over an edit that was about to overwrite it anyway.
class SyncService {
  final TaskLocalDataSource localDataSource;
  final TaskRemoteDataSource remoteDataSource;
  final ConnectionChecker connectionChecker;

  /// How long to wait after a local edit before pushing. Without this, typing
  /// a title would fire a request per keystroke-sized change.
  static const Duration _debounce = Duration(seconds: 2);

  /// A safety net for changes made while the app was closed, and for servers
  /// that came back without the connectivity stream noticing.
  static const Duration _heartbeat = Duration(minutes: 2);

  /// After this many failures an entry is parked with the maximum backoff
  /// instead of being retried tightly forever.
  static const int _maxTightRetries = 8;

  final StreamController<SyncState> _stateController =
      StreamController<SyncState>.broadcast();

  StreamSubscription<void>? _localChangesSub;
  StreamSubscription<bool>? _connectivitySub;
  Timer? _debounceTimer;
  Timer? _heartbeatTimer;

  String? _userId;
  bool _inFlight = false;
  SyncState _state = const SyncState();

  SyncService({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.connectionChecker,
  });

  Stream<SyncState> get stateStream => _stateController.stream;
  SyncState get state => _state;

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  /// Called when a user signs in. Safe to call twice.
  void start(String userId) {
    if (_userId == userId) return;
    stop();
    _userId = userId;

    // 1. React to local writes (debounced).
    _localChangesSub = localDataSource.changes.listen((_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_debounce, syncNow);
    });

    // 2. React to the connection coming back. This is the moment the brief
    //    cares about most: queued work must drain by itself, with no retry
    //    button for the user to find.
    _connectivitySub = connectionChecker.onStatusChange.listen((isOnline) {
      _emit(_state.copyWith(isOnline: isOnline));
      if (isOnline) syncNow();
    });

    // 3. Heartbeat.
    _heartbeatTimer = Timer.periodic(_heartbeat, (_) => syncNow());

    syncNow();
  }

  /// Called on logout. Leaves no timers or subscriptions behind.
  void stop() {
    _debounceTimer?.cancel();
    _heartbeatTimer?.cancel();
    _localChangesSub?.cancel();
    _connectivitySub?.cancel();
    _debounceTimer = null;
    _heartbeatTimer = null;
    _localChangesSub = null;
    _connectivitySub = null;
    _userId = null;
    _emit(const SyncState());
  }

  Future<void> dispose() async {
    stop();
    await _stateController.close();
  }

  // ------------------------------------------------------------------
  // The cycle
  // ------------------------------------------------------------------

  Future<void> syncNow() async {
    final userId = _userId;
    if (userId == null) return;

    // Single-flight guard. Connectivity returning while the heartbeat is
    // already running would otherwise push the same outbox rows twice.
    if (_inFlight) return;
    _inFlight = true;

    try {
      if (!await connectionChecker.isConnected) {
        _emit(_state.copyWith(
          isOnline: false,
          isSyncing: false,
          pendingCount: await localDataSource.pendingCount(),
        ));
        return;
      }

      _emit(_state.copyWith(isOnline: true, isSyncing: true, clearError: true));

      await _push();
      await _pull(userId);

      _emit(_state.copyWith(
        isSyncing: false,
        pendingCount: await localDataSource.pendingCount(),
        lastSyncedAt: DateTime.now(),
        clearError: true,
      ));
    } catch (e) {
      _emit(_state.copyWith(
        isSyncing: false,
        pendingCount: await _safePendingCount(),
        errorMessage: e is ServerException ? e.message : e.toString(),
      ));
    } finally {
      _inFlight = false;
    }
  }

  /// Drains the outbox, oldest change first.
  ///
  /// One entry failing must not block the others — a single task rejected by
  /// a constraint should not freeze every other change behind it. So failures
  /// are recorded and the loop moves on.
  Future<void> _push() async {
    var rounds = 0;
    while (rounds++ < 20) {
      final entries = await localDataSource.pendingEntries(limit: 25);
      if (entries.isEmpty) return;

      var progressed = false;

      for (final entry in entries) {
        try {
          // Upsert, so replaying an entry we already sent (because the app
          // died before we could delete it) lands on the same row instead of
          // creating a duplicate. Idempotency is what makes retries safe.
          await remoteDataSource.upsertTask(entry.task);
          await localDataSource.markEntrySucceeded(entry);
          progressed = true;
        } on ServerException catch (e) {
          await _recordFailure(entry, e.message);
        } catch (e) {
          await _recordFailure(entry, e.toString());
        }
      }

      // Everything left in this batch is scheduled for the future; asking
      // again right now would return nothing and spin.
      if (!progressed) return;
    }
  }

  Future<void> _recordFailure(OutboxEntry entry, String error) async {
    final attempts = entry.attempts + 1;
    final retryAt = DateTime.now().add(_backoffFor(attempts));
    await localDataSource.markEntryFailed(entry, error, retryAt);
  }

  /// Exponential backoff with jitter: 2s, 4s, 8s ... capped at 5 minutes.
  ///
  /// The jitter matters. Without it, every phone that lost signal in the same
  /// tunnel retries at the same instant and stampedes the server the moment
  /// the train comes out.
  Duration _backoffFor(int attempts) {
    final capped = min(attempts, _maxTightRetries);
    final seconds = min(pow(2, capped).toInt(), 300);
    final jitter = Random().nextInt(1000);
    return Duration(seconds: seconds, milliseconds: jitter);
  }

  /// Delta pull: ask only for rows changed since the last successful pull.
  Future<void> _pull(String userId) async {
    final since = await localDataSource.getLastPulledAt();
    final remoteTasks =
        await remoteDataSource.fetchChangedSince(userId, since);

    if (remoteTasks.isEmpty) return;

    await localDataSource.applyRemoteTasks(remoteTasks);

    // Advance the watermark using the newest row the SERVER reported, not
    // this device's clock. If the two clocks disagree, using local time here
    // would silently skip rows forever.
    final newest = remoteTasks
        .map((task) => task.updatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    await localDataSource.setLastPulledAt(newest);
  }

  Future<int> _safePendingCount() async {
    try {
      return await localDataSource.pendingCount();
    } catch (_) {
      return _state.pendingCount;
    }
  }

  void _emit(SyncState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }
}
