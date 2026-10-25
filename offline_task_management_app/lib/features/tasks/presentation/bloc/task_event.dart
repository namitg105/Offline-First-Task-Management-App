part of 'task_bloc.dart';

/// Past tense throughout: an event records something that already happened, not an
/// instruction. `TaskDeletionRequested` says the user asked; whether a row is
/// actually deleted is the bloc's decision.
@immutable
sealed class TaskEvent {
  const TaskEvent();
}

/// A user signed in: start watching the local database for their tasks.
final class TasksSubscriptionRequested extends TaskEvent {
  final String userId;
  const TasksSubscriptionRequested(this.userId);
}

/// Search text or a filter chip changed. Re-queries SQLite with a new WHERE
/// clause rather than filtering the list already in memory.
final class TaskFilterChanged extends TaskEvent {
  final TaskFilter filter;
  const TaskFilterChanged(this.filter);
}

/// The filter sheet was opened and needs the list of categories in use.
final class TaskCategoriesRequested extends TaskEvent {
  const TaskCategoriesRequested();
}

final class TaskCreationSubmitted extends TaskEvent {
  final String userId;
  final String title;
  final String description;
  final TaskPriority priority;
  final String category;
  final DateTime? dueAt;

  const TaskCreationSubmitted({
    required this.userId,
    required this.title,
    this.description = '',
    this.priority = TaskPriority.medium,
    this.category = '',
    this.dueAt,
  });
}

final class TaskEditSubmitted extends TaskEvent {
  final Task task;
  const TaskEditSubmitted(this.task);
}

final class TaskCompletionToggled extends TaskEvent {
  final Task task;
  const TaskCompletionToggled(this.task);
}

/// A task was swiped away and the confirmation accepted.
final class TaskDeletionRequested extends TaskEvent {
  final String taskId;
  const TaskDeletionRequested(this.taskId);
}

/// The UI has shown the current error message and it can be cleared.
final class TaskErrorDismissed extends TaskEvent {
  const TaskErrorDismissed();
}

// Internal events: the database stream feeds these back into the bloc so every
// state change has exactly one source, an event. Both are genuine past-tense
// facts: the rows DID arrive, the read DID fail.

final class TasksUpdated extends TaskEvent {
  final List<Task> tasks;
  const TasksUpdated(this.tasks);
}

final class TasksLoadFailed extends TaskEvent {
  final String message;
  const TasksLoadFailed(this.message);
}
