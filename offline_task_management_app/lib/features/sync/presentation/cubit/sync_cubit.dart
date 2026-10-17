import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/sync_service.dart';
import '../../domain/entities/sync_state.dart';

/// Thin adapter: turns the sync engine's stream into something widgets can
/// rebuild on. It holds no logic of its own — all of that lives in
/// [SyncService], which is plain Dart and testable without Flutter.
class SyncCubit extends Cubit<SyncState> {
  final SyncService syncService;
  StreamSubscription<SyncState>? _subscription;

  SyncCubit(this.syncService) : super(syncService.state) {
    _subscription = syncService.stateStream.listen(emit);
  }

  void start(String userId) => syncService.start(userId);
  void stop() => syncService.stop();

  /// Pull-to-refresh and the retry button both land here.
  Future<void> syncNow() => syncService.syncNow();

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
