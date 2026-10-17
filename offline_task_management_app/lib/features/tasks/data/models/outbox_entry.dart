import 'task_model.dart';

enum OutboxOperation { upsert, delete }

/// One unsent change, exactly as it sits in the `outbox` table.
///
/// Why store a full payload snapshot instead of just the task id?
/// Because by the time the worker gets to this row, the user may have edited
/// the task three more times. Replaying intent in order needs the value as it
/// was *at that moment*, not as it is now.
class OutboxEntry {
  final int id;
  final String taskId;
  final OutboxOperation operation;
  final String payload;
  final DateTime createdAt;
  final int attempts;
  final DateTime nextRetryAt;
  final String? lastError;

  const OutboxEntry({
    required this.id,
    required this.taskId,
    required this.operation,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    required this.nextRetryAt,
    this.lastError,
  });

  TaskModel get task => TaskModel.decodePayload(payload);

  factory OutboxEntry.fromRow(Map<String, Object?> row) {
    return OutboxEntry(
      id: row['id'] as int,
      taskId: row['task_id'] as String,
      operation: OutboxOperation.values.byName(row['operation'] as String),
      payload: row['payload'] as String,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      attempts: (row['attempts'] as int?) ?? 0,
      nextRetryAt:
          DateTime.fromMillisecondsSinceEpoch((row['next_retry_at'] as int?) ?? 0),
      lastError: row['last_error'] as String?,
    );
  }
}
