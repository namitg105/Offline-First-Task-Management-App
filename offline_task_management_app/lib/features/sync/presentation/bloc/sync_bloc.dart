import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/sync_service.dart';
import '../../domain/entities/sync_state.dart';

part 'sync_event.dart';

/// Adapter between the sync engine and the widgets that display its progress.
/// Holds no synchronisation logic: that lives in [SyncService], plain Dart and
/// testable without Flutter.
class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final SyncService _syncService;
  StreamSubscription<SyncState>? _engineSubscription;

  SyncBloc({required SyncService syncService})
      : _syncService = syncService,
        super(syncService.state) {
    on<SyncWatchStarted>(_onSyncWatchStarted);
    on<SyncWatchStopped>(_onSyncWatchStopped);
    on<SyncRequested>(_onSyncRequested);
    on<SyncStateReported>(_onSyncStateReported);

    _engineSubscription = _syncService.stateStream.listen(
      (state) => add(SyncStateReported(state)),
    );
  }

  void _onSyncWatchStarted(SyncWatchStarted event, Emitter<SyncState> emit) {
    _syncService.start(event.userId);
  }

  void _onSyncWatchStopped(SyncWatchStopped event, Emitter<SyncState> emit) {
    _syncService.stop();
  }

  Future<void> _onSyncRequested(
    SyncRequested event,
    Emitter<SyncState> emit,
  ) async {
    await _syncService.syncNow();
  }

  /// The only handler that emits. Everything else asks the engine to do
  /// something and waits for it to report back through this event.
  void _onSyncStateReported(
    SyncStateReported event,
    Emitter<SyncState> emit,
  ) {
    emit(event.state);
  }

  @override
  Future<void> close() async {
    await _engineSubscription?.cancel();
    return super.close();
  }
}
