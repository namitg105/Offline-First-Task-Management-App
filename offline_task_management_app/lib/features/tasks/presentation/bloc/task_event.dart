part of 'task_bloc.dart';

@immutable
sealed class TaskEvent {}

/// Start listening to the local database for this user. Fired once.
final class TasksSubscriptionRequested extends TaskEvent {
  final String userId;
  TasksSubscriptionRequested(this.userId);
}

/// Search text or any filter chip changed. Re-queries SQLite with a new
/// WHERE clause rather than filtering the list already in memory.
final class TaskFilterChanged extends TaskEvent {
  final TaskFilter filter;
  TaskFilterChanged(this.filter);
}

final class TaskCategoriesRequested extends TaskEvent {}

final class TaskCreated extends TaskEvent {
  final String userId;
  final String title;
  final String description;
  final TaskPriority priority;
  final String category;
  final DateTime? dueAt;

  TaskCreated({
    required this.userId,
    required this.title,
    this.description = '',
    this.priority = TaskPriority.medium,
    this.category = '',
    this.dueAt,
  });
}

final class TaskEdited extends TaskEvent {
  final Task task;
  TaskEdited(this.task);
}

final class TaskCompletionToggled extends TaskEvent {
  final Task task;
  TaskCompletionToggled(this.task);
}

final class TaskDeleted extends TaskEvent {
  final String taskId;
  TaskDeleted(this.taskId);
}

/// Clears a one-shot error after the UI has shown it.
final class TaskErrorDismissed extends TaskEvent {}

// ---------------------------------------------------------------------------
// Internal events. The database stream feeds these back into the bloc so that
// every state change has exactly one source: an event. Nothing emits from
// outside a handler.
// ---------------------------------------------------------------------------

final class TasksUpdated extends TaskEvent {
  final List<Task> tasks;
  TasksUpdated(this.tasks);
}

final class TasksLoadFailed extends TaskEvent {
  final String message;
  TasksLoadFailed(this.message);
}
