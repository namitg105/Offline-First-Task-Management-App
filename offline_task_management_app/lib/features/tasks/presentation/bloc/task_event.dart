part of 'task_bloc.dart';

@immutable
sealed class TaskEvent {}

/// Start listening to the local database for this user. Fired once.
final class TasksSubscriptionRequested extends TaskEvent {
  final String userId;
  TasksSubscriptionRequested(this.userId);
}

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
