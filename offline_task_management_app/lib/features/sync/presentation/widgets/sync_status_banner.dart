import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/sync_state.dart';
import '../bloc/sync_bloc.dart';

/// Shows whether the app is online or offline (the brief asks for this).
///
/// Silent when everything is synced: a permanent green bar teaches users to ignore
/// the strip, exactly where an "offline" warning must not be missed.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncBloc, SyncState>(
      builder: (context, state) {
        final info = _describe(state);
        if (info == null) return const SizedBox.shrink();

        return Material(
          color: info.color.withValues(alpha: 0.16),
          child: InkWell(
            onTap: state.isOnline && !state.isSyncing
                ? () => context.read<SyncBloc>().add(const SyncRequested())
                : null,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                children: [
                  if (state.isSyncing)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(info.icon, size: 16, color: info.color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      info.message,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: info.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!state.isSyncing && state.isOnline && state.hasPending)
                    Text('Tap to retry',
                        style: TextStyle(fontSize: 11, color: info.color)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  ({String message, IconData icon, Color color})? _describe(SyncState state) {
    const offline = Color(0xFFF0A14B);
    const error = Color(0xFFF05D5D);
    const busy = Color(0xFF6B8AFD);

    if (!state.isOnline) {
      return (
        message: state.hasPending
            ? 'Offline — ${_changes(state.pendingCount)} will sync when you reconnect'
            : 'Offline — your tasks still work',
        icon: Icons.cloud_off_outlined,
        color: offline,
      );
    }
    if (state.isSyncing) {
      return (message: 'Syncing…', icon: Icons.sync, color: busy);
    }
    if (state.errorMessage != null) {
      return (
        message: 'Sync failed: ${state.errorMessage}',
        icon: Icons.error_outline,
        color: error,
      );
    }
    if (state.hasPending) {
      return (
        message: '${_changes(state.pendingCount)} waiting to sync',
        icon: Icons.cloud_upload_outlined,
        color: busy,
      );
    }
    return null; // fully synced: say nothing
  }

  String _changes(int count) => count == 1 ? '1 change' : '$count changes';
}
